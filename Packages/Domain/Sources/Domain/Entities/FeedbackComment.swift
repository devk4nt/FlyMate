import Foundation

public struct FeedbackComment: Equatable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let feedbackID: UUID
    public let studyID: UUID
    public let authorID: UUID
    public let authorName: String
    public let authorProfileURL: URL?
    public let content: String
    public let mentionedUserIDs: [UUID]
    public let createdAt: Date

    public init(
        id: UUID,
        feedbackID: UUID,
        studyID: UUID,
        authorID: UUID,
        authorName: String,
        authorProfileURL: URL? = nil,
        content: String,
        mentionedUserIDs: [UUID] = [],
        createdAt: Date
    ) {
        self.id = id
        self.feedbackID = feedbackID
        self.studyID = studyID
        self.authorID = authorID
        self.authorName = authorName
        self.authorProfileURL = authorProfileURL
        self.content = content
        self.mentionedUserIDs = mentionedUserIDs
        self.createdAt = createdAt
    }
}

public struct CreateFeedbackCommentRequest: Equatable, Sendable {
    public let feedbackID: UUID
    public let content: String
    public let mentionedUserIDs: [UUID]

    public init(
        feedbackID: UUID,
        content: String,
        mentionedUserIDs: [UUID] = []
    ) {
        self.feedbackID = feedbackID
        self.content = content
        self.mentionedUserIDs = mentionedUserIDs
    }
}
