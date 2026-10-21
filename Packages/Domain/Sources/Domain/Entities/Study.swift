import Foundation

public struct Study: Equatable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let description: String
    public var ownerID: UUID
    public let inviteCode: String
    public let maxMembers: Int
    public var members: [StudyMember]
    public let createdAt: Date
    public var notice: String?
    public var noticeUpdatedAt: Date?
    /// 주간 영상 과제 마감 요일. 0=일 ~ 6=토 (Postgres EXTRACT(DOW)와 동일 인코딩), nil이면 리마인더 없음
    public var videoDeadlineWeekday: Int?
    /// 주간 피드백 마감 요일. 인코딩은 videoDeadlineWeekday와 동일
    public var feedbackDeadlineWeekday: Int?

    public init(
        id: UUID,
        name: String,
        description: String,
        ownerID: UUID,
        inviteCode: String,
        maxMembers: Int,
        members: [StudyMember],
        createdAt: Date,
        notice: String? = nil,
        noticeUpdatedAt: Date? = nil,
        videoDeadlineWeekday: Int? = nil,
        feedbackDeadlineWeekday: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.ownerID = ownerID
        self.inviteCode = inviteCode
        self.maxMembers = maxMembers
        self.members = members
        self.createdAt = createdAt
        self.notice = notice
        self.noticeUpdatedAt = noticeUpdatedAt
        self.videoDeadlineWeekday = videoDeadlineWeekday
        self.feedbackDeadlineWeekday = feedbackDeadlineWeekday
    }

    public var isFull: Bool {
        members.count >= maxMembers
    }

    public var memberCount: Int {
        members.count
    }
}

public struct StudyMember: Equatable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let userID: UUID
    public let userName: String
    public let profileImageURL: URL?
    public var role: MemberRole
    public let joinedAt: Date

    public init(
        id: UUID,
        userID: UUID,
        userName: String,
        profileImageURL: URL? = nil,
        role: MemberRole,
        joinedAt: Date
    ) {
        self.id = id
        self.userID = userID
        self.userName = userName
        self.profileImageURL = profileImageURL
        self.role = role
        self.joinedAt = joinedAt
    }
}

public enum MemberRole: String, Equatable, Sendable, Codable {
    case owner
    case member
}

public struct MemberStats: Equatable, Sendable {
    public let userID: UUID
    public let studyID: UUID
    public let feedbackGivenCount: Int
    public let feedbackReceivedCount: Int
    public let videosUploadedCount: Int
    public let joinedAt: Date

    public init(
        userID: UUID,
        studyID: UUID,
        feedbackGivenCount: Int,
        feedbackReceivedCount: Int,
        videosUploadedCount: Int,
        joinedAt: Date
    ) {
        self.userID = userID
        self.studyID = studyID
        self.feedbackGivenCount = feedbackGivenCount
        self.feedbackReceivedCount = feedbackReceivedCount
        self.videosUploadedCount = videosUploadedCount
        self.joinedAt = joinedAt
    }
}

// MARK: - Join Request

public enum JoinRequestStatus: String, Equatable, Sendable, Codable, Hashable {
    case pending, approved, rejected
}

public struct JoinRequest: Equatable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let studyID: UUID
    public let studyName: String
    public let userID: UUID
    public let userName: String
    public let profileImageURL: URL?
    public let status: JoinRequestStatus
    public let createdAt: Date
    public let respondedAt: Date?

    public init(
        id: UUID,
        studyID: UUID,
        studyName: String,
        userID: UUID,
        userName: String,
        profileImageURL: URL? = nil,
        status: JoinRequestStatus,
        createdAt: Date,
        respondedAt: Date? = nil
    ) {
        self.id = id
        self.studyID = studyID
        self.studyName = studyName
        self.userID = userID
        self.userName = userName
        self.profileImageURL = profileImageURL
        self.status = status
        self.createdAt = createdAt
        self.respondedAt = respondedAt
    }
}
