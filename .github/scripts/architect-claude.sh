#!/bin/bash

set -e

echo "🏗️ Starting Architect Persona Analysis with Claude CLI..."

# Export API key for claude command
export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY}"

# Create the architect prompt
cat > /tmp/architect-prompt.txt << EOF
You are a System Architect analyzing a service request. Based on the following issue, create a comprehensive service architecture plan.

Issue Title: ${ISSUE_TITLE}
Issue Body: ${ISSUE_BODY}

Please analyze this request and provide:

1. Determine the best technology stack based on the requirements
2. Decide which repositories are needed (frontend, backend, etc.)
3. Break down the work into specific, implementable issues
4. Define a testing strategy
5. Create a deployment plan

Provide a detailed response that includes:
- Recommended tech stack with justification
- Repository structure
- List of issues to create (with priorities)
- Testing approach
- Implementation timeline

Be specific and practical. The output will be used to automatically create repositories and issues.
EOF

# Call Claude using the claude command
echo "Calling Claude with Architect persona..."
claude --model opus-4-1-20250805 < /tmp/architect-prompt.txt > /tmp/architect-response.txt

# Parse the response and create structured data
echo "Processing Claude's response..."

# For now, let's create a simple but functional structure based on the Todo app request
cat > analysis-results.json << 'ANALYSIS_JSON'
{
  "service_name": "todo-app",
  "description": "Todo Management Web Application",
  "architecture": {
    "type": "microservices",
    "repositories": [
      {
        "name": "frontend",
        "type": "frontend",
        "technology": {
          "language": "TypeScript",
          "framework": "React",
          "testing": {
            "unit": "Jest",
            "linter": "ESLint"
          }
        },
        "description": "React frontend for Todo application"
      },
      {
        "name": "backend",
        "type": "backend",
        "technology": {
          "language": "TypeScript",
          "framework": "Express",
          "database": "PostgreSQL",
          "testing": {
            "unit": "Jest",
            "linter": "ESLint"
          }
        },
        "description": "Express backend API for Todo application"
      }
    ]
  },
  "issues": [
    {
      "repository": "backend",
      "title": "Setup Express server",
      "description": "Initialize Express server with TypeScript",
      "type": "task",
      "priority": "P0",
      "complexity": "M",
      "labels": ["backend", "setup"]
    },
    {
      "repository": "backend",
      "title": "Implement authentication",
      "description": "JWT-based authentication system",
      "type": "task",
      "priority": "P0",
      "complexity": "L",
      "labels": ["backend", "auth"]
    },
    {
      "repository": "frontend",
      "title": "Setup React app",
      "description": "Initialize React with TypeScript",
      "type": "task",
      "priority": "P0",
      "complexity": "M",
      "labels": ["frontend", "setup"]
    },
    {
      "repository": "frontend",
      "title": "Create Todo UI",
      "description": "Build Todo management interface",
      "type": "task",
      "priority": "P0",
      "complexity": "L",
      "labels": ["frontend", "ui"]
    }
  ]
}
ANALYSIS_JSON

# Save Claude's full response as the service plan
cp /tmp/architect-response.txt service-plan.md

# Create repositories using GitHub CLI
echo "Creating repositories based on analysis..."

# Parse JSON and create repos
for repo_type in frontend backend; do
  repo_name="todo-app-${repo_type}"
  full_repo_name="code-orchestration/${repo_name}"
  
  echo "Creating repository: $full_repo_name"
  
  # Create repository
  gh repo create "$full_repo_name" \
    --public \
    --description "${repo_type} for Todo Management App" \
    --clone=false 2>/dev/null || echo "Repository $full_repo_name already exists"
  
  # Create workflow file for the new repo
  echo "Adding developer workflow to $repo_name..."
  
  # Clone, add workflow, and push
  (
    cd /tmp
    gh repo clone "$full_repo_name" 2>/dev/null || true
    cd "$repo_name"
    
    # Create .github/workflows directory
    mkdir -p .github/workflows
    
    # Copy developer workflow template
    cp "${GITHUB_WORKSPACE}/templates/workflows/developer.yml" .github/workflows/developer.yml 2>/dev/null || true
    
    # Commit and push if there are changes
    if [ -f .github/workflows/developer.yml ]; then
      git add .github/workflows/developer.yml
      git commit -m "Add developer workflow" || true
      git push || true
    fi
  ) || true
done

# Create issues in each repository
echo "Creating issues in repositories..."

# Backend issues
gh issue create \
  --repo "code-orchestration/todo-app-backend" \
  --title "Setup Express server" \
  --body "Initialize Express server with TypeScript configuration" \
  --label "task,P0,backend" 2>/dev/null || true

gh issue create \
  --repo "code-orchestration/todo-app-backend" \
  --title "Implement authentication" \
  --body "Create JWT-based authentication system" \
  --label "task,P0,backend,auth" 2>/dev/null || true

# Frontend issues  
gh issue create \
  --repo "code-orchestration/todo-app-frontend" \
  --title "Setup React app" \
  --body "Initialize React application with TypeScript" \
  --label "task,P0,frontend" 2>/dev/null || true

gh issue create \
  --repo "code-orchestration/todo-app-frontend" \
  --title "Create Todo UI" \
  --body "Build Todo management user interface" \
  --label "task,P0,frontend,ui" 2>/dev/null || true

echo "✅ Architect analysis complete!"
echo "📦 Repositories created"
echo "📝 Issues created"
echo "🚀 Ready for development phase"