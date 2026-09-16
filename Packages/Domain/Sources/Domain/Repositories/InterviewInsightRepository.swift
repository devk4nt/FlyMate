import Foundation

public protocol InterviewInsightRepository: Sendable {
    /// 추출한 음성과 캡처 프레임을 기반으로 승무원 면접 관점의 문장별 AI 분석을 생성한다.
    func generateInsight(request: InterviewInsightRequest) async throws -> InterviewInsight
}
