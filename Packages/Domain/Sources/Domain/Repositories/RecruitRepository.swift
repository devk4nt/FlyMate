import Foundation

/// 모집 글 작성/수정 공용 입력값
public struct RecruitPostDraft: Equatable, Sendable {
    public let title: String
    public let description: String
    public let field: RecruitField
    public let meetingType: RecruitMeetingType
    public let region: String?
    public let schedule: String
    public let startDate: Date
    public let endDate: Date?
    public let maxMembers: Int
    public let deadline: Date
    public let requirement: String
    public let contactMethod: String
    public let linkURL: URL?

    public init(
        title: String,
        description: String,
        field: RecruitField,
        meetingType: RecruitMeetingType,
        region: String?,
        schedule: String,
        startDate: Date,
        endDate: Date?,
        maxMembers: Int,
        deadline: Date,
        requirement: String,
        contactMethod: String,
        linkURL: URL?
    ) {
        self.title = title
        self.description = description
        self.field = field
        self.meetingType = meetingType
        self.region = region
        self.schedule = schedule
        self.startDate = startDate
        self.endDate = endDate
        self.maxMembers = maxMembers
        self.deadline = deadline
        self.requirement = requirement
        self.contactMethod = contactMethod
        self.linkURL = linkURL
    }
}

public struct RecruitPostFilter: Equatable, Sendable {
    public var recruitingOnly: Bool
    public var field: RecruitField?
    public var meetingType: RecruitMeetingType?

    public init(
        recruitingOnly: Bool = false,
        field: RecruitField? = nil,
        meetingType: RecruitMeetingType? = nil
    ) {
        self.recruitingOnly = recruitingOnly
        self.field = field
        self.meetingType = meetingType
    }
}

public struct CreateRecruitCommentRequest: Equatable, Sendable {
    public let postID: UUID
    public let parentID: UUID?
    public let content: String

    public init(postID: UUID, parentID: UUID?, content: String) {
        self.postID = postID
        self.parentID = parentID
        self.content = content
    }
}

public protocol RecruitRepository: Sendable {
    /// 모집 글 목록을 최신순으로 조회한다 (커서 기반 페이지네이션).
    func fetchPosts(filter: RecruitPostFilter, cursor: Date?) async throws -> [RecruitPost]

    /// 모집 글 상세를 조회한다.
    func fetchPost(id: UUID) async throws -> RecruitPost

    /// 새 모집 글을 작성한다.
    func createPost(_ draft: RecruitPostDraft) async throws -> RecruitPost

    /// 본인 모집 글을 수정한다.
    func updatePost(id: UUID, draft: RecruitPostDraft) async throws -> RecruitPost

    /// 모집을 마감한다 (작성자만).
    func closePost(id: UUID) async throws -> RecruitPost

    /// 새 마감일과 함께 모집을 재개한다 (작성자만).
    func reopenPost(id: UUID, deadline: Date) async throws -> RecruitPost

    /// 모집 글을 삭제한다 (작성자만).
    func deletePost(id: UUID) async throws

    /// 모집 글의 댓글·대댓글을 작성순으로 조회한다.
    func fetchComments(postID: UUID) async throws -> [RecruitComment]

    /// 댓글 또는 대댓글을 작성한다.
    func createComment(_ request: CreateRecruitCommentRequest) async throws -> RecruitComment

    /// 본인 댓글을 삭제한다.
    func deleteComment(id: UUID) async throws
}
