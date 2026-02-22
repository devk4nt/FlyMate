import Foundation

public struct UploadVideoRequest: Equatable, Sendable {
    public let studyID: UUID
    public let title: String
    public let videoData: Data
    public let thumbnailData: Data?

    public init(
        studyID: UUID,
        title: String,
        videoData: Data,
        thumbnailData: Data? = nil
    ) {
        self.studyID = studyID
        self.title = title
        self.videoData = videoData
        self.thumbnailData = thumbnailData
    }
}

public protocol VideoRepository: Sendable {
    /// 스터디의 영상 목록을 조회한다.
    func fetchVideos(studyID: UUID, cursor: Date?) async throws -> [Video]

    /// 영상 상세 정보를 조회한다.
    func fetchVideo(id: UUID) async throws -> Video

    /// 영상을 업로드한다.
    func uploadVideo(_ request: UploadVideoRequest, progress: @Sendable (Double) -> Void) async throws -> Video

    /// 영상을 삭제한다.
    func deleteVideo(id: UUID) async throws
}
