import Foundation
import ComposableArchitecture
import Domain

public struct VideoClient: Sendable {
    public var fetchVideos: @Sendable (UUID, Date?) async throws -> [Video]
    public var fetchVideo: @Sendable (UUID) async throws -> Video
    public var uploadVideo: @Sendable (UploadVideoRequest, @Sendable (Double) -> Void) async throws -> Video
    public var deleteVideo: @Sendable (UUID) async throws -> Void

    public init(
        fetchVideos: @escaping @Sendable (UUID, Date?) async throws -> [Video],
        fetchVideo: @escaping @Sendable (UUID) async throws -> Video,
        uploadVideo: @escaping @Sendable (UploadVideoRequest, @Sendable (Double) -> Void) async throws -> Video,
        deleteVideo: @escaping @Sendable (UUID) async throws -> Void
    ) {
        self.fetchVideos = fetchVideos
        self.fetchVideo = fetchVideo
        self.uploadVideo = uploadVideo
        self.deleteVideo = deleteVideo
    }
}

extension VideoClient: TestDependencyKey {
    public static let testValue = VideoClient(
        fetchVideos: unimplemented("\(Self.self).fetchVideos"),
        fetchVideo: unimplemented("\(Self.self).fetchVideo"),
        uploadVideo: { _, _ in
            XCTFail("Unimplemented: \(Self.self).uploadVideo")
            throw _UnimplementedError()
        },
        deleteVideo: unimplemented("\(Self.self).deleteVideo")
    )
}

private struct _UnimplementedError: Error {}

extension DependencyValues {
    public var videoClient: VideoClient {
        get { self[VideoClient.self] }
        set { self[VideoClient.self] = newValue }
    }
}
