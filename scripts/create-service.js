const { Octokit } = require('@octokit/rest');
const Anthropic = require('@anthropic-ai/sdk');
const fs = require('fs').promises;
const path = require('path');
const yaml = require('js-yaml');

// 환경 변수 설정
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
const ISSUE_BODY = process.env.ISSUE_BODY;
const ISSUE_TITLE = process.env.ISSUE_TITLE;

// API 클라이언트 초기화
const octokit = new Octokit({ auth: GITHUB_TOKEN });
const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY });

// 조직 이름
const ORG_NAME = 'code-orchestration';

async function parseIssueContent() {
  console.log('이슈 내용 파싱 중...');
  
  // YAML 형식의 이슈 내용 파싱
  const lines = ISSUE_BODY.split('\n');
  const issueData = {
    serviceName: '',
    description: '',
    language: '',
    framework: '',
    database: '',
    features: [],
    apiEndpoints: [],
    deployment: ''
  };
  
  let currentSection = '';
  
  for (const line of lines) {
    if (line.includes('### 서비스 이름')) {
      currentSection = 'serviceName';
    } else if (line.includes('### 서비스 설명')) {
      currentSection = 'description';
    } else if (line.includes('### 프로그래밍 언어')) {
      currentSection = 'language';
    } else if (line.includes('### 프레임워크')) {
      currentSection = 'framework';
    } else if (line.includes('### 데이터베이스')) {
      currentSection = 'database';
    } else if (line.includes('### 주요 기능')) {
      currentSection = 'features';
    } else if (line.includes('### API 엔드포인트')) {
      currentSection = 'apiEndpoints';
    } else if (line.includes('### 배포 방식')) {
      currentSection = 'deployment';
    } else if (line.trim() && !line.startsWith('#')) {
      if (currentSection === 'features' || currentSection === 'apiEndpoints') {
        if (line.trim().startsWith('-')) {
          issueData[currentSection].push(line.trim().substring(1).trim());
        }
      } else if (currentSection) {
        issueData[currentSection] += line.trim() + ' ';
      }
    }
  }
  
  // 서비스 이름 정리
  issueData.serviceName = issueData.serviceName.trim() || 
    ISSUE_TITLE.replace('[Service]', '').trim().toLowerCase().replace(/\s+/g, '-');
  
  return issueData;
}

async function createServiceRepository(serviceData) {
  console.log(`서비스 레포지토리 생성 중: ${serviceData.serviceName}`);
  
  try {
    // 레포지토리 생성
    const { data: repo } = await octokit.repos.createInOrg({
      org: ORG_NAME,
      name: serviceData.serviceName,
      description: serviceData.description.trim(),
      private: false,
      auto_init: true
    });
    
    console.log(`레포지토리 생성 완료: ${repo.html_url}`);
    return repo;
  } catch (error) {
    console.error('레포지토리 생성 실패:', error);
    throw error;
  }
}

async function analyzeWithSuperClaude(serviceData) {
  console.log('SuperClaude 아키텍처 페르소나로 서비스 분석 중...');
  
  const prompt = `
당신은 SuperClaude의 아키텍처 페르소나입니다. 다음 서비스에 대한 상세한 기능 명세와 구현 계획을 작성해주세요.

서비스 정보:
- 이름: ${serviceData.serviceName}
- 설명: ${serviceData.description}
- 언어: ${serviceData.language}
- 프레임워크: ${serviceData.framework}
- 데이터베이스: ${serviceData.database}
- 주요 기능: ${serviceData.features.join(', ')}
- API 엔드포인트: ${serviceData.apiEndpoints.join(', ')}
- 배포 방식: ${serviceData.deployment}

다음 형식으로 이슈들을 생성해주세요:

1. 프로젝트 초기 설정
2. 데이터베이스 모델 설계 및 구현
3. API 엔드포인트 구현
4. 비즈니스 로직 구현
5. 테스트 코드 작성
6. 배포 환경 구성

각 이슈에 대해 다음 정보를 포함해주세요:
- 제목
- 상세 설명
- 구현해야 할 구체적인 기능들
- 성공 기준

JSON 형식으로 응답해주세요.
`;
  
  try {
    const response = await anthropic.messages.create({
      model: 'claude-3-5-sonnet-20241022',
      max_tokens: 4000,
      temperature: 0.7,
      messages: [{
        role: 'user',
        content: prompt
      }]
    });
    
    // JSON 파싱
    const content = response.content[0].text;
    const jsonMatch = content.match(/```json\n([\s\S]*?)\n```/);
    
    if (jsonMatch) {
      return JSON.parse(jsonMatch[1]);
    } else {
      // JSON 블록이 없으면 전체 내용을 파싱 시도
      return JSON.parse(content);
    }
  } catch (error) {
    console.error('SuperClaude 분석 실패:', error);
    // 기본 이슈 세트 반환
    return generateDefaultIssues(serviceData);
  }
}

