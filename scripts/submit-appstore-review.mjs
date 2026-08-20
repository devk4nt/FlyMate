// App Store 심사 제출 스크립트 (GitHub Actions에서 실행)
// TestFlight 빌드 처리 완료를 기다렸다가 버전에 연결하고 심사 요청까지 수행한다.
// 필요 env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY(.p8 내용)
// 선택 env: BUNDLE_ID(기본 com.flymate.app), TARGET_VERSION(기본 1.1), WHATS_NEW
import crypto from "node:crypto";

const { ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY } = process.env;
const BUNDLE_ID = process.env.BUNDLE_ID || "com.flymate.app";
const TARGET_VERSION = process.env.TARGET_VERSION || "1.1";
const WHATS_NEW = process.env.WHATS_NEW || "";

for (const [name, value] of Object.entries({ ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY })) {
  if (!value) {
    console.error(`missing env: ${name}`);
    process.exit(1);
  }
}

const BASE = "https://api.appstoreconnect.apple.com";
const EDITABLE_STATES = new Set([
  "PREPARE_FOR_SUBMISSION",
  "DEVELOPER_REJECTED",
  "REJECTED",
  "METADATA_REJECTED",
  "INVALID_BINARY",
]);

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

async function api(method, path, body) {
  const response = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${makeToken()}`,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!response.ok) {
    throw new Error(`${method} ${path} → ${response.status}: ${await response.text()}`);
  }
  return response.status === 204 ? null : response.json();
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// 1. 앱 조회
const apps = await api("GET", `/v1/apps?filter[bundleId]=${BUNDLE_ID}`);
const app = apps.data[0];
if (!app) throw new Error(`앱을 찾을 수 없음: ${BUNDLE_ID}`);
console.log(`앱: ${app.id} (${BUNDLE_ID})`);

// 2. 편집 가능한 App Store 버전 확보 (있으면 재사용, 없으면 생성)
const versions = await api(
  "GET",
  `/v1/apps/${app.id}/appStoreVersions?limit=10&fields[appStoreVersions]=versionString,appStoreState,platform`,
);
for (const v of versions.data) {
  console.log(`기존 버전: ${v.attributes.versionString} — ${v.attributes.appStoreState}`);
}
let version = versions.data.find((v) => EDITABLE_STATES.has(v.attributes.appStoreState));
const blocking = versions.data.find((v) =>
  ["WAITING_FOR_REVIEW", "IN_REVIEW"].includes(v.attributes.appStoreState),
);
if (!version && blocking) {
  throw new Error(
    `버전 ${blocking.attributes.versionString}이(가) ${blocking.attributes.appStoreState} 상태입니다. ` +
    "App Store Connect에서 기존 제출을 취소한 뒤 다시 실행하세요.",
  );
}
if (version && version.attributes.versionString !== TARGET_VERSION) {
  console.log(`버전 문자열 변경: ${version.attributes.versionString} → ${TARGET_VERSION}`);
  await api("PATCH", `/v1/appStoreVersions/${version.id}`, {
    data: { type: "appStoreVersions", id: version.id, attributes: { versionString: TARGET_VERSION } },
  });
}
if (!version) {
  console.log(`버전 ${TARGET_VERSION} 생성`);
  const created = await api("POST", "/v1/appStoreVersions", {
    data: {
      type: "appStoreVersions",
      attributes: { platform: "IOS", versionString: TARGET_VERSION },
      relationships: { app: { data: { type: "apps", id: app.id } } },
    },
  });
  version = created.data;
}
console.log(`대상 버전: ${version.id} (${TARGET_VERSION})`);

// 3. 해당 버전의 최신 빌드가 처리 완료(VALID)될 때까지 대기 (최대 40분)
let build = null;
for (let attempt = 0; attempt < 40; attempt += 1) {
  const builds = await api(
    "GET",
    `/v1/builds?filter[app]=${app.id}&filter[preReleaseVersion.version]=${TARGET_VERSION}&sort=-uploadedDate&limit=1`,
  );
  const candidate = builds.data[0];
  const state = candidate?.attributes.processingState;
  console.log(`빌드 상태: ${candidate ? `${candidate.attributes.version} — ${state}` : "업로드된 빌드 없음"}`);
  if (state === "VALID") {
    build = candidate;
    break;
  }
  if (state === "INVALID" || state === "FAILED") {
    throw new Error(`빌드 처리 실패: ${state}`);
  }
  await sleep(60_000);
}
if (!build) throw new Error("빌드 처리 대기 시간 초과 (40분)");

// 4. 버전에 빌드 연결
await api("PATCH", `/v1/appStoreVersions/${version.id}/relationships/build`, {
  data: { type: "builds", id: build.id },
});
console.log(`빌드 연결 완료: build ${build.attributes.version}`);

// 5. 새로운 기능(whatsNew) 갱신 — 최초 버전은 설정 불가하므로 실패해도 계속 진행
if (WHATS_NEW) {
  try {
    const localizations = await api(
      "GET",
      `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`,
    );
    for (const localization of localizations.data) {
      await api("PATCH", `/v1/appStoreVersionLocalizations/${localization.id}`, {
        data: {
          type: "appStoreVersionLocalizations",
          id: localization.id,
          attributes: { whatsNew: WHATS_NEW },
        },
      });
      console.log(`whatsNew 갱신: ${localization.attributes.locale}`);
    }
  } catch (error) {
    console.warn(`whatsNew 갱신 실패 (계속 진행): ${error.message}`);
  }
}

// 6. 심사 제출 (열려 있는 제출이 있으면 재사용)
const submissions = await api(
  "GET",
  `/v1/reviewSubmissions?filter[app]=${app.id}&filter[state]=READY_FOR_REVIEW`,
);
let submission = submissions.data[0];
if (!submission) {
  const created = await api("POST", "/v1/reviewSubmissions", {
    data: {
      type: "reviewSubmissions",
      attributes: { platform: "IOS" },
      relationships: { app: { data: { type: "apps", id: app.id } } },
    },
  });
  submission = created.data;
}
console.log(`심사 제출: ${submission.id}`);

const items = await api("GET", `/v1/reviewSubmissions/${submission.id}/items`);
if (items.data.length === 0) {
  await api("POST", "/v1/reviewSubmissionItems", {
    data: {
      type: "reviewSubmissionItems",
      relationships: {
        reviewSubmission: { data: { type: "reviewSubmissions", id: submission.id } },
        appStoreVersion: { data: { type: "appStoreVersions", id: version.id } },
      },
    },
  });
  console.log("심사 항목 추가 완료");
}

await api("PATCH", `/v1/reviewSubmissions/${submission.id}`, {
  data: { type: "reviewSubmissions", id: submission.id, attributes: { submitted: true } },
});
console.log(`✅ 버전 ${TARGET_VERSION} 심사 요청 완료`);
