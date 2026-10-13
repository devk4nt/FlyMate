import Foundation

public struct Feedback: Equatable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let videoID: UUID
    public let studyID: UUID
    public let authorID: UUID
    public let authorName: String
    public let authorProfileURL: URL?
    public let content: String
    public let timestampSeconds: TimeInterval
    public let createdAt: Date
    public let mentionedUserIDs: [UUID]
    public let commentCount: Int
    /// 영상 주인이 이 피드백을 확인했다고 표시한 시각
    public var acknowledgedAt: Date?

    public init(
        id: UUID,
        videoID: UUID,
        studyID: UUID,
        authorID: UUID,
        authorName: String,
        authorProfileURL: URL? = nil,
        content: String,
        timestampSeconds: TimeInterval,
        createdAt: Date,
        mentionedUserIDs: [UUID] = [],
        commentCount: Int = 0,
        acknowledgedAt: Date? = nil
    ) {
        self.id = id
        self.videoID = videoID
        self.studyID = studyID
        self.authorID = authorID
        self.authorName = authorName
        self.authorProfileURL = authorProfileURL
        self.content = content
        self.timestampSeconds = timestampSeconds
        self.createdAt = createdAt
        self.mentionedUserIDs = mentionedUserIDs
        self.commentCount = commentCount
        self.acknowledgedAt = acknowledgedAt
    }

    public var isAcknowledged: Bool { acknowledgedAt != nil }
}

public struct CreateFeedbackRequest: Equatable, Sendable {
    public let videoID: UUID
    public let content: String
    public let timestampSeconds: TimeInterval
    public let mentionedUserIDs: [UUID]

    public init(
        videoID: UUID,
        content: String,
        timestampSeconds: TimeInterval,
        mentionedUserIDs: [UUID] = []
    ) {
        self.videoID = videoID
        self.content = content
        self.timestampSeconds = timestampSeconds
        self.mentionedUserIDs = mentionedUserIDs
    }
}
