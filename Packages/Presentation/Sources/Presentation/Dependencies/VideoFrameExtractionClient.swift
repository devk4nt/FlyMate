import Foundation
import AVFoundation
import UIKit
import ComposableArchitecture
import Domain

/// AI 총평용으로 영상에서 일정 간격의 프레임을 캡처해 Base64 JPEG로 변환한다.
/// 추출 실패는 빈 배열로 흡수해 분석 플로우를 막지 않는다.
public struct VideoFrameExtractionClient: Sendable {
    public var extractFrames: @Sendable (URL) async -> [InterviewInsightRequest.Frame]

    public init(
        extractFrames: @escaping @Sendable (URL) async -> [InterviewInsightRequest.Frame]
    ) {
        self.extractFrames = extractFrames
    }
}

extension VideoFrameExtractionClient: DependencyKey {
    public static let testValue = VideoFrameExtractionClient(
        extractFrames: unimplemented("\(Self.self).extractFrames", placeholder: [])
    )

    public static let liveValue = VideoFrameExtractionClient { url in
        await VideoFrameExtractor.extractFrames(url: url)
    }
}

extension DependencyValues {
    public var videoFrameExtractionClient: VideoFrameExtractionClient {
        get { self[VideoFrameExtractionClient.self] }
        set { self[VideoFrameExtractionClient.self] = newValue }
    }
}

private enum VideoFrameExtractor {
    /// 5초 간격, 최대 3분 영상 기준 36장 — low detail 이미지 입력 비용과 페이로드 크기(~2MB)의 균형점
    private static let frameInterval: TimeInterval = 5
    private static let maxFrameCount = 36
    private static let maxFrameDimension: CGFloat = 512
    private static let jpegCompressionQuality: CGFloat = 0.5

    static func extractFrames(url: URL) async -> [InterviewInsightRequest.Frame] {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return [] }
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite, durationSeconds > 0 else { return [] }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxFrameDimension, height: maxFrameDimension)
        // 정밀한 프레임이 필요 없으므로 키프레임 근처를 허용해 추출 속도를 높인다
        let tolerance = CMTime(seconds: 1, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        let times = stride(from: 0, to: durationSeconds, by: frameInterval)
            .prefix(maxFrameCount)
            .map { CMTime(seconds: $0, preferredTimescale: 600) }

        var frames: [InterviewInsightRequest.Frame] = []
        for await result in generator.images(for: times) {
            guard case .success(let requestedTime, let image, _) = result else { continue }
            guard let jpegData = UIImage(cgImage: image)
                .jpegData(compressionQuality: jpegCompressionQuality) else { continue }
            frames.append(
                InterviewInsightRequest.Frame(
                    time: CMTimeGetSeconds(requestedTime),
                    jpegBase64: jpegData.base64EncodedString()
                )
            )
        }
        return frames
    }
}