function generateDefaultIssues(serviceData) {
  return [
    {
      title: '프로젝트 초기 설정',
      description: `${serviceData.framework} 프로젝트 초기 설정 및 의존성 설치`,
      tasks: [
        '프로젝트 구조 생성',
        '필요한 패키지 설치',
        '환경 변수 설정',
        'ESLint/Prettier 설정'
      ],
      labels: ['setup', 'priority-high']
    },
    {
      title: '데이터베이스 모델 설계',
      description: `${serviceData.database} 데이터베이스 스키마 설계 및 구현`,
      tasks: [
        '데이터 모델 정의',
        '마이그레이션 파일 생성',
        'ORM/ODM 설정',
        '시드 데이터 생성'
      ],
      labels: ['database', 'priority-high']
    },
    {
      title: 'API 엔드포인트 구현',
      description: 'RESTful API 엔드포인트 구현',
      tasks: serviceData.apiEndpoints.length > 0 ? serviceData.apiEndpoints : [
        'CRUD 엔드포인트 구현',
        '입력 검증 미들웨어',
        '에러 핸들링',
        'API 문서화'
      ],
      labels: ['api', 'priority-high']
    },
    {
      title: '비즈니스 로직 구현',
      description: '핵심 비즈니스 로직 구현',
      tasks: serviceData.features,
      labels: ['feature', 'priority-medium']
    },
    {
      title: '테스트 코드 작성',
      description: '단위 테스트 및 통합 테스트 작성',
      tasks: [
        '단위 테스트 작성',
        '통합 테스트 작성',
        'API 테스트 작성',
        '테스트 커버리지 80% 이상 달성'
      ],
      labels: ['testing', 'priority-medium']
    },
    {
      title: '배포 환경 구성',
      description: `${serviceData.deployment} 배포 환경 구성`,
      tasks: [
        'Dockerfile 작성',
        'CI/CD 파이프라인 설정',
        '환경별 설정 파일 작성',
        '모니터링 설정'
      ],
      labels: ['deployment', 'priority-low']
    }
  ];
}

async function createIssues(repo, issues) {
  console.log('이슈 생성 중...');
  const createdIssues = [];
  
  for (const issue of issues) {
    try {
      const body = `
## 설명
${issue.description}

## 구현해야 할 기능
${issue.tasks ? issue.tasks.map(task => `- [ ] ${task}`).join('\n') : ''}

## 성공 기준
- 모든 기능이 정상적으로 작동
- 테스트 코드 작성 완료
- 코드 리뷰 통과
`;
      
      const { data: createdIssue } = await octokit.issues.create({
        owner: ORG_NAME,
        repo: repo.name,
        title: issue.title,
        body: body,
        labels: issue.labels || []
      });
      
      createdIssues.push(createdIssue);
      console.log(`이슈 생성 완료: ${issue.title}`);
    } catch (error) {
      console.error(`이슈 생성 실패: ${issue.title}`, error);
    }
  }
  
  return createdIssues;
}

async function setupCICD(repo, serviceData) {
  console.log('CI/CD 파이프라인 설정 중...');
  
  // GitHub Actions 워크플로우 생성
  const workflowContent = generateWorkflowContent(serviceData);
  
  try {
    // .github/workflows 디렉토리 생성 및 워크플로우 파일 추가
    await octokit.repos.createOrUpdateFileContents({
      owner: ORG_NAME,
      repo: repo.name,
      path: '.github/workflows/ci-cd.yml',
      message: 'Add CI/CD pipeline',
      content: Buffer.from(workflowContent).toString('base64')
    });
    
    console.log('CI/CD 파이프라인 설정 완료');
  } catch (error) {
    console.error('CI/CD 설정 실패:', error);
  }
}

