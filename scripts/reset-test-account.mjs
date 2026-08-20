// 테스트 계정을 신규 유저 상태로 리셋하는 스크립트 (로컬 실행 전용)
// 사용법: node scripts/reset-test-account.mjs <email>
// 인증: SUPABASE_ACCESS_TOKEN env 또는 macOS 키체인의 Supabase CLI 로그인 토큰
//
// 서버에서 지우는 것: 빠른 피드백 요청(배정/리뷰 캐스케이드 삭제) + 지갑(다음 접속 때 웰컴 포인트 재지급)
// 클라이언트(온보딩/가이드라인 UserDefaults)는 앱 삭제로 리셋해야 한다.
import { execSync } from "node:child_process";

const PROJECT_REF = "fvhrydkofctahxwyvsnp";

// 실수로 실제 사용자를 지우는 것을 방지 — 테스트 계정만 허용
const ALLOWED_EMAILS = ["eileenyoo2@gmail.com", "kakao_4764165034@kakao.flymate.app"];

const email = process.argv[2];
if (!email) {
  console.error("사용법: node scripts/reset-test-account.mjs <email>");
  process.exit(1);
}
if (!ALLOWED_EMAILS.includes(email)) {
  console.error(`허용되지 않은 계정: ${email} — ALLOWED_EMAILS에 추가 후 실행하세요.`);
  process.exit(1);
}

function accessToken() {
  if (process.env.SUPABASE_ACCESS_TOKEN) return process.env.SUPABASE_ACCESS_TOKEN;
  const raw = execSync('security find-generic-password -s "Supabase CLI" -w', { encoding: "utf8" }).trim();
  return Buffer.from(raw.replace("go-keyring-base64:", ""), "base64").toString("utf8");
}

const token = accessToken();

async function query(sql) {
  const response = await fetch(`https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ query: sql }),
  });
  if (!response.ok) {
    throw new Error(`Management API ${response.status}: ${await response.text()}`);
  }
  return response.json();
}

const users = await query(`SELECT id FROM auth.users WHERE email = '${email}'`);
if (users.length === 0) {
  console.error(`계정을 찾을 수 없음: ${email}`);
  process.exit(1);
}
const userID = users[0].id;

const [before] = await query(`
  SELECT
    (SELECT count(*) FROM quick_feedback_requests WHERE uploader_id = '${userID}') AS requests,
    (SELECT count(*) FROM quick_feedback_wallets WHERE user_id = '${userID}') AS wallets,
    (SELECT count(*) FROM studies WHERE owner_id = '${userID}') AS owned_studies,
    (SELECT count(*) FROM study_members WHERE user_id = '${userID}') AS joined_studies
`);
console.log(`대상: ${email} (${userID})`);
console.log(`삭제 전: 빠른 피드백 요청 ${before.requests}건, 지갑 ${before.wallets}건`);

// ponytail: 스터디/영상은 안 지운다 — 다른 멤버 데이터에 영향. 필요하면 앱에서 직접 탈퇴/삭제
if (Number(before.owned_studies) > 0 || Number(before.joined_studies) > 0) {
  console.log(`참고: 스터디 데이터는 건드리지 않음 (소유 ${before.owned_studies}, 가입 ${before.joined_studies}) — 앱에서 직접 정리 필요`);
}

await query(`DELETE FROM quick_feedback_requests WHERE uploader_id = '${userID}'`);
await query(`DELETE FROM quick_feedback_wallets WHERE user_id = '${userID}'`);

console.log("리셋 완료 — 다음 접속 때 웰컴 포인트 2개가 자동 지급됩니다.");
console.log("온보딩/가이드라인을 다시 보려면 기기에서 앱을 삭제 후 재설치하세요.");
