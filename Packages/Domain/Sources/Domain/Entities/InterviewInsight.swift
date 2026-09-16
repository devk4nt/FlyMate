import Foundation

/// AI 면접 분석 결과 — 종합 피드백과 문장별 피드백.
public struct InterviewInsight: Codable, Equatable, Sendable {
    public struct Sentence: Codable, Equatable, Sendable {
        /// 문장 시작 시각 (초)
        public let start: TimeInterval
        /// 지원자가 말한 문장 (전사 오탈자는 서버에서 다듬어짐)
        public let text: String
        /// 좋았던 점 (해당 없으면 nil)
        public let strength: String?
        /// 아쉬운 점 (해당 없으면 nil)
        public let weakness: String?
        /// 개선 방법 (아쉬운 점이 있을 때만)
        public let suggestion: String?

        public init(
            start: TimeInterval,
            text: String,
            strength: String?,
            weakness: String?,
            suggestion: String?
        ) {
            self.start = start
            self.text = text
            self.strength = strength
            self.weakness = weakness
            self.suggestion = suggestion
        }
    }

    public let summary: String
    /// 시각 순 문장별 피드백 (전사 실패 시 빈 배열)
    public let sentences: [Sentence]

    public init(summary: String, sentences: [Sentence]) {
        self.summary = summary
        self.sentences = sentences
    }
}
