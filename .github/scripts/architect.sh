#!/bin/bash

set -e

echo "🏗️ Starting Architect Persona Analysis..."

# Create temporary directory for analysis
WORK_DIR=$(mktemp -d)
cd "$WORK_DIR"

# Create the architect prompt
cat > architect-prompt.md << 'EOF'
You are a System Architect persona with expertise in modern software architecture and best practices.

## Your Task
Analyze the following service requirements and create a comprehensive service architecture plan.

### Input Requirements
**Issue Title:** $ISSUE_TITLE
**Issue Body:** 
$ISSUE_BODY

## Your Responsibilities

1. **Requirement Analysis**
   - Parse the natural language requirements
   - Identify core functionalities
   - Determine non-functional requirements (performance, security, scalability)

2. **Technology Stack Selection**
   Based on the requirements, select the most appropriate:
   - Programming languages
   - Frameworks (frontend/backend)
   - Database systems
   - Additional tools and services

3. **Repository Structure Planning**
   Determine which repositories are needed:
   - Frontend repository (if UI is required)
   - Backend API repository (if backend logic is needed)
   - Infrastructure repository (if complex deployment is required)
   - Shared libraries (if code reuse is beneficial)

4. **Issue Decomposition**
   Break down the service into implementable issues:
   - Create epics for major features
   - Break epics into user stories
   - Define technical tasks
   - Set priorities (P0: Critical, P1: Important, P2: Nice-to-have)
   - Estimate complexity (Small, Medium, Large)

5. **Testing Strategy**
   Define testing approach for each repository:
   - Unit testing framework
   - Integration testing approach
   - E2E testing strategy
   - Code quality tools (linters, formatters)
   - Coverage requirements

6. **CI/CD Pipeline Design**
   Design the automation pipeline:
   - Build process
   - Test execution
   - Code quality checks
   - Deployment strategy

## Output Format

Generate a JSON file with the following structure:
```json
{
  "service_name": "string",
  "description": "string",
  "architecture": {
    "type": "monolithic|microservices|serverless",
    "repositories": [
      {
        "name": "string",
        "type": "frontend|backend|infra|library",
        "technology": {
          "language": "string",
          "framework": "string",
          "database": "string (if applicable)",
          "testing": {
            "unit": "string",
            "integration": "string",
            "linter": "string"
          }
        },
        "description": "string"
      }
    ]
  },
  "issues": [
    {
      "repository": "string",
      "title": "string",
      "description": "string",
      "type": "epic|story|task|bug",
      "priority": "P0|P1|P2",
      "complexity": "S|M|L",
      "labels": ["string"],
      "dependencies": ["issue_id"]
    }
  ],
  "testing_strategy": {
    "unit_coverage_target": "number",
    "integration_tests": "boolean",
    "e2e_tests": "boolean",
    "performance_tests": "boolean"
  },
  "deployment": {
    "strategy": "continuous|staged|manual",
    "environments": ["dev", "staging", "production"]
  }
}
```

Also create a human-readable markdown file (service-plan.md) explaining the decisions and rationale.

Remember:
- Choose technologies that work well together
- Prioritize developer experience and maintainability
- Consider the scale and complexity appropriately
- Keep the initial scope achievable (MVP mindset)
- Ensure all generated issues are concrete and actionable
EOF

# Replace environment variables in the prompt
sed -i "s/\$ISSUE_TITLE/$ISSUE_TITLE/g" architect-prompt.md
sed -i "s/\$ISSUE_BODY/$ISSUE_BODY/g" architect-prompt.md

# Run Claude with the architect prompt
echo "Running Claude CLI with Architect persona..."
claude run --persona system-architect \
  --input architect-prompt.md \
  --output analysis-results.json \
  --format json \
  --think-hard

# Also generate the markdown plan
claude run --persona system-architect \
  --input architect-prompt.md \
  --output service-plan.md \
  --format markdown \
  --context analysis-results.json

# Copy results to workspace
cp analysis-results.json "$GITHUB_WORKSPACE/"
cp service-plan.md "$GITHUB_WORKSPACE/"

# Parse the JSON and create repositories
echo "📦 Creating repositories based on analysis..."
python3 << 'PYTHON_SCRIPT'
import json
import os
import subprocess

with open('analysis-results.json', 'r') as f:
    data = json.load(f)

org_name = "code-orchestration"
gh_token = os.environ['GH_PAT']

for repo in data['architecture']['repositories']:
    repo_name = f"{data['service_name']}-{repo['name']}"
    repo_full_name = f"{org_name}/{repo_name}"
    
    print(f"Creating repository: {repo_full_name}")
    
    # Create repository using gh CLI
    create_cmd = [
        'gh', 'repo', 'create',
        repo_full_name,
        '--public',
        '--description', repo['description'],
        '--clone=false'
    ]
    
    try:
        subprocess.run(create_cmd, check=True, env={**os.environ, 'GH_TOKEN': gh_token})
        print(f"✅ Repository {repo_full_name} created successfully")
        
        # Add labels to the new repository
        labels = ['automated', 'superclaude', repo['type']]
        for label in labels:
            label_cmd = [
                'gh', 'label', 'create',
                label,
                '--repo', repo_full_name
            ]
            subprocess.run(label_cmd, env={**os.environ, 'GH_TOKEN': gh_token})
        
        # Create initial structure based on type
        if repo['type'] == 'frontend':
            # Will be handled by developer persona
            pass
        elif repo['type'] == 'backend':
            # Will be handled by developer persona
            pass
            
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to create repository {repo_full_name}: {e}")

# Create issues in each repository
for issue in data['issues']:
    repo_name = f"{data['service_name']}-{issue['repository']}"
    repo_full_name = f"{org_name}/{repo_name}"
    
    print(f"Creating issue in {repo_full_name}: {issue['title']}")
    
    # Format issue body
    issue_body = f"""## Description
{issue['description']}

## Details
- **Type:** {issue['type']}
- **Priority:** {issue['priority']}
- **Complexity:** {issue['complexity']}
- **Labels:** {', '.join(issue['labels'])}

## Acceptance Criteria
- [ ] Implementation complete
- [ ] Unit tests written
- [ ] Documentation updated
- [ ] Code reviewed

---
*This issue was automatically generated by SuperClaude Architect Persona*
"""
    
    # Create issue using gh CLI
    issue_cmd = [
        'gh', 'issue', 'create',
        '--repo', repo_full_name,
        '--title', issue['title'],
        '--body', issue_body,
        '--label', ','.join(issue['labels'] + [issue['priority'], issue['type']])
    ]
    
    try:
        result = subprocess.run(issue_cmd, check=True, capture_output=True, text=True, 
                              env={**os.environ, 'GH_TOKEN': gh_token})
        print(f"✅ Issue created: {result.stdout.strip()}")
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to create issue: {e}")

print("\n🎉 Service architecture complete!")
PYTHON_SCRIPT

# Create a summary comment on the original issue
cat > summary.md << 'EOF'
## 🏗️ Architect Analysis Complete

The service architecture has been designed and repositories have been created.

### 📊 Analysis Results
See the attached artifacts for detailed analysis.

### 📦 Created Repositories
Check the organization for new repositories.

### 📝 Next Steps
1. Developer personas will pick up the created issues
2. Implementation will begin automatically
3. Monitor progress in each repository's Actions tab

---
*Automated by SuperClaude Architect Persona*
EOF

echo "✅ Architect analysis complete!"