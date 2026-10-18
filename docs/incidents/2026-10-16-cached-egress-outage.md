# 2026-10-16 Cached Egress 쿼터 초과 장애

## 요약

10/16(금) KST 07:50~22:15, 약 14.5시간 동안 prod Supabase(`fvhrydkofctahxwyvsnp`)가
Cached Egress 쿼터 초과로 Fair Use Policy 제재를 받아 Storage·Auth 토큰 리프레시·REST RPC가
전부 402로 막혔다. 로그인 유지조차 안 돼 실사용자가 영향을 받은 실제 장애. 발견은 10/18 —
Supabase가 보낸 쿼터 초과 이메일을 보고서야 인지했다(약 2일 지연).

## 원인

AVPlayer가 progressive MP4 재생에 `URLCache`를 사용하지 않는다. 같은 영상을 다시 보면
(영상 상세 재진입, 빠른 피드백 리뷰 등) **매번 서버에서 전체 파일을 다시 받아왔다.**
Supabase Cached Egress는 전송 바이트 기준으로 과금/쿼터 집계되므로, 재시청 트래픽이 그대로
쿼터 소모로 이어졌다.

- 쿼터: 21.44GB 사용 / 5.5GB 한도 (약 390% 초과)
- prod와 staging이 같은 Supabase org에 묶여 있어 쿼터를 공유함 (staging 전용 QA 룰 적용 중)
- 직전 2026-09-30에도 같은 원인(수동 QA 반복 재생)으로 393% 초과가 있었으나 그때는 grace
  period로 끝나 실제 제재까지는 안 갔었음 — 이번엔 실제로 걸림

## 영향 확인 방법

Management API엔 사용량(%) 조회 엔드포인트가 없어 직접 재현 확인:

```bash
# Storage가 실제로 402를 반환하는지
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  "https://fvhrydkofctahxwyvsnp.supabase.co/storage/v1/object/public/thumbnails/..."

# edge logs에서 402 범위 확인 (analytics/endpoints/logs, ClickHouse SQL)
# event_message 포맷: "METHOD | STATUS | URL | User-Agent"
SELECT toDate(timestamp) as day, count(*) as c, min(timestamp), max(timestamp)
FROM logs WHERE event_message LIKE '%| 402 |%' GROUP BY day
```

결과: 10/16 KST 07:50~22:15 사이 333건 실패(auth 토큰 리프레시·RPC·Storage 전부 포함).
10/17(토)는 요청 자체가 0건 — 장애로 사용자가 이탈했거나 애초에 접속 시도가 없었던 것으로 추정.

edge logs엔 user_id가 안 남아 "어떤 사용자가 영향받았는지"는 특정 불가.

## 대응

1. **즉시 — Supabase Pro 업그레이드**: 서비스 제재 해제. `Spend cap`은 켜둔 채 유지하기로
   결정(끄면 과금 리스크, 켜두면 재발 시 또 막힐 수 있음 — 트레이드오프는 아래 참고).
2. **근본 수정 — 클라이언트 영상 캐시** (`Packages/Core/Sources/Core/Utils/VideoCache.swift`):
   서명 URL의 쿼리(토큰)를 제외한 스토리지 경로를 키로 로컬 디스크에 캐시, 재시청 시 네트워크를
   타지 않음. `VideoPlayerView`/`QuickFeedbackRequestDetailView`/`QuickFeedbackReviewView` 3곳
   연결, 앱 기동 시 7일 TTL로 정리. `VideoCacheTests` 5건으로 캐시 키 안정성(서명 토큰 변경에도
   동일 키)·TTL 정리·파일 URL 폴백 검증.
3. **사용자 공지**: 전체 prod 유저(73명)에게 장애 복구 공지·푸시 발송
   (`scripts/fixtures/publish-outage-recovery-announcement.sql`).
4. **재발 감지**: Supabase Management API엔 사용량 임계치 사전 알림 기능이 없다(쿼터를 이미
   초과한 "뒤"에만 이메일이 옴 — 이번에 2일 지연된 이유). 대신 `scripts/check-cached-egress-block.mjs`로
   edge logs의 402를 직접 폴링. claude.ai cloud routine으로 24/7 자동화를 시도했으나 routine에
   커스텀 Secret을 주입할 방법이 없어(Console의 Environments/Credential vault는 별개 제품,
   routine 쪽 API도 `environment_variables` 필드가 실제로는 미지원) 포기하고 **로컬 launchd**로
   전환: `scripts/cached-egress-watch.sh`를 매시간 실행해 402 감지 시 macOS 알림. 맥이
   켜져있을 때만 동작한다는 한계는 있음.

## Spend cap을 끄지 않은 이유

Pro 플랜의 Spend cap을 켜두면(기본값) 쿼터 초과 시 이번처럼 다시 서비스가 막힌다. 끄면
초과분이 자동 과금되어 서비스는 안 끊기지만 예상 못한 비용 리스크가 생긴다. VideoCache
수정으로 egress 자체가 크게 줄 것으로 보여 초과 가능성은 낮아졌다고 판단, 막히는 리스크보다
과금 리스크를 더 두려워할 이유가 적어 **spend cap은 유지**하고 모니터링으로 빠르게 알아차리는
쪽을 택함.

## 남은 과제 / 보류 중인 것

- prod/staging Supabase org 분리 — 여전히 보류. Pro 업그레이드 + 클라이언트 캐시 수정으로
  재발 가능성이 낮아졌다고 판단해서. 또 재발하면 다시 검토.
- 이번에 발급한 scoped Supabase 토큰(읽기 전용, 이 프로젝트 전용) — launchd가 기존 Keychain
  토큰을 재사용하게 되며 결국 안 쓰게 됨, 정리 필요.
- Console에 만든 `flymate-ops` 환경 + `Flymate` credential vault — 안 쓰는 리소스, 정리 필요.

## 관련

- `scripts/check-cached-egress-block.mjs`, `scripts/cached-egress-watch.sh` — 재발 감지 스크립트
- `scripts/fixtures/publish-outage-recovery-announcement.sql` — 장애 복구 공지 발송 fixture
