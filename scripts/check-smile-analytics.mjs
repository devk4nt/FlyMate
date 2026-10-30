#!/usr/bin/env node
// 미소 연습 기능 사용 현황 — GA4(Firebase Analytics) 집계
// 사용: node scripts/check-smile-analytics.mjs [일수=30]
// 인증: GOOGLE_APPLICATION_CREDENTIALS=<서비스계정 json> (GA4 속성에 뷰어 권한 필요)
// 속성 자동 탐색 실패 시 GA_PROPERTY_ID 로 지정
import { createSign } from 'node:crypto'
import { readFileSync } from 'node:fs'

const DAYS = Number(process.argv[2] ?? 30)
const EVENTS = [
  ['smile_mirror_opened', '거울 진입'],
  ['smile_practice_started', '연습 시작'],
  ['smile_report_shown', '리포트 도달'],
  ['smile_report_shared', '공유'],
  ['smile_reminder_enabled', '알림 설정'],
  ['smile_practice_abandoned', '시작 없이 이탈'],
]

const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS
if (!keyPath) throw new Error('GOOGLE_APPLICATION_CREDENTIALS 미설정')
const key = JSON.parse(readFileSync(keyPath, 'utf8'))

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url')
const now = Math.floor(Date.now() / 1000)
const claim = `${b64({ alg: 'RS256', typ: 'JWT' })}.${b64({
  iss: key.client_email,
  scope: 'https://www.googleapis.com/auth/analytics.readonly',
  aud: 'https://oauth2.googleapis.com/token',
  exp: now + 3600,
  iat: now,
})}`
const sig = createSign('RSA-SHA256').update(claim).sign(key.private_key, 'base64url')

const res = await fetch('https://oauth2.googleapis.com/token', {
  method: 'POST',
  headers: { 'content-type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion: `${claim}.${sig}`,
  }),
})
const tokenBody = await res.json()
if (!tokenBody.access_token) throw new Error(`토큰 발급 실패: ${JSON.stringify(tokenBody)}`)
const auth = { authorization: `Bearer ${tokenBody.access_token}` }

const api = async (url, init) => {
  const r = await fetch(url, { ...init, headers: { ...auth, 'content-type': 'application/json', ...init?.headers } })
  const body = await r.json()
  if (!r.ok) throw new Error(`${r.status} ${url}\n${JSON.stringify(body, null, 2)}`)
  return body
}

let propertyId = process.env.GA_PROPERTY_ID
if (!propertyId) {
  const { accountSummaries = [] } = await api('https://analyticsadmin.googleapis.com/v1beta/accountSummaries')
  const props = accountSummaries.flatMap((a) => a.propertySummaries ?? [])
  if (props.length === 0) throw new Error('접근 가능한 GA4 속성 없음 — 서비스 계정을 GA4 속성 사용자로 추가 필요')
  const hit = props.find((p) => /flymate/i.test(p.displayName)) ?? props[0]
  propertyId = hit.property.split('/')[1]
  console.log(`속성: ${hit.displayName} (${propertyId})`)
}

const report = (body) =>
  api(`https://analyticsdata.googleapis.com/v1beta/properties/${propertyId}:runReport`, {
    method: 'POST',
    body: JSON.stringify({ dateRanges: [{ startDate: `${DAYS}daysAgo`, endDate: 'today' }], ...body }),
  })

const byEvent = await report({
  dimensions: [{ name: 'eventName' }],
  metrics: [{ name: 'eventCount' }, { name: 'totalUsers' }],
  dimensionFilter: { filter: { fieldName: 'eventName', inListFilter: { values: EVENTS.map(([n]) => n) } } },
})
const totals = await report({ metrics: [{ name: 'totalUsers' }] })

const counts = new Map(
  (byEvent.rows ?? []).map((r) => [r.dimensionValues[0].value, r.metricValues.map((m) => Number(m.value))])
)
const activeUsers = Number(totals.rows?.[0]?.metricValues?.[0]?.value ?? 0)

console.log(`\n최근 ${DAYS}일 · 전체 사용자 ${activeUsers}명\n`)
console.log('이벤트'.padEnd(26) + '횟수'.padStart(8) + '사용자'.padStart(8) + '  전체대비')
for (const [name, label] of EVENTS) {
  const [count = 0, users = 0] = counts.get(name) ?? []
  const pct = activeUsers ? `${((users / activeUsers) * 100).toFixed(1)}%` : '-'
  console.log(`${label} (${name})`.padEnd(26) + String(count).padStart(8) + String(users).padStart(8) + pct.padStart(10))
}

const u = (n) => (counts.get(n) ?? [0, 0])[1]
const step = (a, b) => (u(a) ? `${((u(b) / u(a)) * 100).toFixed(1)}%` : '-')
console.log(`\n퍼널(사용자 기준): 진입→시작 ${step('smile_mirror_opened', 'smile_practice_started')} · 시작→리포트 ${step('smile_practice_started', 'smile_report_shown')} · 리포트→공유 ${step('smile_report_shown', 'smile_report_shared')}`)
