// Staging 전용 샘플 데이터 시딩 스크립트 (로컬 실행 전용)
// 사용법: node scripts/seed-staging.mjs
// 인증: SUPABASE_ACCESS_TOKEN env 또는 macOS 키체인의 Supabase CLI 로그인 토큰
//
// 만드는 것:
//   - 테스트 계정 3개 (auth + users 프로필): 김하늘(방장)/이수민(멤버)/박지원(신청자)
//     이메일·비밀번호는 mise.local.toml의 FlyMate-Owner/Member/Applicant 스킴과 동일
//   - 스터디 1개 (방장+멤버 가입, 신청자는 pending 가입 신청, 공지 등록)
//   - 영상 2개 (스토리지 실파일 업로드 → 앱에서 실제 재생 가능)
//   - 피드백 3개 (멘션 포함) + 피드백 댓글 1개 (알림은 DB 트리거가 자동 생성)
//   - 모집글 1개 (스터디 연결) + 모집글 댓글 1개
//
// 고정 UUID(5eed…)로 시딩하므로 재실행해도 중복 생성되지 않는다 (ON CONFLICT DO NOTHING).
import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

// ponytail: staging 전용 하드코딩 — prod ref를 넣을 수 있는 입구 자체를 없앤다
const PROJECT_REF = "kilkzezzkvyegnuubltg";
const SUPABASE_URL = `https://${PROJECT_REF}.supabase.co`;

const ACCOUNTS = [
  { email: "test@flymate.app", name: "김하늘", role: "owner" },
  { email: "test2@flymate.app", name: "이수민", role: "member" },
  { email: "test3@flymate.app", name: "박지원", role: "applicant" },
];

// 스킴(FlyMate-Owner/Member/Applicant)과 동일한 비밀번호 — mise.local.toml에서 읽는다
const fixtures = join(dirname(fileURLToPath(import.meta.url)), "fixtures");
const misePath = join(dirname(fixtures), "..", "mise.local.toml");
const password = readFileSync(misePath, "utf8").match(/TUIST_TEST_PASSWORD\s*=\s*"([^"]+)"/)?.[1];
if (!password) {
  console.error("mise.local.toml에서 TUIST_TEST_PASSWORD를 찾을 수 없습니다.");
  process.exit(1);
}

// 고정 UUID — 재실행 멱등성 + 디버깅 시 식별 용이 (5eed = seed)
const STUDY_ID = "5eed0000-0000-4000-8000-000000000001";
const VIDEO1_ID = "5eed0000-0000-4000-8000-000000000101"; // 방장 업로드
const VIDEO2_ID = "5eed0000-0000-4000-8000-000000000102"; // 멤버 업로드
const FEEDBACK1_ID = "5eed0000-0000-4000-8000-000000000201";
const FEEDBACK2_ID = "5eed0000-0000-4000-8000-000000000202";
const FEEDBACK3_ID = "5eed0000-0000-4000-8000-000000000203";
const COMMENT_ID = "5eed0000-0000-4000-8000-000000000301";
const RECRUIT_POST_ID = "5eed0000-0000-4000-8000-000000000501";
const RECRUIT_COMMENT_ID = "5eed0000-0000-4000-8000-000000000502";
const INVITE_CODE = "FLYSTG";

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

// 1. service_role 키 확보 (Auth Admin API·Storage 업로드용)
const keys = await (await fetch(`https://api.supabase.com/v1/projects/${PROJECT_REF}/api-keys?reveal=true`, {
  headers: { Authorization: `Bearer ${token}` },
})).json();
const serviceKey = keys.find((k) => k.name === "service_role")?.api_key;
if (!serviceKey) throw new Error("service_role 키를 찾을 수 없습니다.");

// 2. 테스트 계정 생성 (이미 있으면 조회만)
async function ensureUser({ email, name }) {
  const response = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
    method: "POST",
    headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
      user_metadata: { name }, // handle_new_user 트리거가 users.name으로 사용
    }),
  });
  if (response.ok) {
    const user = await response.json();
    console.log(`계정 생성: ${email} (${name})`);
    return user.id;
  }
  const body = await response.text();
  if (response.status === 422 || body.includes("already been registered")) {
    const rows = await query(`SELECT id FROM auth.users WHERE email = '${email}'`);
    if (rows.length === 0) throw new Error(`계정 조회 실패: ${email}`);
    console.log(`계정 존재: ${email}`);
    return rows[0].id;
  }
  throw new Error(`계정 생성 실패 ${email}: ${response.status} ${body}`);
}

