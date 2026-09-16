import Foundation
import AVFoundation
import ComposableArchitecture
import Core

/// AI 면접 분석용으로 영상에서 음성 트랙을 m4a로 추출해 Base64로 변환한다.
public struct ExtractedAudio: Equatable, Sendable {
    public let duration: TimeInterval
    /// 음성 트랙 추출 실패 시 nil — 프레임만으로 분석을 이어간다
    public let m4aBase64: String?

    public init(duration: TimeInterval, m4aBase64: String?) {
        self.duration = duration
        self.m4aBase64 = m4aBase64
    }
}

public struct AudioExtractionClient: Sendable {
    public var extractAudio: @Sendable (URL) async throws -> ExtractedAudio

    public init(
        extractAudio: @escaping @Sendable (URL) async throws -> ExtractedAudio
    ) {
        self.extractAudio = extractAudio
    }
}

extension AudioExtractionClient: DependencyKey {
    public static let testValue = AudioExtractionClient(
        extractAudio: unimplemented("\(Self.self).extractAudio")
    )

    public static let liveValue = AudioExtractionClient { url in
        try await AudioExtractor.extract(url: url)
    }
}

extension DependencyValues {
    public var audioExtractionClient: AudioExtractionClient {
        get { self[AudioExtractionClient.self] }
        set { self[AudioExtractionClient.self] = newValue }
    }
}

private enum AudioExtractor {
    static func extract(url: URL) async throws -> ExtractedAudio {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else {
            throw AppError.unexpected("영상 정보를 읽을 수 없어요.")
        }
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw AppError.unexpected("영상 정보를 읽을 수 없어요.")
        }
        return ExtractedAudio(
            duration: durationSeconds,
            m4aBase64: await exportAudio(asset: asset)
        )
    }

    private static func exportAudio(asset: AVAsset) async -> String? {
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else { return nil }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        await exportSession.export()
        defer { try? FileManager.default.removeItem(at: outputURL) }

        guard exportSession.status == .completed,
              let data = try? Data(contentsOf: outputURL) else { return nil }
        return data.base64EncodedString()
    }
}
