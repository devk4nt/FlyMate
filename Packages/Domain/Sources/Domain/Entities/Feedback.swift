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
    public let mentionedUserID: UUID?

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
        mentionedUserID: UUID? = nil
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
        self.mentionedUserID = mentionedUserID
    }
}

public struct CreateFeedbackRequest: Equatable, Sendable {
    public let videoID: UUID
    public let content: String
    public let timestampSeconds: TimeInterval
    public let mentionedUserID: UUID?

    public init(
        videoID: UUID,
        content: String,
        timestampSeconds: TimeInterval,
        mentionedUserID: UUID? = nil
    ) {
        self.videoID = videoID
        self.content = content
        self.timestampSeconds = timestampSeconds
        self.mentionedUserID = mentionedUserID
    }
}