const [ownerID, memberID, applicantID] = await Promise.all(ACCOUNTS.map(ensureUser));

// 3. 스토리지 업로드 (영상 실파일 + 썸네일 — 없으면 앱에서 재생/표시 불가)
const videoData = readFileSync(join(fixtures, "sample-video.mp4"));
const thumbnailData = readFileSync(join(fixtures, "sample-thumbnail.jpg"));

async function uploadStorage(bucket, path, data, contentType) {
  const response = await fetch(`${SUPABASE_URL}/storage/v1/object/${bucket}/${path}`, {
    method: "POST",
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": contentType,
      "x-upsert": "true",
    },
    body: data,
  });
  if (!response.ok) throw new Error(`스토리지 업로드 실패 ${path}: ${response.status} ${await response.text()}`);
  console.log(`업로드: ${bucket}/${path}`);
}

// 앱의 StorageService.videoPath는 UUID 문자열 보간(대문자)로 경로를 만든다 — 반드시 대문자로 업로드
for (const videoID of [VIDEO1_ID, VIDEO2_ID]) {
  await uploadStorage("videos", `${STUDY_ID.toUpperCase()}/${videoID.toUpperCase()}.mp4`, videoData, "video/mp4");
  await uploadStorage("thumbnails", `${STUDY_ID}/${videoID}.jpg`, thumbnailData, "image/jpeg");
}
const thumbnailURL = (videoID) =>
  `${SUPABASE_URL}/storage/v1/object/public/thumbnails/${STUDY_ID}/${videoID}.jpg`;

// 영상 fixture의 실제 길이(초) — DB의 duration_seconds와 대략 일치시키면 UI 표기가 자연스럽다
const VIDEO_DURATION = 72;

