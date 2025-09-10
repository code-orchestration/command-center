const { Octokit } = require('@octokit/rest');
const Anthropic = require('@anthropic-ai/sdk');
const { execSync } = require('child_process');

// 환경 변수
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
const PR_NUMBER = process.env.GITHUB_EVENT_NAME === 'pull_request' 
  ? JSON.parse(process.env.GITHUB_EVENT_PATH).pull_request.number 
  : null;

// API 클라이언트
const octokit = new Octokit({ auth: GITHUB_TOKEN });
const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY });

// 레포지토리 정보
const [owner, repo] = process.env.GITHUB_REPOSITORY.split('/');

async function getPRDetails() {
  const { data: pr } = await octokit.pulls.get({
    owner,
    repo,
    pull_number: PR_NUMBER
  });
  
  return pr;
}

async function getPRFiles() {
  const { data: files } = await octokit.pulls.listFiles({
    owner,
    repo,
    pull_number: PR_NUMBER
  });
  
  return files;
}

async function reviewWithSuperClaude(pr, files) {
  console.log('SuperClaude QA 페르소나로 코드 리뷰 중...');
  
  // 파일 내용 수집
  const fileContents = await Promise.all(
    files.map(async (file) => {
      if (file.patch) {
        return {
          filename: file.filename,
          status: file.status,
          additions: file.additions,
          deletions: file.deletions,
          patch: file.patch
        };
      }
      return null;
    })
  );
  
  const validFiles = fileContents.filter(f => f !== null);
  
  const prompt = `
당신은 SuperClaude의 QA 페르소나입니다. 다음 Pull Request를 리뷰해주세요.

PR 제목: ${pr.title}
PR 설명: ${pr.body}

변경된 파일들:
${JSON.stringify(validFiles, null, 2)}

다음 관점에서 리뷰해주세요:
1. 코드 품질 (가독성, 유지보수성)
2. 버그 가능성
3. 보안 취약점
4. 성능 이슈
5. 테스트 커버리지
6. 베스트 프랙티스 준수

리뷰 결과를 JSON 형식으로 응답해주세요:
{
  "approved": true/false,
  "issues": [
    {
      "severity": "critical/major/minor",
      "file": "파일명",
      "line": 라인번호,
      "description": "이슈 설명",
      "suggestion": "개선 제안"
    }
  ],
  "generalComments": "전반적인 코멘트",
  "positivePoints": ["잘한 점들"],
  "needsWork": ["개선이 필요한 부분들"]
}
`;
  
  try {
    const response = await anthropic.messages.create({
      model: 'claude-3-5-sonnet-20241022',
      max_tokens: 4000,
      temperature: 0.2,
      messages: [{
        role: 'user',
        content: prompt
      }]
    });
    
    const content = response.content[0].text;
    const jsonMatch = content.match(/```json\n([\s\S]*?)\n```/);
    
    if (jsonMatch) {
      return JSON.parse(jsonMatch[1]);
    } else {
      return JSON.parse(content);
    }
  } catch (error) {
    console.error('리뷰 생성 실패:', error);
    throw error;
  }
}

async function postReviewComments(review) {
  console.log('리뷰 코멘트 작성 중...');
  
  // 전체 리뷰 코멘트 작성
  let reviewBody = `## 🤖 SuperClaude QA 리뷰\n\n`;
  
  if (review.approved) {
    reviewBody += `### ✅ 승인됨\n\n`;
  } else {
    reviewBody += `### ❌ 변경 필요\n\n`;
  }
  
  if (review.generalComments) {
    reviewBody += `**전반적인 코멘트:**\n${review.generalComments}\n\n`;
  }
  
  if (review.positivePoints && review.positivePoints.length > 0) {
    reviewBody += `### 👍 잘한 점\n`;
    review.positivePoints.forEach(point => {
      reviewBody += `- ${point}\n`;
    });
    reviewBody += '\n';
  }
  
  if (review.needsWork && review.needsWork.length > 0) {
    reviewBody += `### 🔧 개선 필요\n`;
    review.needsWork.forEach(point => {
      reviewBody += `- ${point}\n`;
    });
    reviewBody += '\n';
  }
  
  if (review.issues && review.issues.length > 0) {
    reviewBody += `### 🐛 발견된 이슈 (${review.issues.length}개)\n\n`;
    
    // 심각도별로 그룹화
    const criticalIssues = review.issues.filter(i => i.severity === 'critical');
    const majorIssues = review.issues.filter(i => i.severity === 'major');
    const minorIssues = review.issues.filter(i => i.severity === 'minor');
    
    if (criticalIssues.length > 0) {
      reviewBody += `#### 🔴 심각 (${criticalIssues.length})\n`;
      criticalIssues.forEach(issue => {
        reviewBody += `- **${issue.file}**: ${issue.description}\n`;
        if (issue.suggestion) {
          reviewBody += `  - 💡 제안: ${issue.suggestion}\n`;
        }
      });
      reviewBody += '\n';
    }
    
    if (majorIssues.length > 0) {
      reviewBody += `#### 🟡 주요 (${majorIssues.length})\n`;
      majorIssues.forEach(issue => {
        reviewBody += `- **${issue.file}**: ${issue.description}\n`;
        if (issue.suggestion) {
          reviewBody += `  - 💡 제안: ${issue.suggestion}\n`;
        }
      });
      reviewBody += '\n';
    }
    
    if (minorIssues.length > 0) {
      reviewBody += `#### 🟢 경미 (${minorIssues.length})\n`;
      minorIssues.forEach(issue => {
        reviewBody += `- **${issue.file}**: ${issue.description}\n`;
        if (issue.suggestion) {
          reviewBody += `  - 💡 제안: ${issue.suggestion}\n`;
        }
      });
      reviewBody += '\n';
    }
  }
  
  // PR 리뷰 생성
  const reviewEvent = review.approved ? 'APPROVE' : 'REQUEST_CHANGES';
  
  try {
    await octokit.pulls.createReview({
      owner,
      repo,
      pull_number: PR_NUMBER,
      body: reviewBody,
      event: reviewEvent
    });
    
    console.log(`리뷰 완료: ${reviewEvent}`);
  } catch (error) {
    console.error('리뷰 작성 실패:', error);
    // 실패 시 일반 코멘트로 작성
    await octokit.issues.createComment({
      owner,
      repo,
      issue_number: PR_NUMBER,
      body: reviewBody
    });
  }
}

