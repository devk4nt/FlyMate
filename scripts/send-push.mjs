// 임의 푸시 발송 (공지/알림함 행 없이 FCM만) — 기능 넛지용
// 사용법: node scripts/send-push.mjs --title "제목" --body "본문" [--dry-run] [--emails a@x,b@y] [--ref <project-ref>]
//   알림함(notifications)에 남지 않는다. 기록이 필요하면 공지 경로(scripts/fixtures/publish-*-announcement.sql)를 쓸 것.
//   data.type 은 보내지 않는다 — AppFeature 푸시 라우팅(recruit/study/video)에 해당 없이 앱만 열리게 한다.
// 인증: macOS 키체인의 Supabase CLI 토큰 + Firebase 서비스 계정 JSON
import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";
import crypto from "node:crypto";

const flags = process.argv.slice(2);
const arg = (name) => {
  const i = flags.indexOf(name);
  return i !== -1 ? flags[i + 1] : null;
};
const title = arg("--title");
const body = arg("--body");
if (!title || !body) {
  console.error('사용법: node scripts/send-push.mjs --title "제목" --body "본문" [--dry-run] [--emails a@x,b@y] [--ref <project-ref>]');
  process.exit(1);
}
const dryRun = flags.includes("--dry-run");
const onlyEmails = arg("--emails")?.split(",").map((e) => e.trim()).filter(Boolean) ?? null;

const PROJECT_REF = arg("--ref") || "fvhrydkofctahxwyvsnp"; // 기본 prod, staging은 --ref kilkzezzkvyegnuubltg
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
  const text = await res.text();
  if (!res.ok) throw new Error(`${res.status} ${text}`);
  return JSON.parse(text);
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

const sqlList = (emails) => emails.map((e) => `'${e.replace(/'/g, "''")}'`).join(", ");
const rows = await query(`
  select u.email, dt.fcm_token
  from device_tokens dt
  join users u on u.id = dt.user_id
  where dt.notifications_enabled = true
    and u.notifications_enabled = true
    ${onlyEmails ? `and u.email in (${sqlList(onlyEmails)})` : ""}
  order by u.email`);

console.log(`제목: ${title}\n본문: ${body}`);
console.log(`\n대상 토큰 ${rows.length}개 / 사용자 ${new Set(rows.map((r) => r.email)).size}명${dryRun ? " — dry-run (발송 안 함)" : ""}\n`);
if (dryRun) {
  for (const email of [...new Set(rows.map((r) => r.email))]) console.log(`  ${email}`);
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
        notification: { title, body },
        apns: { payload: { aps: { sound: "default" } } },
      },
    }),
  });
  let code = "OK";
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    code = err.error?.details?.[0]?.errorCode || err.error?.status || `HTTP_${res.status}`;
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
