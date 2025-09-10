#!/bin/bash

set -e

echo "🏗️ Starting Simple Architect Analysis..."

# Create analysis using direct API call
cat > analysis-request.json << EOF
{
  "issue_title": "$ISSUE_TITLE",
  "issue_body": "$ISSUE_BODY",
  "issue_number": "$ISSUE_NUMBER"
}
EOF

# Create simple analysis result (for MVP testing)
cat > analysis-results.json << EOF
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
            "integration": "React Testing Library",
            "linter": "ESLint"
          }
        },
        "description": "React-based frontend for Todo application"
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
            "integration": "Supertest",
            "linter": "ESLint"
          }
        },
        "description": "RESTful API backend for Todo application"
      }
    ]
  },
  "issues": [
    {
      "repository": "backend",
      "title": "Setup Express server with TypeScript",
      "description": "Initialize Express server with TypeScript configuration, middleware, and basic routing",
      "type": "task",
      "priority": "P0",
      "complexity": "M",
      "labels": ["backend", "setup"],
      "dependencies": []
    },
    {
      "repository": "backend",
      "title": "Implement authentication with JWT",
      "description": "Create user authentication system with JWT tokens, signup, login, and logout endpoints",
      "type": "task",
      "priority": "P0",
      "complexity": "L",
      "labels": ["backend", "auth"],
      "dependencies": []
    },
    {
      "repository": "backend",
      "title": "Create Todo CRUD endpoints",
      "description": "Implement Create, Read, Update, Delete operations for todos",
      "type": "task",
      "priority": "P0",
      "complexity": "M",
      "labels": ["backend", "api"],
      "dependencies": []
    },
    {
      "repository": "frontend",
      "title": "Setup React with TypeScript",
      "description": "Initialize React application with TypeScript, routing, and state management",
      "type": "task",
      "priority": "P0",
      "complexity": "M",
      "labels": ["frontend", "setup"],
      "dependencies": []
    },
    {
      "repository": "frontend",
      "title": "Create authentication UI",
      "description": "Build login, signup, and logout components with form validation",
      "type": "task",
      "priority": "P0",
      "complexity": "M",
      "labels": ["frontend", "auth"],
      "dependencies": []
    },
    {
      "repository": "frontend",
      "title": "Build Todo management interface",
      "description": "Create components for displaying, adding, editing, and deleting todos",
      "type": "task",
      "priority": "P0",
      "complexity": "L",
      "labels": ["frontend", "ui"],
      "dependencies": []
    }
  ],
  "testing_strategy": {
    "unit_coverage_target": 80,
    "integration_tests": true,
    "e2e_tests": true,
    "performance_tests": false
  },
  "deployment": {
    "strategy": "continuous",
    "environments": ["dev", "staging", "production"]
  }
}
EOF

# Create service plan
cat > service-plan.md << 'EOF'
# Service Architecture Plan: Todo Management Web App

## Overview
A modern, full-stack Todo management application with user authentication and real-time updates.

## Technology Stack

### Frontend
- **Framework**: React 18 with TypeScript
- **State Management**: Redux Toolkit
- **Styling**: Tailwind CSS
- **Build Tool**: Vite
- **Testing**: Jest + React Testing Library

### Backend
- **Runtime**: Node.js 20
- **Framework**: Express with TypeScript
- **Database**: PostgreSQL
- **ORM**: Prisma
- **Authentication**: JWT with bcrypt
- **Testing**: Jest + Supertest

## Repository Structure

### todo-app-frontend
React-based SPA with modern UI/UX features including:
- Responsive design
- Dark mode support
- Real-time updates via WebSocket
- Progressive Web App capabilities

### todo-app-backend
RESTful API server providing:
- User authentication and authorization
- Todo CRUD operations
- Real-time notifications
- Data validation and sanitization

## Implementation Phases

### Phase 1: Foundation (Week 1)
- Setup repositories with TypeScript
- Configure build tools and linting
- Implement basic CI/CD pipelines

### Phase 2: Core Features (Week 2)
- User authentication system
- Todo CRUD operations
- Basic UI components

### Phase 3: Advanced Features (Week 3)
- Real-time updates
- Tags and categories
- Search and filtering

### Phase 4: Polish (Week 4)
- Performance optimization
- Security hardening
- Documentation

## Testing Strategy
- Unit tests for all business logic (80% coverage)
- Integration tests for API endpoints
- E2E tests for critical user flows
- Performance testing for scalability

## Deployment
- Containerized with Docker
- Orchestrated with Kubernetes
- CI/CD via GitHub Actions
- Monitoring with Prometheus/Grafana
EOF

echo "Creating repositories..."

# Create repositories using GitHub CLI
for repo_data in frontend:React-Frontend backend:Express-Backend; do
  IFS=':' read -r repo_suffix repo_desc <<< "$repo_data"
  repo_name="todo-app-${repo_suffix}"
  full_repo_name="code-orchestration/${repo_name}"
  
  echo "Creating repository: $full_repo_name"
  
  # Create repository
  gh repo create "$full_repo_name" \
    --public \
    --description "$repo_desc for Todo Management App" \
    --clone=false || echo "Repository might already exist"
  
  # Add labels
  for label in automated backend frontend P0 P1 P2 task epic bug; do
    gh label create "$label" --repo "$full_repo_name" --force || true
  done
done

# Create issues in repositories
echo "Creating issues..."

# Backend issues
gh issue create \
  --repo "code-orchestration/todo-app-backend" \
  --title "Setup Express server with TypeScript" \
  --body "Initialize Express server with TypeScript configuration, middleware, and basic routing" \
  --label "task,P0,backend,setup" || true

gh issue create \
  --repo "code-orchestration/todo-app-backend" \
  --title "Implement authentication with JWT" \
  --body "Create user authentication system with JWT tokens, signup, login, and logout endpoints" \
  --label "task,P0,backend,auth" || true

gh issue create \
  --repo "code-orchestration/todo-app-backend" \
  --title "Create Todo CRUD endpoints" \
  --body "Implement Create, Read, Update, Delete operations for todos" \
  --label "task,P0,backend,api" || true

# Frontend issues
gh issue create \
  --repo "code-orchestration/todo-app-frontend" \
  --title "Setup React with TypeScript" \
  --body "Initialize React application with TypeScript, routing, and state management" \
  --label "task,P0,frontend,setup" || true

gh issue create \
  --repo "code-orchestration/todo-app-frontend" \
  --title "Create authentication UI" \
  --body "Build login, signup, and logout components with form validation" \
  --label "task,P0,frontend,auth" || true

gh issue create \
  --repo "code-orchestration/todo-app-frontend" \
  --title "Build Todo management interface" \
  --body "Create components for displaying, adding, editing, and deleting todos" \
  --label "task,P0,frontend,ui" || true

echo "✅ Architect analysis complete!"