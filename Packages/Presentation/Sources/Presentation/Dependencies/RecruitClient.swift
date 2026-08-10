import Foundation
import ComposableArchitecture
import Domain

public struct RecruitClient: Sendable {
    public var fetchPosts: @Sendable (RecruitPostFilter, Date?) async throws -> [RecruitPost]
    public var fetchPost: @Sendable (UUID) async throws -> RecruitPost
    public var createPost: @Sendable (RecruitPostDraft) async throws -> RecruitPost
    public var updatePost: @Sendable (UUID, RecruitPostDraft) async throws -> RecruitPost
    public var closePost: @Sendable (UUID) async throws -> RecruitPost
    public var reopenPost: @Sendable (UUID, Date) async throws -> RecruitPost
    public var deletePost: @Sendable (UUID) async throws -> Void
    public var fetchComments: @Sendable (UUID) async throws -> [RecruitComment]
    public var createComment: @Sendable (CreateRecruitCommentRequest) async throws -> RecruitComment
    public var deleteComment: @Sendable (UUID) async throws -> Void

    public init(
        fetchPosts: @escaping @Sendable (RecruitPostFilter, Date?) async throws -> [RecruitPost],
        fetchPost: @escaping @Sendable (UUID) async throws -> RecruitPost,
        createPost: @escaping @Sendable (RecruitPostDraft) async throws -> RecruitPost,
        updatePost: @escaping @Sendable (UUID, RecruitPostDraft) async throws -> RecruitPost,
        closePost: @escaping @Sendable (UUID) async throws -> RecruitPost,
        reopenPost: @escaping @Sendable (UUID, Date) async throws -> RecruitPost,
        deletePost: @escaping @Sendable (UUID) async throws -> Void,
        fetchComments: @escaping @Sendable (UUID) async throws -> [RecruitComment],
        createComment: @escaping @Sendable (CreateRecruitCommentRequest) async throws -> RecruitComment,
        deleteComment: @escaping @Sendable (UUID) async throws -> Void
    ) {
        self.fetchPosts = fetchPosts
        self.fetchPost = fetchPost
        self.createPost = createPost
        self.updatePost = updatePost
        self.closePost = closePost
        self.reopenPost = reopenPost
        self.deletePost = deletePost
        self.fetchComments = fetchComments
        self.createComment = createComment
        self.deleteComment = deleteComment
    }
}

extension RecruitClient: TestDependencyKey {
    public static let testValue = RecruitClient(
        fetchPosts: unimplemented("\(Self.self).fetchPosts"),
        fetchPost: unimplemented("\(Self.self).fetchPost"),
        createPost: unimplemented("\(Self.self).createPost"),
        updatePost: unimplemented("\(Self.self).updatePost"),
        closePost: unimplemented("\(Self.self).closePost"),
        reopenPost: unimplemented("\(Self.self).reopenPost"),
        deletePost: unimplemented("\(Self.self).deletePost"),
        fetchComments: unimplemented("\(Self.self).fetchComments"),
        createComment: unimplemented("\(Self.self).createComment"),
        deleteComment: unimplemented("\(Self.self).deleteComment")
    )
}

extension DependencyValues {
    public var recruitClient: RecruitClient {
        get { self[RecruitClient.self] }
        set { self[RecruitClient.self] = newValue }
    }
}
