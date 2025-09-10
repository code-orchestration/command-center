#!/bin/bash

set -e

echo "👨‍💻 Starting Developer Persona Implementation..."

# Read issue details
ISSUE_DATA=$(cat issue.json)
ISSUE_TITLE=$(echo "$ISSUE_DATA" | jq -r '.title')
ISSUE_BODY=$(echo "$ISSUE_DATA" | jq -r '.body')
ISSUE_LABELS=$(echo "$ISSUE_DATA" | jq -r '.labels[].name' | tr '\n' ' ')

# Detect repository type and language
REPO_NAME=$(basename $(git rev-parse --show-toplevel))
REPO_TYPE="unknown"
LANGUAGE="unknown"

# Check for common patterns in repo name
if [[ "$REPO_NAME" == *"-web"* ]] || [[ "$REPO_NAME" == *"-frontend"* ]]; then
  REPO_TYPE="frontend"
elif [[ "$REPO_NAME" == *"-api"* ]] || [[ "$REPO_NAME" == *"-backend"* ]]; then
  REPO_TYPE="backend"
elif [[ "$REPO_NAME" == *"-infra"* ]]; then
  REPO_TYPE="infrastructure"
fi

# Detect language from existing files or repo type
if [ -f "package.json" ]; then
  LANGUAGE="javascript"
elif [ -f "requirements.txt" ] || [ -f "setup.py" ]; then
  LANGUAGE="python"
elif [ -f "go.mod" ]; then
  LANGUAGE="go"
elif [ "$REPO_TYPE" == "frontend" ]; then
  LANGUAGE="javascript"  # Default for frontend
elif [ "$REPO_TYPE" == "backend" ]; then
  LANGUAGE="javascript"  # Default for backend, can be overridden
fi

echo "Repository Type: $REPO_TYPE"
echo "Language: $LANGUAGE"

# Create developer prompt
cat > developer-prompt.md << 'EOF'
You are a Senior Developer persona with expertise in modern software development practices.

## Your Task
Implement the following issue in a production-ready manner.

### Issue Details
**Title:** $ISSUE_TITLE
**Description:** 
$ISSUE_BODY

### Repository Context
- **Repository Type:** $REPO_TYPE
- **Language:** $LANGUAGE
- **Labels:** $ISSUE_LABELS

## Your Responsibilities

1. **Code Implementation**
   - Write clean, maintainable code
   - Follow language-specific best practices
   - Use appropriate design patterns
   - Handle errors gracefully
   - Add necessary comments and documentation

2. **Testing**
   - Write comprehensive unit tests
   - Add integration tests where appropriate
   - Ensure good test coverage (aim for 80%+)
   - Test edge cases and error conditions

3. **Documentation**
   - Update README if needed
   - Add inline code comments
   - Document APIs and interfaces
   - Create usage examples

4. **Code Quality**
   - Follow existing code style
   - Use linting tools
   - Optimize for performance
   - Consider security implications

## Implementation Guidelines

### For Frontend (JavaScript/TypeScript)
- Use React/Vue/Angular based on existing setup
- Implement responsive design
- Ensure accessibility (WCAG 2.1 AA)
- Optimize bundle size
- Add proper error boundaries

### For Backend (Node.js/Python/Go)
- Design RESTful APIs
- Implement proper validation
- Add authentication/authorization if needed
- Use appropriate data models
- Implement logging and monitoring

### For Infrastructure
- Use Infrastructure as Code
- Implement security best practices
- Add monitoring and alerting
- Document deployment process
- Consider scalability

## Output

Generate the actual code files needed to implement this issue. Include:
1. Source code files
2. Test files
3. Configuration updates
4. Documentation updates

Remember:
- Start with a minimal working implementation
- Add tests alongside the code
- Ensure the code is production-ready
- Follow the Single Responsibility Principle
- Make the code easy to review and understand
EOF

# Replace variables in the prompt
sed -i "s|\$ISSUE_TITLE|$ISSUE_TITLE|g" developer-prompt.md
sed -i "s|\$ISSUE_BODY|$ISSUE_BODY|g" developer-prompt.md
sed -i "s|\$REPO_TYPE|$REPO_TYPE|g" developer-prompt.md
sed -i "s|\$LANGUAGE|$LANGUAGE|g" developer-prompt.md
sed -i "s|\$ISSUE_LABELS|$ISSUE_LABELS|g" developer-prompt.md

# Initialize project if needed
if [ ! -f "package.json" ] && [ "$LANGUAGE" == "javascript" ]; then
  echo "Initializing JavaScript project..."
  
  if [ "$REPO_TYPE" == "frontend" ]; then
    # Create a React app structure
    npx create-react-app . --template typescript --use-npm
  elif [ "$REPO_TYPE" == "backend" ]; then
    # Create a Node.js Express app
    npm init -y
    npm install express cors helmet morgan compression dotenv
    npm install -D @types/node @types/express typescript ts-node nodemon jest @types/jest supertest
    
    # Create basic structure
    mkdir -p src tests
    
    # Create tsconfig.json
    cat > tsconfig.json << 'TSCONFIG'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
TSCONFIG
  fi
elif [ ! -f "requirements.txt" ] && [ "$LANGUAGE" == "python" ]; then
  echo "Initializing Python project..."
  
  # Create Python project structure
  mkdir -p src tests
  
  if [ "$REPO_TYPE" == "backend" ]; then
    # Create requirements.txt for FastAPI
    cat > requirements.txt << 'REQUIREMENTS'
fastapi==0.104.1
uvicorn[standard]==0.24.0
pydantic==2.5.0
python-dotenv==1.0.0
pytest==7.4.3
pytest-asyncio==0.21.1
httpx==0.25.1
black==23.11.0
flake8==6.1.0
mypy==1.7.0
REQUIREMENTS
  fi
  
  # Create setup.py
  cat > setup.py << 'SETUP'
from setuptools import setup, find_packages

setup(
    name="service",
    version="0.1.0",
    packages=find_packages(),
    python_requires=">=3.8",
)
SETUP
fi

# Run Claude to implement the issue
echo "Running Claude CLI with Developer persona..."
claude run --persona developer \
  --input developer-prompt.md \
  --think-hard \
  --task "Implement the issue completely with all necessary files, tests, and documentation"

# Run tests if they exist
if [ "$LANGUAGE" == "javascript" ] && [ -f "package.json" ]; then
  echo "Running JavaScript tests..."
  npm test --passWithNoTests || true
elif [ "$LANGUAGE" == "python" ] && [ -f "requirements.txt" ]; then
  echo "Running Python tests..."
  python -m pytest tests/ || true
fi

# Run linting
if [ "$LANGUAGE" == "javascript" ] && [ -f "package.json" ]; then
  echo "Running ESLint..."
  npx eslint . --fix || true
elif [ "$LANGUAGE" == "python" ]; then
  echo "Running Python linters..."
  python -m black . || true
  python -m flake8 . || true
fi

echo "✅ Developer implementation complete!"