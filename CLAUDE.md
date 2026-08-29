# CLAUDE.md — FlyMate 코딩 컨벤션

## 프로젝트 개요

- **앱**: 승무원, 아나운서 등 영상면접 준비자를 위한 스터디 피드백 iOS 앱 (v1.0 App Store 심사 제출 완료)
- **스택**: Swift 6, SwiftUI, TCA 1.x, Supabase, Firebase(Analytics/Messaging/Crashlytics), Kakao Login
- **타겟**: iOS 17+
- **모듈**: Tuist 프레임워크 타겟 4개 (Core, Domain, Data, Presentation) — `Project.swift`에서 정의, 소스는 `Packages/{모듈}/Sources/{모듈}/`
- **핵심 정책**: 피드백 요청 영상은 최대 3분(180초). 스터디 개설 3개 / 총 참여 5개 / 멤버 8명 고정 한도 (플랜 개념 없음)

---

## 1. 패키지 구조 및 의존성

```
App → Presentation, Data, Domain, Core, Firebase(Core/Messaging/Crashlytics)
Presentation → Domain, Core, TCA, Kingfisher, KakaoSDK(Common/Auth/User)
Data → Domain, Supabase SDK
Domain → Core
Core → (없음)
```

외부 의존성은 `Tuist/Package.swift`에서 관리: TCA 1.17+, Kingfisher 8+, kakao-ios-sdk 2.23+, supabase-swift 2+, firebase-ios-sdk 11+

| 패키지 | 역할 | 주요 내용 |
|--------|------|----------|
| **Core** | 공통 유틸리티 | Extensions, AppConstants, Logger, Debouncer, RetryHelper, Protocols (Analytics/CrashReport 포함), Models (LoadingState, PaginatedState, AppError) |
| **Domain** | 비즈니스 모델 | Entities, Repository 프로토콜 |
| **Data** | 데이터 소스 | DTOs, Mappers, Repository 구현체, Services (RealtimeService, StorageService) |
| **Presentation** | UI 레이어 | TCA Features, DesignSystem, Dependencies (TCA Client) |

### Feature 목록 (12개)

`Packages/Presentation/Sources/Presentation/Features/`:
Auth, BugReport, Feedback, Notification, Onboarding, Recruit, Report, Settings, Study, Tab, TermsConsent, Video

- 차단(Block)은 Settings 하위 `Settings/BlockedUsers/`
- Analytics/Crashlytics는 Core의 `AnalyticsProtocol`/`CrashReportProtocol` 추상화 + Firebase 구현, Presentation의 Dependencies에서 TCA Client로 주입

---

## 2. 파일 & 폴더 네이밍

### Feature 구조

```
Features/{FeatureName}/
├── {FeatureName}Feature.swift    # Reducer 정의
├── {FeatureName}View.swift       # SwiftUI View
└── {SubFeatureName}/             # 하위 기능 (필요 시)
    ├── {SubFeatureName}Feature.swift
    └── {SubFeatureName}View.swift
```

### Data 레이어

```
Data/
├── DTOs/{Entity}DTO.swift
├── Mappers/DTOMapper.swift       # 단일 파일에 모든 매핑 함수
├── Repositories/{Entity}RepositoryImpl.swift
├── Services/
└── Supabase/
```

### DesignSystem

```
DesignSystem/
├── Tokens/      # FMSpacing, FMColors, FMTypography
├── Components/  # FM 접두사 컴포넌트 (FMButton, FMCard, ...)
└── Modifiers/   # ViewModifier 구현
```

---

## 3. Swift 기본 컨벤션

### 접근 제어

- **기본 private** — 외부 노출 필요한 경우에만 `public`
- Feature Reducer, State, Action, View: `public` (크로스 모듈)
- `@Dependency` 프로퍼티: `private`
- View의 computed helper: `private`
- DTO: `internal` (Data 레이어 내부에서만 사용)

### 타입 안전성

