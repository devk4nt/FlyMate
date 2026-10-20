import SwiftUI
import ComposableArchitecture

/// 화면 진입을 Firebase `screen_view`로 직접 기록한다.
///
/// Firebase 자동 화면 수집은 UIViewController만 관찰하는데, 이 앱은 SwiftUI라
/// 루트를 감싼 `ShakeDetectorViewController` 하나로 전부 뭉개져 화면 분석이 불가능했다.
/// 자동 수집은 Info.plist에서 끄고(`FirebaseAutomaticScreenReportingEnabled`) 여기서 수동 기록한다.
private struct ScreenTrackingModifier: ViewModifier {
    let name: String
    @Dependency(\.analyticsClient) private var analyticsClient

    func body(content: Content) -> some View {
        content.onAppear { analyticsClient.trackScreen(name) }
    }
}

extension View {
    /// ponytail: `onAppear` 기준 1회 집계 — 탭 전환·뒤로가기 복귀도 새 조회로 센다.
    /// 체류 시간이 필요해지면 `onDisappear` 짝을 추가.
    public func trackScreen(_ name: String) -> some View {
        modifier(ScreenTrackingModifier(name: name))
    }
}

/// 화면 이름 상수 — GA4에서 집계 키가 되므로 오타·표기 흔들림을 막는다
public enum AnalyticsScreen {
    // 진입
    public static let login = "Login"
    public static let onboarding = "Onboarding"
    public static let termsConsent = "TermsConsent"

    // 스터디
    public static let studyList = "StudyList"
    public static let studyDetail = "StudyDetail"
    public static let studyCreate = "StudyCreate"
    public static let joinStudy = "JoinStudy"
    public static let studyManagement = "StudyManagement"
    public static let memberManagement = "MemberManagement"
    public static let joinRequestManagement = "JoinRequestManagement"
    public static let memberStats = "MemberStats"

    // 영상
    public static let videoFeed = "VideoFeed"
    public static let videoUpload = "VideoUpload"
    public static let videoFeedbackSheet = "VideoFeedbackSheet"

    // 피드백
    public static let feedbackWrite = "FeedbackWrite"
    public static let feedbackEdit = "FeedbackEdit"
    public static let feedbackList = "FeedbackList"
    public static let feedbackCommentList = "FeedbackCommentList"
    public static let feedbackManagement = "FeedbackManagement"
    public static let quickFeedbackHub = "QuickFeedbackHub"
    public static let quickFeedbackRequestDetail = "QuickFeedbackRequestDetail"

    // 모집
    public static let recruitList = "RecruitList"
    public static let recruitDetail = "RecruitDetail"
    public static let recruitCreate = "RecruitCreate"

    // 기타
    public static let practiceMirror = "PracticeMirror"
    public static let notificationList = "NotificationList"
    public static let announcementDetail = "AnnouncementDetail"
    public static let settings = "Settings"
    public static let profileEdit = "ProfileEdit"
    public static let myActivity = "MyActivity"
    public static let blockedUsers = "BlockedUsers"
    public static let report = "Report"
    public static let bugReport = "BugReport"
}
