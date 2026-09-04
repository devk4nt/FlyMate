// 읽기 전용 SQL 조회용 (apply-migrations.mjs의 인증/쿼리 방식 재사용)
// 사용법: node q.mjs <project-ref> "<sql>"
import { execSync } from "node:child_process";

function accessToken() {
  if (process.env.SUPABASE_ACCESS_TOKEN) return process.env.SUPABASE_ACCESS_TOKEN;
  const raw = execSync('security find-generic-password -s "Supabase CLI" -w', { encoding: "utf8" }).trim();
  return Buffer.from(raw.replace("go-keyring-base64:", ""), "base64").toString("utf8");
}

const [projectRef, sql] = process.argv.slice(2);
const res = await fetch(`https://api.supabase.com/v1/projects/${projectRef}/database/query`, {
  method: "POST",
  headers: { Authorization: `Bearer ${accessToken()}`, "Content-Type": "application/json" },
  body: JSON.stringify({ query: sql }),
});
const body = await res.text();
if (!res.ok) {
  console.error(res.status, body);
  process.exit(1);
}
console.table(JSON.parse(body));
