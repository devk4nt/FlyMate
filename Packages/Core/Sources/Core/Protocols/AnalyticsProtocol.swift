import Foundation

/// 분석 이벤트 추적을 위한 추상화 프로토콜.
/// Firebase Analytics, Amplitude 등 구체 구현체를 교체 가능하게 한다.
public protocol AnalyticsProtocol: Sendable {
    /// 화면 진입 이벤트 기록
    func trackScreenView(name: String, parameters: [String: String])

    /// 사용자 액션 이벤트 기록
    func trackEvent(name: String, parameters: [String: String])

    /// 사용자 속성 설정
    func setUserProperty(key: String, value: String?)

    /// 사용자 ID 설정
    func setUserID(_ userID: String?)
}
