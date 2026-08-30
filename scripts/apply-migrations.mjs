// supabase/migrations 중 미적용 파일을 지정 프로젝트에 순서대로 적용하는 스크립트 (로컬 실행 전용)
// `supabase db push`가 cli_login_postgres 권한 오류로 고장나 있어 Management API로 SQL을 직접 실행한다.
// 사용법: node scripts/apply-migrations.mjs <project-ref> [--dry-run] [--bootstrap]
//   staging: kilkzezzkvyegnuubltg / prod: fvhrydkofctahxwyvsnp  — 항상 staging 먼저 적용해 검증 후 prod
//   --file <path>: 임의 SQL 파일 1개 실행 (히스토리 미등록 — 부분 적용·수동 보정용)
//   --mark <version>: 실행 없이 히스토리만 등록 (스냅샷에 이미 반영된 마이그레이션 처리용)
//   --bootstrap: 빈 프로젝트에 초기 스냅샷(supabase_schema.sql + supabase_storage.sql)을 먼저 적용
// 인증: SUPABASE_ACCESS_TOKEN env 또는 macOS 키체인의 Supabase CLI 로그인 토큰
import { execSync } from "node:child_process";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const [projectRef, ...flags] = process.argv.slice(2);
if (!projectRef) {
  console.error("사용법: node scripts/apply-migrations.mjs <project-ref> [--dry-run]");
  process.exit(1);
}
const dryRun = flags.includes("--dry-run");
const bootstrap = flags.includes("--bootstrap");
const BOOTSTRAP_FILES = ["supabase_schema.sql", "supabase_storage.sql"];
const MIGRATIONS_DIR = "supabase/migrations";

function accessToken() {
  if (process.env.SUPABASE_ACCESS_TOKEN) return process.env.SUPABASE_ACCESS_TOKEN;
  const raw = execSync('security find-generic-password -s "Supabase CLI" -w', { encoding: "utf8" }).trim();
  return Buffer.from(raw.replace("go-keyring-base64:", ""), "base64").toString("utf8");
}
const token = accessToken();

async function query(sql) {
  const res = await fetch(`https://api.supabase.com/v1/projects/${projectRef}/database/query`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ query: sql }),
  });
  const body = await res.text();
  if (!res.ok) throw new Error(`${res.status} ${body}`);
  return body ? JSON.parse(body) : [];
}

if (bootstrap && !dryRun) {
  const [{ exists }] = await query("select to_regclass('public.users') is not null as exists");
  if (exists) {
    console.error("public.users가 이미 존재 — --bootstrap은 빈 프로젝트에서만 실행");
    process.exit(1);
  }
  for (const file of BOOTSTRAP_FILES) {
    await query(readFileSync(file, "utf8"));
    console.log(`✓ ${file} (bootstrap)`);
  }
}

// 히스토리 테이블은 CLI가 첫 push 때 만드는 것이라 새 프로젝트에는 없을 수 있음
await query(`
  create schema if not exists supabase_migrations;
  create table if not exists supabase_migrations.schema_migrations (
    version text primary key, statements text[], name text
  );`);
const applied = new Set((await query("select version from supabase_migrations.schema_migrations")).map((r) => r.version));

const fileIndex = flags.indexOf("--file");
if (fileIndex !== -1) {
  const rows = await query(readFileSync(flags[fileIndex + 1], "utf8"));
  if (rows.length) console.log(JSON.stringify(rows, null, 1)); // SELECT 결과 출력 (스키마 대조용)
  console.log(`✓ ${flags[fileIndex + 1]} (ad-hoc)`);
  process.exit(0);
}

const markIndex = flags.indexOf("--mark");
if (markIndex !== -1) {
  const version = flags[markIndex + 1];
  await query(`insert into supabase_migrations.schema_migrations (version, name) values ('${version}', 'marked-as-applied') on conflict do nothing`);
  console.log(`= ${version} 히스토리 등록 (실행 없음)`);
  process.exit(0);
}

const files = readdirSync(MIGRATIONS_DIR).filter((f) => f.endsWith(".sql")).sort();
const pending = files.filter((f) => !applied.has(f.split("_")[0]));
console.log(`[${projectRef}] 적용됨 ${applied.size} / 미적용 ${pending.length}${dryRun ? " (dry-run)" : ""}`);
for (const file of pending) console.log(`  - ${file}`);
if (dryRun) process.exit(0);

for (const file of pending) {
  const version = file.split("_")[0];
  const name = file.slice(version.length + 1, -".sql".length);
  const sql = readFileSync(join(MIGRATIONS_DIR, file), "utf8");
  try {
    await query(sql);
    await query(`insert into supabase_migrations.schema_migrations (version, name) values ('${version}', '${name.replace(/'/g, "''")}')`);
    console.log(`✓ ${file}`);
  } catch (error) {
    console.error(`✗ ${file}\n${error.message}`);
    process.exit(1); // 순서 의존성 때문에 첫 실패에서 중단 — 원인 수정 후 재실행하면 이어서 적용
  }
}
await query("NOTIFY pgrst, 'reload schema';"); // 함수/뷰 변경을 PostgREST에 반영
console.log("완료");
