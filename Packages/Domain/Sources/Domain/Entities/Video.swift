import Foundation

public struct Video: Equatable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let studyID: UUID
    public let uploaderID: UUID
    public let uploaderName: String
    public let title: String
    public let videoURL: URL
    public let thumbnailURL: URL?
    public let durationSeconds: TimeInterval
    public let feedbackCount: Int
    public let focusPoints: String?
    public let feedbackRequest: String?
    public let createdAt: Date

    public init(
        id: UUID,
        studyID: UUID,
        uploaderID: UUID,
        uploaderName: String,
        title: String,
        videoURL: URL,
        thumbnailURL: URL? = nil,
        durationSeconds: TimeInterval,
        feedbackCount: Int = 0,
        focusPoints: String? = nil,
        feedbackRequest: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.studyID = studyID
        self.uploaderID = uploaderID
        self.uploaderName = uploaderName
        self.title = title
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.durationSeconds = durationSeconds
        self.feedbackCount = feedbackCount
        self.focusPoints = focusPoints
        self.feedbackRequest = feedbackRequest
        self.createdAt = createdAt
    }
}