// 4. 데이터 시딩 (전부 ON CONFLICT DO NOTHING — 재실행 안전)
await query(`
-- 스터디 (방장: 김하늘, 무료 플랜 기준 멤버 3명 제한)
INSERT INTO studies (id, name, description, owner_id, invite_code, max_members, notice, notice_updated_at)
VALUES ('${STUDY_ID}', '승무원 영상면접 스터디', '대한항공·아시아나 승무원 준비생 모임입니다. 매주 영상 올리고 서로 피드백해요!',
        '${ownerID}', '${INVITE_CODE}', 3,
        '매주 화/목 21시 줌 모의면접 진행합니다. 영상은 최소 하루 전에 올려주세요 ✈️', now())
ON CONFLICT (id) DO NOTHING;

-- 멤버십 (방장 + 멤버)
INSERT INTO study_members (study_id, user_id, user_name, role)
VALUES ('${STUDY_ID}', '${ownerID}', '김하늘', 'owner'),
       ('${STUDY_ID}', '${memberID}', '이수민', 'member')
ON CONFLICT (study_id, user_id) DO NOTHING;

-- 가입 신청 (박지원, pending — 방장 승인 플로우 테스트용, 이름은 트리거가 채움)
INSERT INTO study_join_requests (study_id, user_id, status)
VALUES ('${STUDY_ID}', '${applicantID}', 'pending')
ON CONFLICT (study_id, user_id) DO NOTHING;

-- 영상 2개 (스토리지 실파일과 경로 일치)
INSERT INTO videos (id, study_id, uploader_id, uploader_name, title, video_url, thumbnail_url, duration_seconds, created_at)
VALUES ('${VIDEO1_ID}', '${STUDY_ID}', '${ownerID}', '김하늘', '1분 자기소개 연습',
        '${STUDY_ID}/${VIDEO1_ID}.mp4', '${thumbnailURL(VIDEO1_ID)}', ${VIDEO_DURATION}, now() - interval '2 days'),
       ('${VIDEO2_ID}', '${STUDY_ID}', '${memberID}', '이수민', '기내방송문 리딩 연습',
        '${STUDY_ID}/${VIDEO2_ID}.mp4', '${thumbnailURL(VIDEO2_ID)}', ${VIDEO_DURATION}, now() - interval '1 day')
ON CONFLICT (id) DO NOTHING;

-- 피드백 (feedback_count는 트리거가 증가)
INSERT INTO feedbacks (id, video_id, study_id, author_id, author_name, content, timestamp_seconds, mentioned_user_ids, created_at)
VALUES ('${FEEDBACK1_ID}', '${VIDEO1_ID}', '${STUDY_ID}', '${memberID}', '이수민',
        '도입부 미소가 정말 좋아요! 다만 시선이 카메라 아래로 자주 떨어지는 것 같아요.', 3, '{}', now() - interval '40 hours'),
       ('${FEEDBACK2_ID}', '${VIDEO1_ID}', '${STUDY_ID}', '${memberID}', '이수민',
        '@김하늘 마무리 멘트 속도만 조금 늦추면 완벽할 것 같아요!', 9, '{${ownerID}}', now() - interval '39 hours'),
       ('${FEEDBACK3_ID}', '${VIDEO2_ID}', '${STUDY_ID}', '${ownerID}', '김하늘',
        '발음이 또렷해서 듣기 편해요. 문장 사이 호흡을 반 박자만 더 가져가 봅시다.', 5, '{}', now() - interval '20 hours')
ON CONFLICT (id) DO NOTHING;

-- 피드백 댓글 (방장이 멤버 피드백에 답글)
INSERT INTO feedback_comments (id, feedback_id, study_id, author_id, author_name, content, created_at)
VALUES ('${COMMENT_ID}', '${FEEDBACK1_ID}', '${STUDY_ID}', '${ownerID}', '김하늘',
        '피드백 감사해요! 다음 영상에서 시선 처리 신경 써볼게요 🙏', now() - interval '38 hours')
ON CONFLICT (id) DO NOTHING;

-- 알림은 수동 삽입하지 않는다 — 피드백/멘션/댓글/모집글 INSERT 시 DB 트리거가 자동 생성
-- 모집글 (방장 작성, 스터디 연결) + 댓글 (신청자)
INSERT INTO recruit_posts (id, author_id, author_name, title, description, field, meeting_type, region, schedule,
                           start_date, max_members, deadline, requirement, contact_method, study_id, created_at)
VALUES ('${RECRUIT_POST_ID}', '${ownerID}', '김하늘', '승무원 영상면접 스터디원 모집 (1자리)',
        '주 2회 줌으로 모의 영상면접을 진행하고 서로 피드백합니다. 국내 항공사 준비생 환영!',
        'flight_attendant', 'online', NULL, '매주 화/목 21시',
        now() + interval '3 days', 3, now() + interval '14 days',
        '승무원 준비 6개월 이상', '앱 내 가입 신청', '${STUDY_ID}', now() - interval '3 days')
ON CONFLICT (id) DO NOTHING;

INSERT INTO recruit_comments (id, post_id, author_id, author_name, content, created_at)
VALUES ('${RECRUIT_COMMENT_ID}', '${RECRUIT_POST_ID}', '${applicantID}', '박지원',
        '혹시 초보도 참여 가능할까요? 가입 신청 넣었습니다!', now() - interval '2 days')
ON CONFLICT (id) DO NOTHING;
`);

console.log("\n시딩 완료 — 계정/데이터 요약");
const [summary] = await query(`
  SELECT
    (SELECT count(*) FROM study_members WHERE study_id = '${STUDY_ID}') AS members,
    (SELECT count(*) FROM study_join_requests WHERE study_id = '${STUDY_ID}' AND status = 'pending') AS pending_requests,
    (SELECT count(*) FROM videos WHERE study_id = '${STUDY_ID}') AS videos,
    (SELECT count(*) FROM feedbacks WHERE study_id = '${STUDY_ID}') AS feedbacks,
    (SELECT count(*) FROM notifications WHERE recipient_id IN ('${ownerID}', '${memberID}')) AS notifications,
    (SELECT count(*) FROM recruit_posts WHERE id = '${RECRUIT_POST_ID}') AS recruit_posts
`);
console.table(summary);
console.log(`
스터디: 승무원 영상면접 스터디 (초대코드 ${INVITE_CODE})
  방장   김하늘 test@flymate.app  → FlyMate-Owner 스킴
  멤버   이수민 test2@flymate.app → FlyMate-Member 스킴
  신청자 박지원 test3@flymate.app → FlyMate-Applicant 스킴 (가입 신청 pending)
비밀번호는 mise.local.toml의 TUIST_TEST_PASSWORD.
스킴에 계정이 안 물려 있으면: tuist generate 후 실행 (mise.local.toml의 TUIST_TEST_EMAIL_* 사용)
`);
