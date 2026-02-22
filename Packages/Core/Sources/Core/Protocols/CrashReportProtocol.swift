import Foundation

/// 크래시 리포트 및 에러 로깅 추상화 프로토콜.
/// Sentry, Firebase Crashlytics 등 구체 구현체를 교체 가능하게 한다.
public protocol CrashReportProtocol: Sendable {
    /// Non-fatal 에러 기록
    func recordError(_ error: Error, context: [String: String])

    /// Breadcrumb 기록 (크래시 직전 사용자 행동 경로)
    func addBreadcrumb(category: String, message: String)

    /// 커스텀 Key-Value 정보 첨부
    func setCustomValue(_ value: String, forKey key: String)

    /// 사용자 ID 설정
    func setUserID(_ userID: String?)
}
