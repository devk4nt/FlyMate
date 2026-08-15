<div align="center">

# ✈️ FlyMate

**승무원·아나운서 등 영상면접 준비자를 위한 스터디 피드백 iOS 앱**

![Swift](https://img.shields.io/badge/Swift_6-F05138?style=flat-square&logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS_17+-000000?style=flat-square&logo=apple&logoColor=white)
![TCA](https://img.shields.io/badge/TCA_1.x-4B32C3?style=flat-square)
![Tuist](https://img.shields.io/badge/Tuist-6236FF?style=flat-square)
![Supabase](https://img.shields.io/badge/Supabase-3FCF8E?style=flat-square&logo=supabase&logoColor=white)

v1.0 App Store 심사 진행 중

</div>

## 소개

영상면접을 준비하는 사람들이 스터디를 만들고, 연습 영상을 올리고, 구간별 타임스탬프 피드백을 주고받는 앱입니다. 기획 → 디자인 → 개발 → 심사 제출까지 전 과정을 직접 진행했습니다.

- 스터디 개설/모집/가입 — 무료 플랜 제한(개설 1·가입 1·멤버 3명)과 프리미엄 구독으로 확장
- 영상 업로드(최대 3분) 및 타임스탬프 기반 피드백
- Supabase Realtime 실시간 피드백/알림
- 카카오 로그인, StoreKit 2 월간/연간 구독

## 아키텍처

**TCA 단방향 데이터 플로우 + 4개 프레임워크 모듈 (Tuist)**

```
App
 └─ Presentation ── TCA Features(13개), DesignSystem, Dependency Clients
     └─ Domain ──── Entities, Repository 프로토콜
         └─ Core ── LoadingState, AppError, Analytics/CrashReport 추상화, 공통 유틸
 └─ Data ────────── Repository 구현, DTO/Mapper, Supabase·StoreKit·Realtime Services
```

의존성은 항상 안쪽(Core)을 향하고, Presentation은 Data를 모릅니다 — Repository 프로토콜(Domain)과 TCA `@Dependency` 클라이언트로 결합을 끊었습니다.

### 기술적 포인트

- **Swift 6 strict concurrency** — 전 모듈 `Sendable` 적합성, `@Sendable` 클로저 기반 Dependency Client
- **화면 상태 모델링** — `LoadingState<T>` (idle/loading/loaded/failed) + 커서 기반 페이지네이션 상태
- **에러 계층** — `AppError` → Network/Business/Unexpected 분리, 케이스별 사용자 메시지 매핑, 재시도(backoff) 지원
- **실시간 스트림** — Supabase Realtime을 `AsyncStream`으로 감싸 TCA Effect에서 구독, 화면 이탈 시 `CancelID`로 취소
- **DesignSystem** — 토큰(FMSpacing/FMColors/FMTypography) + FM 컴포넌트, 전 인터랙티브 요소 접근성 라벨
- **관측성** — Analytics/Crashlytics를 Core 프로토콜로 추상화해 Firebase 구현 주입
- **CI/CD** — GitHub Actions로 PR 빌드·테스트, App Store 업로드 자동화, 앱 리뷰 수집 파이프라인

## 기술 스택

| 영역 | 사용 기술 |
|------|----------|
| UI | SwiftUI, TCA 1.17+, Kingfisher |
| 동시성 | Swift Concurrency (async/await, AsyncStream, Actor) |
| 백엔드 | Supabase (Auth, DB, Realtime, Storage) |
| 결제 | StoreKit 2 (월간/연간 구독) |
| 인증 | Kakao Login, Apple 로그인 |
| 관측 | Firebase Analytics · Messaging · Crashlytics |
| 빌드 | Tuist (mise 버전 고정), SPM |
| CI/CD | GitHub Actions, Fastlane |

## 빌드

```bash
mise install      # tuist 설치
tuist install     # 의존성 해석
tuist generate    # 워크스페이스 생성 + Xcode 열기
```

테스트는 FlyMate 스킴에서 `Cmd+U` 또는 `tuist test`.
