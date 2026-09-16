import Foundation

/// AI 면접 분석 요청 페이로드.
/// 영상에서 추출한 음성(m4a)과 일정 간격 캡처 프레임을 담는다 — 영상 원본은 전송하지 않는다.
public struct InterviewInsightRequest: Codable, Equatable, Sendable {
    public struct Frame: Codable, Equatable, Sendable {
        /// 캡처 시점 (초)
        public let time: TimeInterval
        /// 다운스케일된 JPEG 이미지의 Base64 문자열
        public let jpegBase64: String

        public init(time: TimeInterval, jpegBase64: String) {
            self.time = time
            self.jpegBase64 = jpegBase64
        }
    }

    public let duration: TimeInterval
    /// 답변 음성 m4a의 Base64 문자열 — 서버에서 OpenAI 전사에 사용 (추출 실패 시 nil)
    public let audioBase64: String?
    public let frames: [Frame]

    public init(duration: TimeInterval, audioBase64: String?, frames: [Frame]) {
        self.duration = duration
        self.audioBase64 = audioBase64
        self.frames = frames
    }
}
