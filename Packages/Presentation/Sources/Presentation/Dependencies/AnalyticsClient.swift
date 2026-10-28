import Foundation
import ComposableArchitecture

/// 분석 이벤트 클라이언트 — 구현은 앱 타겟에서 Firebase Analytics로 주입한다.
public struct AnalyticsClient: Sendable {
    public var trackEvent: @Sendable (_ name: String, _ parameters: [String: String]) -> Void
    /// GA4 User-ID 설정. nil이면 해제(로그아웃).
    ///
    /// 설정하지 않으면 GA4가 사람이 아니라 **기기** 단위로 집계한다 — 유지율 카드의
    /// "기기 데이터만 기반으로 함"이 그 뜻이고, 기기 교체·재설치가 전부 신규 사용자로 잡힌다.
    /// 식별자는 Supabase user UUID(가명)만 쓴다. 이메일 등 PII는 절대 넣지 않는다.
    public var setUserID: @Sendable (_ userID: String?) -> Void

    public init(
        trackEvent: @escaping @Sendable (String, [String: String]) -> Void,
        setUserID: @escaping @Sendable (String?) -> Void
    ) {
        self.trackEvent = trackEvent
        self.setUserID = setUserID
    }
}

/// 이벤트 이름 상수 — 오타 방지용 단일 정의
public enum AnalyticsEvent {
    public static let smileMirrorOpened = "smile_mirror_opened"
    public static let smilePracticeStarted = "smile_practice_started"
    public static let smileReportShown = "smile_report_shown"
    public static let smileReportShared = "smile_report_shared"
    public static let smileReminderEnabled = "smile_reminder_enabled"
    /// 거울을 열었지만 연습을 한 번도 시작하지 않고 닫음 — 준비 화면 이탈 측정
    public static let smilePracticeAbandoned = "smile_practice_abandoned"

    // MARK: - 화면 조회
    /// Firebase 자동 화면 수집은 Info.plist의 `FirebaseAutomaticScreenReportingEnabled`로 꺼져 있다.
    /// SwiftUI 앱이라 자동 수집은 루트의 ShakeDetectorViewController 하나만 잡아 화면 분석이 불가능했다.
    public static let screenView = "screen_view"
    public static let screenNameParameter = "screen_name"
    /// GA4의 "화면 클래스" 디멘션. 비워두면 Firebase가 현재 UIViewController 이름으로 채워
    /// 자동 수집을 꺼도 ShakeDetectorViewController가 다시 들어온다 — 반드시 같이 보낸다.
    public static let screenClassParameter = "screen_class"

    // MARK: - 핵심 루프 퍼널
    /// 스터디 가입 "신청" — 방장 승인 전 단계라 joined가 아닌 requested
    public static let studyJoinRequested = "study_join_requested"
    public static let videoUploaded = "video_uploaded"
    public static let feedbackWritten = "feedback_written"

    /// 가입 경로 구분: `invite_code` | `recruit_post`
    public static let sourceParameter = "source"
    /// 업로드 종류 구분: `study` | `quick_feedback`
    public static let kindParameter = "kind"

    // MARK: - 진입 퍼널 (설치 → 로그인 → 가입)
    /// 스플래시 해제 시점. 인증 확인을 못 기다리고 최대 대기(6초)로 풀렸는지 `timed_out`으로 구분한다 —
    /// 설치 후 로그인 화면조차 못 본 이탈이 스플래시 때문인지 판별할 유일한 단서.
    public static let splashResolved = "splash_resolved"
    /// 로그인 버튼 탭. `login_succeeded`와의 차이가 곧 "눌렀는데 못 들어간" 사람 수다.
    public static let loginAttempted = "login_attempted"
    public static let loginSucceeded = "login_succeeded"
    /// 실패·사용자 취소 모두 포함 — `reason`으로 구분한다
    public static let loginFailed = "login_failed"

    /// 로그인 수단: `apple` | `kakao` | `email`
    public static let providerParameter = "provider"
    /// 가입 직후 첫 로그인이면 `true` — 신규 가입 전환 측정
    public static let isNewParameter = "is_new"
    public static let durationMsParameter = "duration_ms"
    public static let timedOutParameter = "timed_out"
    /// 실패 사유: `canceled` | `sdk` | AppError 설명
    public static let reasonParameter = "reason"
}

extension AnalyticsClient {
    /// 화면 조회 기록 — Firebase의 `screen_view` 이벤트로 그대로 매핑된다
    public func trackScreen(_ name: String) {
        trackEvent(
            AnalyticsEvent.screenView,
            [
                AnalyticsEvent.screenNameParameter: name,
                AnalyticsEvent.screenClassParameter: name,
            ]
        )
    }
}

extension AnalyticsClient: TestDependencyKey {
    /// 분석은 관찰용 부수효과라 테스트에서 스텁을 강제하지 않는다 (no-op)
    public static let testValue = AnalyticsClient(trackEvent: { _, _ in }, setUserID: { _ in })
    public static let previewValue = testValue
}

extension DependencyValues {
    public var analyticsClient: AnalyticsClient {
        get { self[AnalyticsClient.self] }
        set { self[AnalyticsClient.self] = newValue }
    }
}
