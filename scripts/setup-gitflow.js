const { Octokit } = require('@octokit/rest');

const GITHUB_TOKEN = process.env.GITHUB_TOKEN || process.env.GH_ORG_TOKEN;
const octokit = new Octokit({ auth: GITHUB_TOKEN });

async function setupGitFlow(owner, repo) {
  console.log(`Git Flow 설정 중: ${owner}/${repo}`);
  
  try {
    // develop 브랜치 생성
    try {
      const { data: mainRef } = await octokit.git.getRef({
        owner,
        repo,
        ref: 'heads/main'
      });
      
      await octokit.git.createRef({
        owner,
        repo,
        ref: 'refs/heads/develop',
        sha: mainRef.object.sha
      });
      
      console.log('develop 브랜치 생성 완료');
    } catch (e) {
      if (e.status === 422) {
        console.log('develop 브랜치가 이미 존재합니다');
      }
    }
    
    // 브랜치 보호 규칙 설정 - main 브랜치
    try {
      await octokit.repos.updateBranchProtection({
        owner,
        repo,
        branch: 'main',
        required_status_checks: {
          strict: true,
          contexts: ['lint-and-test']
        },
        enforce_admins: false,
        required_pull_request_reviews: {
          dismissal_restrictions: {},
          dismiss_stale_reviews: true,
          require_code_owner_reviews: false,
          required_approving_review_count: 1
        },
        restrictions: null,
        allow_force_pushes: false,
        allow_deletions: false,
        required_linear_history: false,
        allow_squash_merge: true,
        allow_merge_commit: true,
        allow_rebase_merge: true
      });
      
      console.log('main 브랜치 보호 규칙 설정 완료');
    } catch (e) {
      console.error('main 브랜치 보호 규칙 설정 실패:', e.message);
    }
    
    // 브랜치 보호 규칙 설정 - develop 브랜치
    try {
      await octokit.repos.updateBranchProtection({
        owner,
        repo,
        branch: 'develop',
        required_status_checks: {
          strict: true,
          contexts: ['lint-and-test']
        },
        enforce_admins: false,
        required_pull_request_reviews: {
          dismissal_restrictions: {},
          dismiss_stale_reviews: true,
          require_code_owner_reviews: false,
          required_approving_review_count: 1
        },
        restrictions: null,
        allow_force_pushes: false,
        allow_deletions: false,
        required_linear_history: false,
        allow_squash_merge: true,
        allow_merge_commit: true,
        allow_rebase_merge: true
      });
      
      console.log('develop 브랜치 보호 규칙 설정 완료');
    } catch (e) {
      console.error('develop 브랜치 보호 규칙 설정 실패:', e.message);
    }
    
    // 기본 브랜치를 develop으로 변경 (선택사항)
    // await octokit.repos.update({
    //   owner,
    //   repo,
    //   default_branch: 'develop'
    // });
    
    return true;
  } catch (error) {
    console.error('Git Flow 설정 실패:', error);
    return false;
  }
}

// 명령줄 인자로 실행할 경우
if (require.main === module) {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.log('사용법: node setup-gitflow.js <owner> <repo>');
    process.exit(1);
  }
  
  setupGitFlow(args[0], args[1]).then(success => {
    process.exit(success ? 0 : 1);
  });
}

module.exports = { setupGitFlow };