const { Octokit } = require('@octokit/rest');
const Anthropic = require('@anthropic-ai/sdk');
const fs = require('fs').promises;
const { execSync } = require('child_process');

// 환경 변수
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
const ISSUE_NUMBER = process.env.ISSUE_NUMBER;

// API 클라이언트
const octokit = new Octokit({ auth: GITHUB_TOKEN });
const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY });

// 레포지토리 정보
const [owner, repo] = process.env.GITHUB_REPOSITORY.split('/');

async function getIssueDetails() {
  const { data: issue } = await octokit.issues.get({
    owner,
    repo,
    issue_number: ISSUE_NUMBER
  });
  
  return issue;
}

async function generateCodeWithSuperClaude(issue) {
  console.log('SuperClaude 개발자 페르소나로 코드 생성 중...');
  
  const prompt = `
당신은 SuperClaude의 개발자 페르소나입니다. 다음 이슈를 해결하는 코드를 작성해주세요.

이슈 제목: ${issue.title}
이슈 내용:
${issue.body}

다음 요구사항을 준수해주세요:
1. 깔끔하고 유지보수가 쉬운 코드 작성
2. 적절한 에러 처리
3. 필요한 경우 단위 테스트 포함
4. 코드 주석 추가
5. SOLID 원칙 준수

생성해야 할 파일들과 내용을 JSON 형식으로 응답해주세요:
{
  "files": [
    {
      "path": "src/example.js",
      "content": "파일 내용",
      "action": "create" // create, update, delete
    }
  ],
  "commitMessage": "커밋 메시지",
  "branchName": "feature/branch-name"
}
`;
  
  try {
    const response = await anthropic.messages.create({
      model: 'claude-3-5-sonnet-20241022',
      max_tokens: 8000,
      temperature: 0.3,
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
    console.error('코드 생성 실패:', error);
    throw error;
  }
}

async function createBranch(branchName) {
  console.log(`브랜치 생성: ${branchName}`);
  
  try {
    // 기본 브랜치 정보 가져오기
    const { data: repoData } = await octokit.repos.get({ owner, repo });
    const defaultBranch = repoData.default_branch;
    
    // 기본 브랜치의 최신 커밋 가져오기
    const { data: ref } = await octokit.git.getRef({
      owner,
      repo,
      ref: `heads/${defaultBranch}`
    });
    
    // 새 브랜치 생성
    await octokit.git.createRef({
      owner,
      repo,
      ref: `refs/heads/${branchName}`,
      sha: ref.object.sha
    });
    
    console.log(`브랜치 생성 완료: ${branchName}`);
    return branchName;
  } catch (error) {
    if (error.status === 422) {
      console.log(`브랜치가 이미 존재함: ${branchName}`);
      return branchName;
    }
    throw error;
  }
}

async function applyChanges(branchName, files) {
  console.log('파일 변경사항 적용 중...');
  
  for (const file of files) {
    try {
      if (file.action === 'create' || file.action === 'update') {
        // 파일 내용을 Base64로 인코딩
        const content = Buffer.from(file.content).toString('base64');
        
        // 기존 파일 확인
        let sha;
        try {
          const { data: existingFile } = await octokit.repos.getContent({
            owner,
            repo,
            path: file.path,
            ref: branchName
          });
          sha = existingFile.sha;
        } catch (e) {
          // 파일이 존재하지 않음 (새 파일)
        }
        
        // 파일 생성 또는 업데이트
        await octokit.repos.createOrUpdateFileContents({
          owner,
          repo,
          path: file.path,
          message: `${file.action === 'create' ? 'Create' : 'Update'} ${file.path}`,
          content: content,
          branch: branchName,
          sha: sha
        });
        
        console.log(`파일 ${file.action}: ${file.path}`);
      } else if (file.action === 'delete') {
        // 파일 삭제
        const { data: fileData } = await octokit.repos.getContent({
          owner,
          repo,
          path: file.path,
          ref: branchName
        });
        
        await octokit.repos.deleteFile({
          owner,
          repo,
          path: file.path,
          message: `Delete ${file.path}`,
          sha: fileData.sha,
          branch: branchName
        });
        
        console.log(`파일 삭제: ${file.path}`);
      }
    } catch (error) {
      console.error(`파일 처리 실패 (${file.path}):`, error);
    }
  }
}

async function createPullRequest(branchName, commitMessage, issueNumber) {
  console.log('Pull Request 생성 중...');
  
  try {
    const { data: pr } = await octokit.pulls.create({
      owner,
      repo,
      title: commitMessage,
      head: branchName,
      base: 'develop', // Git Flow에 따라 develop 브랜치로 PR
      body: `이슈 #${issueNumber} 해결\n\n## 변경사항\n${commitMessage}\n\n## 체크리스트\n- [ ] 코드 리뷰 통과\n- [ ] 테스트 통과\n- [ ] 린트 통과`
    });
    
    console.log(`PR 생성 완료: ${pr.html_url}`);
    
    // 이슈에 PR 링크 댓글 추가
    await octokit.issues.createComment({
      owner,
      repo,
      issue_number: issueNumber,
      body: `🤖 **SuperClaude 개발자가 자동으로 코드를 생성했습니다!**\n\nPull Request: #${pr.number}\n${pr.html_url}\n\n자동 테스트와 리뷰가 진행됩니다.`
    });
    
    return pr;
  } catch (error) {
    console.error('PR 생성 실패:', error);
    throw error;
  }
}

async function main() {
  try {
    // 1. 이슈 정보 가져오기
    const issue = await getIssueDetails();
    console.log(`이슈 처리 중: #${issue.number} - ${issue.title}`);
    
    // 2. SuperClaude로 코드 생성
    const codeGeneration = await generateCodeWithSuperClaude(issue);
    
    // 3. 브랜치 생성
    const branchName = codeGeneration.branchName || `feature/issue-${issue.number}`;
    await createBranch(branchName);
    
    // 4. 파일 변경사항 적용
    await applyChanges(branchName, codeGeneration.files);
    
    // 5. Pull Request 생성
    const commitMessage = codeGeneration.commitMessage || `Fix #${issue.number}: ${issue.title}`;
    await createPullRequest(branchName, commitMessage, issue.number);
    
    console.log('자동 개발 완료!');
  } catch (error) {
    console.error('자동 개발 실패:', error);
    
    // 이슈에 실패 댓글 추가
    await octokit.issues.createComment({
      owner,
      repo,
      issue_number: ISSUE_NUMBER,
      body: `❌ **자동 개발 실패**\n\n에러: ${error.message}\n\n수동으로 처리가 필요합니다.`
    });
    
    process.exit(1);
  }
}

// 스크립트 실행
main();