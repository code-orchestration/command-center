# Command Center - SuperClaude Automation Pipeline

## Overview
Central control repository for the SuperClaude automation pipeline that orchestrates the entire service creation and development lifecycle using AI-powered personas.

## Architecture

### Workflow Triggers
1. **Service Creation**: Issue with `service-type` label → Architect persona bootstraps new service
2. **Development**: Issues in service repos → Developer persona implements features
3. **QA & Review**: Pull requests → QA persona reviews and tests

### Personas
- **System Architect**: Analyzes natural language requirements, designs architecture, creates repos/issues
- **Developer**: Implements features based on issues, creates PRs
- **QA Engineer**: Reviews code, runs tests, ensures quality

## Setup

### Prerequisites
- GitHub organization: `/code-orchestration`
- Claude API key ($200 plan)
- SuperClaude CLI with Opus model

### Configuration
Set GitHub secrets at organization level:
```
ANTHROPIC_API_KEY: Your Claude API key
GH_PAT: GitHub Personal Access Token (repo, workflow, issue permissions)
```

## Usage

### Creating a New Service
1. Create issue in this repository
2. Add `service-type` label
3. Describe service in natural language

Example:
```
Title: Todo Management Web App
Body: I need a web application for managing todos with:
      - User authentication
      - CRUD operations for tasks
      - Modern responsive UI
      - Real-time updates
```

The pipeline will:
- Analyze requirements using Architect persona
- Choose appropriate tech stack automatically
- Create necessary repositories (frontend/backend/infra)
- Generate detailed implementation issues
- Set up CI/CD pipelines with tests and linting

## Repository Structure
```
command-center/
├── .github/
│   ├── workflows/
│   │   ├── service-creator.yml         # Triggered by service-type issues
│   │   ├── developer.yml               # Template for dev repos
│   │   └── qa-reviewer.yml             # Template for PR reviews
│   ├── scripts/
│   │   ├── architect.sh                # Architect persona script
│   │   ├── developer.sh                # Developer persona script
│   │   └── qa.sh                       # QA persona script
│   └── ISSUE_TEMPLATE/
│       └── service-request.yml
├── templates/
│   ├── frontend/                       # Frontend repo templates
│   ├── backend/                        # Backend repo templates
│   └── workflows/                      # Workflow templates
└── docs/
    └── personas.md                     # Persona specifications
```

## Monitoring
- Check Actions tab for pipeline execution
- Each service gets its own project board
- Status: Planning → In Progress → Review → Testing → Done

## Service Lifecycle

### Phase 1: Bootstrap (Architect)
- Parse natural language requirements
- Determine optimal tech stack
- Create repositories with structure
- Generate issues with priorities
- Setup testing framework

### Phase 2: Development (Developer)
- Pick up issues automatically
- Implement features
- Write tests
- Create pull requests

### Phase 3: QA (QA Engineer)
- Run automated tests
- Perform code review
- Suggest improvements
- Approve or request changes

### Phase 4: Deployment
- Auto-merge approved PRs
- Create follow-up issues if needed
- Update documentation