async function createIssuesForProblems(review, pr) {
  if (!review.approved && review.issues && review.issues.length > 0) {
    console.log('발견된 문제에 대한 이슈 생성 중...');
    
    // 심각한 이슈들만 새 이슈로 생성
    const criticalIssues = review.issues.filter(i => i.severity === 'critical' || i.severity === 'major');
    
    if (criticalIssues.length > 0) {
      const issueBody = `
## PR #${PR_NUMBER} 리뷰에서 발견된 문제

### 관련 PR
- #${PR_NUMBER}: ${pr.title}

### 발견된 문제들
${criticalIssues.map((issue, index) => `
#### ${index + 1}. ${issue.description}
- **파일**: ${issue.file}
- **심각도**: ${issue.severity}
- **제안**: ${issue.suggestion || '없음'}
`).join('\n')}

### 해결 방법
위 문제들을 수정한 후 동일한 PR에 추가 커밋을 푸시해주세요.
`;
      
      const { data: newIssue } = await octokit.issues.create({
        owner,
        repo,
        title: `[QA] PR #${PR_NUMBER} 수정 필요`,
        body: issueBody,
        labels: ['bug', 'qa-review', 'auto-develop'],
        assignees: pr.user ? [pr.user.login] : []
      });
      
      console.log(`이슈 생성 완료: #${newIssue.number}`);
      
      // PR에 이슈 링크 코멘트 추가
      await octokit.issues.createComment({
        owner,
        repo,
        issue_number: PR_NUMBER,
        body: `🔧 수정이 필요한 사항들을 이슈 #${newIssue.number}에 정리했습니다.\n\nSuperClaude 개발자가 자동으로 수정을 시도할 예정입니다.`
      });
    }
  }
}

async function main() {
  try {
    if (!PR_NUMBER) {
      console.log('PR 번호를 찾을 수 없습니다.');
      process.exit(0);
    }
    
    // 1. PR 정보 가져오기
    const pr = await getPRDetails();
    console.log(`PR 리뷰 중: #${pr.number} - ${pr.title}`);
    
    // 2. PR 파일 목록 가져오기
    const files = await getPRFiles();
    console.log(`변경된 파일 수: ${files.length}`);
    
    // 3. SuperClaude로 리뷰
    const review = await reviewWithSuperClaude(pr, files);
    
    // 4. 리뷰 코멘트 작성
    await postReviewComments(review);
    
    // 5. 필요 시 이슈 생성
    if (!review.approved) {
      await createIssuesForProblems(review, pr);
    }
    
    console.log('QA 리뷰 완료!');
    
    // 리뷰가 승인되지 않았으면 실패 코드로 종료
    if (!review.approved) {
      console.log('변경이 필요하여 PR이 승인되지 않았습니다.');
      process.exit(1);
    }
  } catch (error) {
    console.error('QA 리뷰 실패:', error);
    
    // 에러 발생 시 PR에 코멘트
    await octokit.issues.createComment({
      owner,
      repo,
      issue_number: PR_NUMBER,
      body: `❌ **QA 리뷰 실패**\n\n에러: ${error.message}\n\n수동 리뷰가 필요합니다.`
    });
    
    process.exit(1);
  }
}

// 스크립트 실행
main();