- 강제 언래핑(`!`) 금지 — `guard let` / `if let` 사용
- `@Sendable` 적합성 필수 (Swift 6 strict concurrency)
- 매직 넘버 금지 — `AppConstants` 또는 `enum`으로 관리

### Import 순서

```swift
import Foundation          // 1. 표준 라이브러리
import SwiftUI             // 2. Apple 프레임워크
import ComposableArchitecture  // 3. 외부 프레임워크
import Core                // 4. 로컬 패키지 (Core → Domain → Data → Presentation)
import Domain
```

테스트 파일에서는 테스트 대상 모듈만 `@testable import` 사용:
```swift
@testable import Presentation
```

---

## 4. TCA 패턴

### Reducer 기본 구조

```swift
@Reducer
public struct {FeatureName}Feature {
    @ObservableState
    public struct State: Equatable {
        // 프로퍼티 선언
        public init() {}
    }

    public enum Action: Equatable {
        // 액션 선언
    }

    @Dependency(\.someClient) private var someClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // 액션 핸들링
            }
        }
    }
}
```

### Action 네이밍

| 패턴 | 용도 | 예시 |
|------|------|------|
| `~Tapped` | 사용자 탭 인터랙션 | `submitTapped`, `deleteTapped` |
| `~Changed` | 값 변경 | `contentChanged(String)`, `titleChanged(String)` |
| `~Response` | 비동기 결과 수신 | `fetchResponse(Result<T, AppError>)` |
| `~Dismissed` | 해제/닫기 | `errorDismissed`, `alertDismissed` |
| `onAppear` / `onDisappear` | 라이프사이클 | `case onAppear` |
| `loadMore` | 페이지네이션 | `case loadMore` |

### Side Effect 작성 규칙

```swift
case .submitTapped:
    state.isSubmitting = true           // 1. 상태 먼저 동기 변경
    state.error = nil
    let client = feedbackClient         // 2. 의존성 캡처 (Effect.run 전에)
    let request = CreateFeedbackRequest(...)
    return .run { send in               // 3. Effect.run으로 비동기 작업
        do {
            let result = try await client.createFeedback(request)
            await send(.submitResponse(.success(result)))
        } catch {
            let appError = error as? AppError ?? .unexpected(error.localizedDescription)
            await send(.submitResponse(.failure(appError)))
        }
    }
```

**필수 규칙**:
- 의존성은 반드시 `let client = someClient` 로 Effect.run **이전에** 캡처
- 에러 매핑: `error as? AppError ?? .unexpected(error.localizedDescription)`
- 상태 변경은 Effect 반환 전에 동기적으로 수행

### Navigation 패턴

**Sheet/Modal (Presentation)**:
```swift
// State
@Presents public var createStudy: StudyCreateFeature.State?

// Action
case .createTapped:
    state.createStudy = StudyCreateFeature.State()
    return .none

// Body
.ifLet(\.$createStudy, action: \.createStudy) {
    StudyCreateFeature()
}
```

**Tab (Scope)**:
```swift
public var body: some ReducerOf<Self> {
    Scope(state: \.study, action: \.study) {
        StudyNavigationFeature()
    }
    Scope(state: \.feedbackManagement, action: \.feedbackManagement) {
        FeedbackManagementFeature()
    }
    Reduce { state, action in
        // 부모 레벨 액션 처리
    }
}
```

**부모-자식 액션 전파**: 자식에서 부모가 처리할 액션은 `return .none`으로 선언만 하고, 부모 Reducer에서 핸들링

### 실시간 스트림 패턴

```swift
private enum CancelID { case realtimeFeedback }

case .onAppear:
    return .run { send in
        for await feedbacks in client.observeFeedbacks(videoID) {
            await send(.feedbacksUpdated(feedbacks))
        }
    }
    .cancellable(id: CancelID.realtimeFeedback)

case .onDisappear:
    return .cancel(id: CancelID.realtimeFeedback)
```

---

## 5. Dependency Client 패턴

### 정의

