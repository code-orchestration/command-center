# Command Center - 자동화된 코드 생성 파이프라인

## 개요
SuperClaude 페르소나를 활용한 자동화된 코드 생성 및 관리 시스템

## 주요 기능

### 1. 서비스 생성 자동화
- `service-type` 라벨이 있는 이슈 생성 시 자동으로 새 서비스 레포지토리 생성
- SuperClaude 아키텍처 페르소나를 통한 서비스 설계
- 자동 이슈 생성 및 개발 태스크 할당

### 2. 자동화된 개발 프로세스
- SuperClaude 개발자 페르소나를 통한 자동 코드 생성
- SuperClaude QA 페르소나를 통한 코드 리뷰
- 자동 테스트 및 린팅
- Git Flow 브랜치 전략 자동 적용

### 3. CI/CD 파이프라인
- PR 생성 시 자동 테스트 및 리뷰
- 리뷰 통과 시 자동 머지
- 자동 배포 파이프라인

## 사용 방법

### 새 서비스 생성
1. 이 레포지토리에 새 이슈 생성
2. `service-type` 라벨 추가
3. 이슈 내용에 서비스 요구사항 작성
4. 자동으로 서비스 레포지토리가 생성되고 개발이 시작됨

### 이슈 템플릿 예시
```yaml
title: "[Service] 새로운 마이크로서비스 이름"
labels: service-type
body: |
  ## 서비스 설명
  [서비스의 목적과 주요 기능 설명]
  
  ## 기술 스택
  - 언어: Node.js/Python/Go
  - 프레임워크: Express/FastAPI/Gin
  - 데이터베이스: PostgreSQL/MongoDB
  
  ## 주요 기능
  - [ ] 기능 1
  - [ ] 기능 2
  - [ ] 기능 3
```

## 환경 변수 설정
다음 시크릿을 GitHub 조직 레벨에서 설정해야 합니다:
- `ANTHROPIC_API_KEY`: Claude API 키
- `GH_ORG_TOKEN`: GitHub 조직 관리 토큰

## 아키텍처
```
command-center/
├── .github/
│   ├── workflows/
│   │   ├── service-orchestrator.yml    # 서비스 생성 워크플로우
│   │   └── issue-analyzer.yml          # 이슈 분석 워크플로우
│   └── ISSUE_TEMPLATE/
│       └── service-request.yml         # 서비스 요청 템플릿
├── scripts/
│   ├── create-service.js               # 서비스 생성 스크립트
│   ├── analyze-issue.js                # 이슈 분석 스크립트
│   └── superclaude-integration.js      # SuperClaude 통합
└── templates/
    └── service-template/                # 서비스 레포지토리 템플릿
```