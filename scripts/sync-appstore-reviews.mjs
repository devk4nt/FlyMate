// App Store 리뷰를 GitHub Issue로 동기화하는 스크립트 (GitHub Actions에서 실행)
// 필요 env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY, ASC_APP_ID, GH_TOKEN, GITHUB_REPOSITORY
import crypto from "node:crypto";

const {
  ASC_KEY_ID,
  ASC_ISSUER_ID,
  ASC_PRIVATE_KEY,
  ASC_APP_ID,
  GH_TOKEN,
  GITHUB_REPOSITORY,
} = process.env;

for (const [name, value] of Object.entries({ ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY, ASC_APP_ID, GH_TOKEN, GITHUB_REPOSITORY })) {
  if (!value) {
    console.error(`missing env: ${name}`);
    process.exit(1);
  }
}

const b64url = (input) => Buffer.from(input).toString("base64url");

function makeToken() {
  const header = b64url(JSON.stringify({ alg: "ES256", kid: ASC_KEY_ID, typ: "JWT" }));
  const payload = b64url(JSON.stringify({
    iss: ASC_ISSUER_ID,
    exp: Math.floor(Date.now() / 1000) + 20 * 60,
    aud: "appstoreconnect-v1",
  }));
  const signature = crypto
    .sign("sha256", Buffer.from(`${header}.${payload}`), { key: ASC_PRIVATE_KEY, dsaEncoding: "ieee-p1363" })
    .toString("base64url");
  return `${header}.${payload}.${signature}`;
}

async function fetchReviews() {
  const url = `https://api.appstoreconnect.apple.com/v1/apps/${ASC_APP_ID}/customerReviews?sort=-createdDate&limit=50`;
  const response = await fetch(url, { headers: { Authorization: `Bearer ${makeToken()}` } });
  if (!response.ok) {
    throw new Error(`App Store Connect API ${response.status}: ${await response.text()}`);
  }
  const json = await response.json();
  return json.data ?? [];
}

async function github(path, options = {}) {
  const response = await fetch(`https://api.github.com${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${GH_TOKEN}`,
      Accept: "application/vnd.github+json",
      ...options.headers,
    },
  });
  if (!response.ok) {
    throw new Error(`GitHub API ${response.status} ${path}: ${await response.text()}`);
  }
  return response.json();
}

// 기존 이슈 본문의 review-id 마커를 수집해서 중복 생성 방지
async function fetchExistingReviewIDs() {
  const ids = new Set();
  for (let page = 1; ; page += 1) {
    const issues = await github(
      `/repos/${GITHUB_REPOSITORY}/issues?labels=appstore-review&state=all&per_page=100&page=${page}`,
    );
    for (const issue of issues) {
      const match = issue.body?.match(/<!-- review-id: (\S+) -->/);
      if (match) ids.add(match[1]);
    }
    if (issues.length < 100) return ids;
  }
}

const reviews = await fetchReviews();
const existingIDs = await fetchExistingReviewIDs();
let created = 0;

for (const review of reviews) {
  if (existingIDs.has(review.id)) continue;
  const { rating, title, body, reviewerNickname, territory, createdDate } = review.attributes;
  const stars = "★".repeat(rating) + "☆".repeat(5 - rating);
  const labels = ["appstore-review", ...(rating <= 2 ? ["bug"] : [])];
  await github(`/repos/${GITHUB_REPOSITORY}/issues`, {
    method: "POST",
    body: JSON.stringify({
      title: `[${stars}] ${title || "(제목 없음)"}`,
      labels,
      body: [
        `<!-- review-id: ${review.id} -->`,
        `**평점**: ${rating}/5`,
        `**작성자**: ${reviewerNickname ?? "익명"}`,
        `**국가**: ${territory ?? "-"}`,
        `**작성일**: ${createdDate}`,
        "",
        "---",
        "",
        body || "(내용 없음)",
      ].join("\n"),
    }),
  });
  created += 1;
  console.log(`created issue for review ${review.id} (${rating}/5)`);
}

console.log(`done: ${reviews.length} reviews fetched, ${created} issues created`);
