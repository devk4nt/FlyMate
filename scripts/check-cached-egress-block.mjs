// prod Supabase edge logs에서 Cached Egress 쿼터 초과로 인한 402를 감지한다.
// 2026-10-16 장애(쿼터 초과로 Storage/Auth/REST 전면 차단) 재발을 몇 분 내 포착하기 위한 스크립트.
// 주의: Management API엔 사용량(%) 조회 엔드포인트가 없어 "사전 경고"는 불가 — 402가 뜬 "직후" 감지만 가능하다.
// 사용법: node scripts/check-cached-egress-block.mjs [lookback분, 기본 70]
import { execSync } from "node:child_process";

const PROD_PROJECT_REF = "fvhrydkofctahxwyvsnp";

function accessToken() {
  if (process.env.SUPABASE_ACCESS_TOKEN) return process.env.SUPABASE_ACCESS_TOKEN;
  const raw = execSync('security find-generic-password -s "Supabase CLI" -w', { encoding: "utf8" }).trim();
  return Buffer.from(raw.replace("go-keyring-base64:", ""), "base64").toString("utf8");
}

const lookbackMinutes = Number(process.argv[2] ?? 70);
const end = new Date();
const start = new Date(end.getTime() - lookbackMinutes * 60 * 1000);

const url = new URL(`https://api.supabase.com/v1/projects/${PROD_PROJECT_REF}/analytics/endpoints/logs`);
url.searchParams.set(
  "sql",
  "SELECT count(*) AS c, min(timestamp) AS first_seen, max(timestamp) AS last_seen " +
    "FROM logs WHERE event_message LIKE '%| 402 |%'"
);
url.searchParams.set("iso_timestamp_start", start.toISOString());
url.searchParams.set("iso_timestamp_end", end.toISOString());

const res = await fetch(url, { headers: { Authorization: `Bearer ${accessToken()}` } });
const body = await res.text();
if (!res.ok) {
  console.error("조회 실패:", res.status, body);
  process.exit(1);
}

const row = JSON.parse(body).result?.[0];
const count = Number(row?.c ?? 0);

if (count > 0) {
  console.log(`ALERT: 최근 ${lookbackMinutes}분 사이 402(Cached Egress 쿼터 초과 추정) ${count}건 발생`);
  console.log(`  first_seen(UTC): ${row.first_seen}`);
  console.log(`  last_seen(UTC):  ${row.last_seen}`);
  process.exit(2);
}

console.log(`OK: 최근 ${lookbackMinutes}분 사이 402 없음`);
