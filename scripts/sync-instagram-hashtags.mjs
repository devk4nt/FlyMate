// 인스타그램 해시태그 새 게시글을 메일로 알림하는 스크립트 (GitHub Actions에서 실행)
// 필요 env: IG_USER_ID, IG_ACCESS_TOKEN, GMAIL_APP_PASSWORD
// 사전 조건: 인스타그램 프로페셔널 계정 + Meta 개발자 앱 (README 참고: 워크플로 파일 상단 주석)
import nodemailer from "nodemailer";

const HASHTAGS = ["승무원준비", "승무원준비생"];
const MAIL_TO = "flymate.team.contact@gmail.com";
const MAIL_FROM = "flymate.team.contact@gmail.com";
// ponytail: 상태 파일 없이 시간 윈도우로 중복 제거 — cron 지연 대비 7시간.
// 실행 지연이 겹치면 드물게 같은 글이 두 번 올 수 있음. 문제 되면 seen ID를 저장소에 커밋하는 방식으로 전환.
const WINDOW_HOURS = 7;

const { IG_USER_ID, IG_ACCESS_TOKEN, GMAIL_APP_PASSWORD } = process.env;
for (const [name, value] of Object.entries({ IG_USER_ID, IG_ACCESS_TOKEN, GMAIL_APP_PASSWORD })) {
  if (!value) {
    console.error(`missing env: ${name}`);
    process.exit(1);
  }
}

const GRAPH = "https://graph.facebook.com/v21.0";

async function graphAPI(path, params) {
  const query = new URLSearchParams({ ...params, access_token: IG_ACCESS_TOKEN });
  const response = await fetch(`${GRAPH}${path}?${query}`);
  const json = await response.json();
  if (!response.ok || json.error) {
    throw new Error(`Graph API ${response.status} ${path}: ${JSON.stringify(json.error ?? json)}`);
  }
  return json;
}

async function fetchRecentMedia(hashtag) {
  const search = await graphAPI("/ig_hashtag_search", { user_id: IG_USER_ID, q: hashtag });
  const hashtagID = search.data?.[0]?.id;
  if (!hashtagID) {
    console.warn(`hashtag not found: #${hashtag}`);
    return [];
  }
  const media = await graphAPI(`/${hashtagID}/recent_media`, {
    user_id: IG_USER_ID,
    fields: "id,permalink,caption,timestamp",
    limit: "50",
  });
  return media.data ?? [];
}

const cutoff = Date.now() - WINDOW_HOURS * 60 * 60 * 1_000;
const seen = new Set();
const sections = [];
let totalFresh = 0;

for (const hashtag of HASHTAGS) {
  const media = await fetchRecentMedia(hashtag);
  const fresh = media.filter((post) => {
    if (seen.has(post.id)) return false;
    seen.add(post.id);
    return new Date(post.timestamp).getTime() >= cutoff;
  });
  console.log(`#${hashtag}: ${media.length} fetched, ${fresh.length} new`);
  if (fresh.length === 0) continue;
  totalFresh += fresh.length;
  sections.push(
    `<h3>#${hashtag} — 새 게시글 ${fresh.length}건</h3><ul>` +
      fresh
        .map((post) => {
          const preview = (post.caption ?? "(캡션 없음)").replaceAll("<", "&lt;").slice(0, 80);
          return `<li><a href="${post.permalink}">${post.permalink}</a><br>${preview}</li>`;
        })
        .join("") +
      "</ul>",
  );
}

if (sections.length === 0) {
  console.log("no new posts, skipping email");
  process.exit(0);
}

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: { user: MAIL_FROM, pass: GMAIL_APP_PASSWORD },
});

await transporter.sendMail({
  from: `FlyMate 해시태그 알림 <${MAIL_FROM}>`,
  to: MAIL_TO,
  subject: `[FlyMate] 해시태그 새 게시글 ${totalFresh}건`,
  html: sections.join("<hr>"),
});

console.log(`email sent: ${sections.length} hashtag section(s)`);