```swift
public struct {Entity}Client: Sendable {
    public var fetch: @Sendable (UUID) async throws -> Entity
    public var create: @Sendable (CreateRequest) async throws -> Entity
    public var observe: @Sendable (UUID) -> AsyncStream<[Entity]>

    public init(
        fetch: @escaping @Sendable (UUID) async throws -> Entity,
        create: @escaping @Sendable (CreateRequest) async throws -> Entity,
        observe: @escaping @Sendable (UUID) -> AsyncStream<[Entity]>
    ) {
        self.fetch = fetch
        self.create = create
        self.observe = observe
    }
}
```

### TestDependencyKey

```swift
extension {Entity}Client: TestDependencyKey {
    public static let testValue = {Entity}Client(
        fetch: unimplemented("\(Self.self).fetch"),
        create: unimplemented("\(Self.self).create"),
        observe: unimplemented("\(Self.self).observe", placeholder: .finished)
    )
}

extension DependencyValues {
    public var {entity}Client: {Entity}Client {
        get { self[{Entity}Client.self] }
        set { self[{Entity}Client.self] = newValue }
    }
}
```

**규칙**:
- 프로토콜이 아닌 struct + 클로저 프로퍼티 방식
- 모든 클로저에 `@Sendable` 명시
- `testValue`에서 `unimplemented()` 사용 (AsyncStream은 `placeholder: .finished`)
- `DependencyValues` extension으로 getter/setter 등록

---

## 6. Domain 엔티티

```swift
public struct Study: Equatable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    // ...

    public init(id: UUID, name: String, ...) {
        self.id = id
        self.name = name
    }

    // 비즈니스 로직은 computed property로
    public var isFull: Bool {
        members.count >= maxMembers
    }
}
```

**규칙**:
- 프로토콜 채택: `Equatable, Identifiable, Sendable, Hashable`
- 모든 프로퍼티 `public`
- 명시적 `public init` (모든 필드 할당)
- 비즈니스 로직은 computed property로 표현

---

## 7. DTO & Mapper

### DTO

```swift
struct StudyDTO: Codable, Sendable {
    let id: UUID
    let ownerID: UUID
    let createdAt: String    // ISO 8601 문자열

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"     // 백엔드 snake_case 매핑
        case createdAt = "created_at"
    }
}
```

**규칙**:
- `internal` 접근 제어 (Data 레이어 내부)
- `Codable, Sendable` 채택
- `CodingKeys`로 snake_case ↔ camelCase 매핑
- 날짜는 `String`으로 받고, URL도 `String`으로 받아 Mapper에서 변환

### DTOMapper

```swift
enum DTOMapper {
    static func toDomain(_ dto: StudyDTO, members: [StudyMemberDTO]) -> Study { ... }
    static func toDomain(_ dto: FeedbackDTO) -> Feedback { ... }
}
```

**규칙**:
- `enum` (인스턴스화 방지) + `static` 메서드
- 메서드 오버로딩으로 DTO 타입별 구분: `toDomain(_ dto:)`
- 날짜 변환: 공유 `ISO8601DateFormatter` 사용
- URL 변환: `flatMap(URL.init(string:))`
- 실패 시 기본값 폴백 (예: `Date()`, `.member`)

---

## 8. LoadingState 패턴

```swift
public enum LoadingState<T: Equatable & Sendable>: Equatable, Sendable {
    case idle
    case loading
    case loaded(T)
    case failed(AppError)
}
```

**사용**:
```swift
// Reducer
case .onAppear:
    guard case .idle = state.studies else { return .none }
    state.studies = .loading
    // fetch...

case .studiesResponse(.success(let studies)):
    state.studies = .loaded(studies)

case .studiesResponse(.failure(let error)):
    state.studies = .failed(error)

// View
switch store.studies {
case .idle, .loading:
    FMSkeletonView()
case .loaded(let studies):
    StudyListContent(studies: studies)
case .failed(let error):
    FMErrorView(error: error) { store.send(.retryTapped) }
}
```

---

## 9. 에러 처리

### AppError 계층

