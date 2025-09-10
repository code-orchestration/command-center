# Sample Service Creation Issue

This is an example of what to write in a service-type issue to trigger the automation pipeline.

## Issue Title
```
Todo Management Web App
```

## Issue Labels
- `service-type` (required to trigger the pipeline)

## Issue Body
```markdown
I need a Todo Management Web App with the following features:

## Core Features
- User authentication (signup, login, logout, password reset)
- Create, read, update, and delete todos
- Mark todos as complete/incomplete with visual feedback
- Set due dates with reminder notifications
- Assign priority levels (High, Medium, Low)
- Add tags/categories for organization
- Search and filter todos by status, date, priority, or tags

## User Interface
- Modern, responsive design that works on desktop and mobile
- Dark mode support
- Real-time updates without page refresh
- Drag and drop to reorder todos
- Keyboard shortcuts for power users

## Technical Requirements
- Fast page loads (< 2 seconds)
- Support for 1000+ todos per user
- Secure authentication with JWT tokens
- Data persistence with automatic backups
- RESTful API for potential mobile app integration

## Nice to Have
- Share todos with other users
- Recurring todos
- Todo templates
- Export to CSV/PDF
- Statistics dashboard
```

## What Happens Next

1. **Architect Persona** will:
   - Analyze your requirements
   - Choose the best tech stack (e.g., React + Node.js + PostgreSQL)
   - Create repositories (todo-web, todo-api)
   - Generate detailed implementation issues
   - Set up CI/CD pipelines

2. **Developer Persona** will:
   - Pick up each issue automatically
   - Implement the features
   - Write tests
   - Create pull requests

3. **QA Persona** will:
   - Review the code
   - Run automated tests
   - Approve or request changes
   - Auto-merge when ready

## Tips for Writing Good Service Requests

1. **Be Specific**: The more detail you provide, the better the architecture
2. **Natural Language**: Write as if explaining to a human developer
3. **Priorities**: Mention what's critical vs nice-to-have
4. **Constraints**: Include any technical or business constraints
5. **Examples**: Reference similar apps or services if helpful