function generateWorkflowContent(serviceData) {
  const languageConfig = getLanguageConfig(serviceData.language);
  
  return `name: CI/CD Pipeline

on:
  pull_request:
    branches: [develop, main]
  push:
    branches: [main]
  issues:
    types: [opened, labeled]

jobs:
  lint-and-test:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup ${serviceData.language}
        ${languageConfig.setup}
      
      - name: Install dependencies
        run: ${languageConfig.install}
      
      - name: Run linter
        run: ${languageConfig.lint}
      
      - name: Run tests
        run: ${languageConfig.test}
      
      - name: SuperClaude QA Review
        env:
          ANTHROPIC_API_KEY: \${{ secrets.ANTHROPIC_API_KEY }}
          GITHUB_TOKEN: \${{ secrets.GITHUB_TOKEN }}
        run: |
          # SuperClaude QA 페르소나를 통한 코드 리뷰
          node .github/scripts/qa-review.js

  auto-develop:
    if: github.event_name == 'issues' && contains(github.event.issue.labels.*.name, 'auto-develop')
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: SuperClaude Developer
        env:
          ANTHROPIC_API_KEY: \${{ secrets.ANTHROPIC_API_KEY }}
          GITHUB_TOKEN: \${{ secrets.GITHUB_TOKEN }}
          ISSUE_NUMBER: \${{ github.event.issue.number }}
        run: |
          # SuperClaude 개발자 페르소나를 통한 자동 개발
          node .github/scripts/auto-develop.js

  deploy:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    needs: [lint-and-test]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy to ${serviceData.deployment}
        run: |
          echo "Deploying to ${serviceData.deployment}..."
          # 배포 스크립트 실행
`;
}

function getLanguageConfig(language) {
  const configs = {
    'Node.js (TypeScript)': {
      setup: `uses: actions/setup-node@v4
        with:
          node-version: '20'`,
      install: 'npm ci',
      lint: 'npm run lint',
      test: 'npm test'
    },
    'Python': {
      setup: `uses: actions/setup-python@v4
        with:
          python-version: '3.11'`,
      install: 'pip install -r requirements.txt',
      lint: 'flake8 .',
      test: 'pytest'
    },
    'Go': {
      setup: `uses: actions/setup-go@v4
        with:
          go-version: '1.21'`,
      install: 'go mod download',
      lint: 'golangci-lint run',
      test: 'go test ./...'
    },
    'Java': {
      setup: `uses: actions/setup-java@v3
        with:
          java-version: '17'
          distribution: 'temurin'`,
      install: './gradlew dependencies',
      lint: './gradlew checkstyle',
      test: './gradlew test'
    }
  };
  
  return configs[language] || configs['Node.js (TypeScript)'];
}

async function main() {
  try {
    // 1. 이슈 내용 파싱
    const serviceData = await parseIssueContent();
    console.log('파싱된 서비스 데이터:', serviceData);
    
    // 2. 서비스 레포지토리 생성
    const repo = await createServiceRepository(serviceData);
    
    // 3. SuperClaude로 서비스 분석
    const issues = await analyzeWithSuperClaude(serviceData);
    
    // 4. 이슈 생성
    const createdIssues = await createIssues(repo, Array.isArray(issues) ? issues : generateDefaultIssues(serviceData));
    
    // 5. CI/CD 파이프라인 설정
    await setupCICD(repo, serviceData);
    
    // 6. 결과 저장
    const result = {
      success: true,
      repoName: repo.name,
      repoUrl: repo.html_url,
      status: '서비스 레포지토리 생성 및 초기 설정 완료',
      issuesCreated: createdIssues.length
    };
    
    await fs.writeFile('service-creation-result.json', JSON.stringify(result, null, 2));
    console.log('서비스 생성 완료:', result);
    
  } catch (error) {
    console.error('서비스 생성 실패:', error);
    
    const result = {
      success: false,
      message: error.message
    };
    
    await fs.writeFile('service-creation-result.json', JSON.stringify(result, null, 2));
    process.exit(1);
  }
}

// 스크립트 실행
main();