```
AppError
├── .network(NetworkError)     # 네트워크 오류 (noConnection, timeout, serverError, ...)
├── .business(BusinessError)   # 비즈니스 로직 오류 (studyFull, unauthorized, ...)
└── .unexpected(String)        # 예상치 못한 오류 (fallback)
```

- 모든 에러 타입은 `Equatable, Sendable, LocalizedError` 채택
- 각 case에 `userMessage` 한국어 메시지 매핑
- Reducer에서의 에러 캐치: `error as? AppError ?? .unexpected(error.localizedDescription)`

---

## 10. DesignSystem

### 토큰 사용

```swift
// 스페이싱
.padding(FMSpacing.md)                                    // 16pt
.padding(.horizontal, FMSpacing.lg)                       // 20pt

// 코너 라디우스
.clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))  // 12pt

// 색상
.foregroundStyle(FMColors.label)
.background(FMColors.secondaryBackground)

// 타이포그래피
.font(FMTypography.headline)
.font(FMTypography.body)
```

### 스페이싱 스케일

| 토큰 | 값 |
|------|-----|
| `xxxs` | 2pt |
| `xxs` | 4pt |
| `xs` | 8pt |
| `sm` | 12pt |
| `md` | 16pt |
| `lg` | 20pt |
| `xl` | 24pt |
| `xxl` | 32pt |
| `xxxl` | 40pt |

### 컴포넌트 규칙

- `FM` 접두사 사용 (FMButton, FMCard, FMTextField, FMMentionTextEditor, FMEmptyState, FMErrorView, FMSkeletonView, FMToast, FMBadge, FMNotificationBell, FMProfileImage, FMFeedCell / Modifier: FMGlass)
- private 프로퍼티 + public init 패턴
- 모든 인터랙티브 요소에 `accessibilityLabel` / `accessibilityHint` 필수
- 로딩/비활성 상태 지원

---

## 11. View 작성 패턴

### 기본 구조

```swift
public struct {FeatureName}View: View {
    @Bindable var store: StoreOf<{FeatureName}Feature>

    public init(store: StoreOf<{FeatureName}Feature>) {
        self.store = store
    }

    public var body: some View {
        // 메인 레이아웃
    }

    // MARK: - Private Views
    private var someSection: some View { ... }
}
```

### Sheet 바인딩

```swift
.sheet(item: $store.scope(state: \.createStudy, action: \.createStudy)) { createStore in
    NavigationStack {
        StudyCreateView(store: createStore)
    }
}
```

### MARK 주석으로 섹션 구분

```swift
// MARK: - Header
// MARK: - Content
// MARK: - Styling Helpers
// MARK: - Mock Data
```

---

## 12. 페이지네이션

```swift
// State
public var feedbacks = PaginatedState<Feedback>()
public var loadingState: LoadingState<[Feedback]> = .idle

// Action
case .loadMore:
    guard !state.feedbacks.isLoadingMore, state.feedbacks.hasMore else { return .none }
    state.feedbacks.isLoadingMore = true
    return fetchFeedbacks(cursor: state.feedbacks.cursor)

case .loadMoreResponse(.success(let newItems)):
    state.feedbacks.isLoadingMore = false
    state.feedbacks.items.append(contentsOf: newItems)
    state.feedbacks.cursor = newItems.last?.createdAt
    state.feedbacks.hasMore = newItems.count >= AppConstants.defaultPageSize
```

---

## 13. 테스트 패턴

### 기본 구조 (Swift Testing)

```swift
import Testing
import ComposableArchitecture
import Domain
import Core
@testable import Presentation

@MainActor
struct {FeatureName}FeatureTests {
    @Test
    func 기능_설명_한글() async {
        let store = TestStore(initialState: SomeFeature.State()) {
            SomeFeature()
        } withDependencies: {
            $0.someClient.fetch = { _ in .mock }
        }

        await store.send(.someTapped) {
            $0.isLoading = true
        }

        await store.receive(\.fetchResponse.success) {
            $0.isLoading = false
            $0.data = .loaded(.mock)
        }
    }
}
```

