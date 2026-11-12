// 공지 푸시 재발송 (알림 행은 이미 존재 — 푸시만 다시 보낸다)
// 사용법: node scripts/resend-announcement-push.mjs <announcement-id> [--dry-run] [--emails a@x,b@y]
//   알림함/팝업은 notifications 행이 이미 있으므로 DB를 건드리지 않는다.
//   INSERT 웹훅을 다시 태우지 않고 FCM에 직접 발송해 토큰별 결과를 기록한다.
//   --emails: 지정한 계정에만 발송 (전체 재발송 전 소규모 검증용)
//   --exclude: 지정한 계정 제외 (이미 받은 계정 중복 발송 방지)
// 인증: macOS 키체인의 Supabase CLI 토큰 + Firebase 서비스 계정 JSON
import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";
import crypto from "node:crypto";

const [announcementID, ...flags] = process.argv.slice(2);
if (!announcementID) {
  console.error("사용법: node scripts/resend-announcement-push.mjs <announcement-id> [--dry-run]");
  process.exit(1);
}
const dryRun = flags.includes("--dry-run");
const emailsFlag = flags[flags.indexOf("--emails") + 1];
const onlyEmails = flags.includes("--emails") && emailsFlag
  ? emailsFlag.split(",").map((e) => e.trim()).filter(Boolean)
  : null;
if (flags.includes("--emails") && !onlyEmails) {
  console.error("--emails 뒤에 쉼표로 구분한 이메일이 필요합니다");
  process.exit(1);
}
const excludeFlag = flags[flags.indexOf("--exclude") + 1];
const excludeEmails = flags.includes("--exclude") && excludeFlag
  ? excludeFlag.split(",").map((e) => e.trim()).filter(Boolean)
  : null;
if (flags.includes("--exclude") && !excludeEmails) {
  console.error("--exclude 뒤에 쉼표로 구분한 이메일이 필요합니다");
  process.exit(1);
}
const sqlList = (emails) => emails.map((e) => `'${e.replace(/'/g, "''")}'`).join(", ");
const PROJECT_REF = "fvhrydkofctahxwyvsnp";
const SERVICE_ACCOUNT = process.env.FIREBASE_SERVICE_ACCOUNT_JSON
  || "/Users/jaejun/Downloads/flymate-1cb63-firebase-adminsdk-fbsvc-5092064763.json";

function mgmtToken() {
  if (process.env.SUPABASE_ACCESS_TOKEN) return process.env.SUPABASE_ACCESS_TOKEN;
  const raw = execSync('security find-generic-password -s "Supabase CLI" -w', { encoding: "utf8" }).trim();
  return Buffer.from(raw.replace("go-keyring-base64:", ""), "base64").toString("utf8");
}

async function query(sql) {
  const res = await fetch(`https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query`, {
    method: "POST",
    headers: { Authorization: `Bearer ${mgmtToken()}`, "Content-Type": "application/json" },
    body: JSON.stringify({ query: sql }),
  });
  const body = await res.text();
  if (!res.ok) throw new Error(`${res.status} ${body}`);
  return JSON.parse(body);
}

const sa = JSON.parse(readFileSync(SERVICE_ACCOUNT, "utf8"));
const b64url = (b) => Buffer.from(b).toString("base64url");

async function accessToken() {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = b64url(JSON.stringify({
    iss: sa.client_email, sub: sa.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now, exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  }));
  const sig = crypto.sign("RSA-SHA256", Buffer.from(`${header}.${payload}`), sa.private_key).toString("base64url");
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${payload}.${sig}`,
    }),
  });
  const data = await res.json();
  if (!data.access_token) throw new Error("OAuth 실패: " + JSON.stringify(data));
  return data.access_token;
}

// 푸시용 요약 body는 notifications 행이 아니라 announcements 원문과 별개이므로
// 최초 발송과 동일한 요약 문구를 쓰기 위해 인자로 받지 않고 상수로 둔다.
const [ann] = await query(`select title, body from announcements where id = '${announcementID}'`);
if (!ann) throw new Error("공지를 찾을 수 없음: " + announcementID);

const PUSH_BODY = "프로필 사진 변경·공지사항 저장 문제를 수정했어요. App Store에서 업데이트해 주세요!";

const rows = await query(`
  select u.email, dt.fcm_token
  from notifications n
  join users u on u.id = n.recipient_id
  join device_tokens dt on dt.user_id = n.recipient_id
  where n.reference_announcement_id = '${announcementID}'
    and dt.notifications_enabled = true
    ${onlyEmails ? `and u.email in (${sqlList(onlyEmails)})` : ""}
    ${excludeEmails ? `and u.email not in (${sqlList(excludeEmails)})` : ""}
  order by u.email`);

console.log(`공지: ${ann.title}`);
console.log(`대상 토큰 ${rows.length}개 (알림 행 보유 사용자의 활성 토큰)${dryRun ? " — dry-run" : ""}\n`);
if (dryRun) {
  const byUser = {};
  for (const r of rows) byUser[r.email] = (byUser[r.email] || 0) + 1;
  for (const [email, n] of Object.entries(byUser)) console.log(`  ${email}: ${n}개`);
  process.exit(0);
}

const token = await accessToken();
const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
const summary = {};
const failures = [];

for (const row of rows) {
  const res = await fetch(url, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      message: {
        token: row.fcm_token,
        notification: { title: ann.title, body: PUSH_BODY },
        data: { type: "announcement" },
        apns: { payload: { aps: { sound: "default", badge: 1 } } },
      },
    }),
  });
  let code = "OK";
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    code = body.error?.details?.[0]?.errorCode || body.error?.status || `HTTP_${res.status}`;
    failures.push(`${row.email} ${row.fcm_token.slice(0, 12)}… ${code}`);
  }
  summary[code] = (summary[code] || 0) + 1;
}

console.log("결과:");
for (const [k, v] of Object.entries(summary).sort((a, b) => b[1] - a[1])) console.log(`  ${k}: ${v}`);
if (failures.length) {
  console.log("\n실패 상세:");
  for (const f of failures) console.log(`  ${f}`);
}
