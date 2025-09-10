#!/bin/bash

set -e

echo "🔍 Starting QA Persona Review..."

# Read PR details
PR_DATA=$(cat pr.json)
PR_TITLE=$(echo "$PR_DATA" | jq -r '.title')
PR_BODY=$(echo "$PR_DATA" | jq -r '.body')
PR_FILES=$(echo "$PR_DATA" | jq -r '.files[].filename' | tr '\n' ' ')
PR_ADDITIONS=$(echo "$PR_DATA" | jq -r '.additions')
PR_DELETIONS=$(echo "$PR_DATA" | jq -r '.deletions')

# Read the diff
PR_DIFF=$(cat pr.diff)

# Create QA review prompt
cat > qa-prompt.md << 'EOF'
You are a Senior QA Engineer persona with expertise in code quality, testing, and best practices.

## Your Task
Review the following pull request and provide comprehensive feedback.

### Pull Request Details
**Title:** $PR_TITLE
**Description:** 
$PR_BODY

**Files Changed:** $PR_FILES
**Lines Added:** $PR_ADDITIONS
**Lines Deleted:** $PR_DELETIONS

### Code Diff
```diff
$PR_DIFF
```

## Review Criteria

1. **Code Quality**
   - Clean, readable, and maintainable code
   - Proper naming conventions
   - No code duplication (DRY principle)
   - SOLID principles adherence
   - Appropriate abstractions

2. **Testing**
   - Adequate test coverage (minimum 80%)
   - Unit tests for new functionality
   - Integration tests where needed
   - Edge cases covered
   - Tests are meaningful and not just for coverage

3. **Security**
   - No hardcoded secrets or credentials
   - Input validation and sanitization
   - SQL injection prevention
   - XSS prevention (for web apps)
   - Proper authentication/authorization

4. **Performance**
   - No obvious performance bottlenecks
   - Efficient algorithms (appropriate time/space complexity)
   - Database queries optimized
   - Caching used appropriately
   - No memory leaks

5. **Documentation**
   - Code is self-documenting
   - Complex logic has comments
   - README updated if needed
   - API documentation complete
   - Changelog updated

6. **Best Practices**
   - Error handling implemented
   - Logging added appropriately
   - Configuration externalized
   - Dependencies up to date
   - No deprecated functions used

## Review Output

Generate a JSON file with the following structure:
```json
{
  "approval_status": "approved|changes_requested|comment",
  "overall_quality": "excellent|good|satisfactory|needs_improvement",
  "strengths": [
    "List of things done well"
  ],
  "issues": [
    {
      "severity": "critical|major|minor|suggestion",
      "category": "security|performance|quality|testing|documentation",
      "description": "Description of the issue",
      "file": "file path if applicable",
      "line": "line number if applicable",
      "suggestion": "How to fix it"
    }
  ],
  "suggestions": [
    "General improvement suggestions"
  ],
  "metrics": {
    "test_coverage": "percentage or N/A",
    "code_quality": "A|B|C|D|F",
    "security_score": "high|medium|low",
    "performance_impact": "positive|neutral|negative"
  },
  "detailed_feedback": "Comprehensive review text"
}
```

## Decision Criteria

**Approve** if:
- No critical or major issues
- Test coverage >= 80%
- Security checks pass
- Code quality is good or excellent

**Request Changes** if:
- Any critical issues found
- Multiple major issues
- Test coverage < 60%
- Security vulnerabilities detected

**Comment** if:
- Only minor issues or suggestions
- Test coverage between 60-80%
- Need clarification on implementation

Remember:
- Be constructive and specific in feedback
- Acknowledge good practices
- Provide actionable suggestions
- Consider the context and scope of changes
- Balance perfectionism with pragmatism
EOF

# Replace variables in the prompt
# Use different delimiter for sed to handle special characters in diff
sed -i "s|\$PR_TITLE|$PR_TITLE|g" qa-prompt.md
sed -i "s|\$PR_BODY|$PR_BODY|g" qa-prompt.md
sed -i "s|\$PR_FILES|$PR_FILES|g" qa-prompt.md
sed -i "s|\$PR_ADDITIONS|$PR_ADDITIONS|g" qa-prompt.md
sed -i "s|\$PR_DELETIONS|$PR_DELETIONS|g" qa-prompt.md

# Handle the diff separately due to special characters
# Create a temporary file with the diff content
echo "$PR_DIFF" > temp_diff.txt
# Use awk to replace the placeholder with the diff content
awk '/\$PR_DIFF/{system("cat temp_diff.txt");next}1' qa-prompt.md > qa-prompt-final.md
mv qa-prompt-final.md qa-prompt.md
rm temp_diff.txt

# Run Claude with QA persona
echo "Running Claude CLI with QA persona..."
claude run --persona qa-engineer \
  --input qa-prompt.md \
  --output review-results.json \
  --format json \
  --think-hard

# Parse the review results and create summary
python3 << 'PYTHON_SCRIPT'
import json
import sys

try:
    with open('review-results.json', 'r') as f:
        review = json.load(f)
    
    print("\n" + "="*50)
    print("QA REVIEW SUMMARY")
    print("="*50)
    
    print(f"\n📊 Overall Status: {review['approval_status'].upper()}")
    print(f"📈 Code Quality: {review['overall_quality']}")
    
    if review.get('strengths'):
        print("\n✅ Strengths:")
        for strength in review['strengths']:
            print(f"  • {strength}")
    
    if review.get('issues'):
        critical_count = sum(1 for i in review['issues'] if i['severity'] == 'critical')
        major_count = sum(1 for i in review['issues'] if i['severity'] == 'major')
        minor_count = sum(1 for i in review['issues'] if i['severity'] == 'minor')
        
        print(f"\n⚠️ Issues Found:")
        print(f"  • Critical: {critical_count}")
        print(f"  • Major: {major_count}")
        print(f"  • Minor: {minor_count}")
        
        if critical_count > 0 or major_count > 0:
            print("\n🔴 Critical/Major Issues:")
            for issue in review['issues']:
                if issue['severity'] in ['critical', 'major']:
                    print(f"  • [{issue['severity'].upper()}] {issue['description']}")
    
    print("\n" + "="*50)
    
    # Set output for GitHub Actions
    print(f"::set-output name=approval_status::{review['approval_status']}")
    
except Exception as e:
    print(f"Error processing review results: {e}")
    sys.exit(1)
PYTHON_SCRIPT

echo "✅ QA review complete!"