**규칙**:
- `@MainActor` 필수
- `@Test` 매크로 사용 (Swift Testing)
- 테스트 함수명 한글 허용 (가독성)
- `TestStore` + `withDependencies` 패턴
- `await store.send()` → 상태 변경 검증
- `await store.receive()` → 비동기 액션 수신 검증
- Mock 데이터는 `extension Entity { static let mock = ... }` 패턴
- 고정 UUID 사용 (재현 가능성)

---

## 14. 상수 관리

전체 상수는 `Packages/Core/Sources/Core/Constants/AppConstants.swift` 참조. 대표 예:

```swift
public enum AppConstants {
    public static let maxVideoDurationSeconds: TimeInterval = 180
    public static let maxVideoFileSizeBytes = 50 * 1_024 * 1_024
    public static let maxStudyMembers = 8
    public static let maxOwnedStudies = 3
    public static let maxJoinedStudies = 5
    public static let defaultPageSize = 20
    public static let maxFeedbackLength = 500
}
```

- `enum` 사용 (인스턴스화 방지), 도메인별 상수는 중첩 enum으로 그룹화 (예: `AppConstants.QuickFeedback`)
- Doc comment로 각 상수 설명
- 바이트 크기는 `* 1_024` 형태로 가독성 확보

---

## 빌드 & 실행

- 빌드 시스템: **Tuist** (mise로 버전 고정 — `mise.toml`)
- 프로젝트 파일(`FlyMate.xcodeproj`/`FlyMate.xcworkspace`)은 생성물이므로 커밋하지 않음
- 외부 의존성은 `Tuist/Package.swift`, 타겟/스킴 정의는 `Project.swift`

```bash
mise install          # tuist 설치 (최초 1회)
tuist install         # 외부 의존성 해석
tuist generate        # 워크스페이스 생성 + Xcode 열기
```

- 이후 Xcode에서 `FlyMate.xcworkspace`의 FlyMate 스킴으로 iOS 시뮬레이터 빌드

### 환경 (Supabase 프로젝트 2개)

| 환경 | 프로젝트 ref | 앱 구성 / 스킴 | 자격 증명 |
|------|-------------|---------------|----------|
| prod | `fvhrydkofctahxwyvsnp` (Flymate Release) | Debug/Release — `FlyMate` 스킴, 심사 빌드 | `Secrets.xcconfig` |
| staging | `kilkzezzkvyegnuubltg` (Flymate Staging) | `Staging` 구성 — `FlyMate-Staging`(실 로그인), `FlyMate-Owner/Member`(테스트 계정) 스킴 | `Secrets.staging.xcconfig` |

- `FlyMate` 스킴 기본 실행은 여전히 목 데이터(로그인 없음) — 오프라인 UI 검수용. 실 백엔드 플로우 검증은 `FlyMate-Staging`
- 번들 ID·서명·Firebase·카카오 설정은 두 환경이 동일, Supabase URL/키만 다름
- 마이그레이션은 **staging 먼저 → 검증 → prod** 순서. `supabase db push`가 고장나 있어 스크립트 사용:
  `node scripts/apply-migrations.mjs <project-ref> [--dry-run]` (Management API로 미적용 파일 순차 실행 + 히스토리 등록)
- Edge Function 배포: `supabase functions deploy --project-ref <ref>` (staging 시크릿은 대시보드에서 별도 설정)
- 테스트: FlyMate 스킴에 FlyMateTests + PresentationTests 포함 (`tuist test` 또는 Cmd+U)

## CI/CD (.github/workflows/)

| 워크플로 | 역할 |
|----------|------|
| `ci.yml` | PR/푸시 시 빌드 & 테스트 |
| `release-upload.yml` | App Store 심사 빌드 & 업로드 — **심사 빌드는 반드시 이 워크플로 사용** (베타 macOS 로컬 빌드는 Invalid Binary 발생) |
| `appstore-reviews.yml` | App Store 리뷰 수집 (`scripts/sync-appstore-reviews.mjs`) |
