import Foundation
import ComposableArchitecture

/// 분석 이벤트 클라이언트 — 구현은 앱 타겟에서 Firebase Analytics로 주입한다.
public struct AnalyticsClient: Sendable {
    public var trackEvent: @Sendable (_ name: String, _ parameters: [String: String]) -> Void

    public init(trackEvent: @escaping @Sendable (String, [String: String]) -> Void) {
        self.trackEvent = trackEvent
    }
}

/// 이벤트 이름 상수 — 오타 방지용 단일 정의
public enum AnalyticsEvent {
    public static let smileMirrorOpened = "smile_mirror_opened"
    public static let smilePracticeStarted = "smile_practice_started"
    public static let smileReportShown = "smile_report_shown"
    public static let smileReportShared = "smile_report_shared"
    public static let smileReminderEnabled = "smile_reminder_enabled"
}

extension AnalyticsClient: TestDependencyKey {
    /// 분석은 관찰용 부수효과라 테스트에서 스텁을 강제하지 않는다 (no-op)
    public static let testValue = AnalyticsClient(trackEvent: { _, _ in })
    public static let previewValue = testValue
}

extension DependencyValues {
    public var analyticsClient: AnalyticsClient {
        get { self[AnalyticsClient.self] }
        set { self[AnalyticsClient.self] = newValue }
    }
}
