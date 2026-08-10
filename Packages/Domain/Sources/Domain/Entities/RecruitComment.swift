import Foundation

/// 모집 글 댓글 (parentID가 있으면 1단계 대댓글)
public struct RecruitComment: Equatable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let postID: UUID
    public let parentID: UUID?
    public let authorID: UUID
    public let authorName: String
    public let authorProfileURL: URL?
    public let content: String
    public let createdAt: Date

    public init(
        id: UUID,
        postID: UUID,
        parentID: UUID?,
        authorID: UUID,
        authorName: String,
        authorProfileURL: URL?,
        content: String,
        createdAt: Date
    ) {
        self.id = id
        self.postID = postID
        self.parentID = parentID
        self.authorID = authorID
        self.authorName = authorName
        self.authorProfileURL = authorProfileURL
        self.content = content
        self.createdAt = createdAt
    }

    public var isReply: Bool { parentID != nil }
}
