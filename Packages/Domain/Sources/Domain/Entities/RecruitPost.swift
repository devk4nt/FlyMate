import Foundation

/// 스터디원 모집 글
public struct RecruitPost: Equatable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let title: String
    public let description: String
    public let field: RecruitField
    public let meetingType: RecruitMeetingType
    /// 활동 지역 (온라인 전용이면 nil)
    public let region: String?
    /// 활동 일정 (요일·시간·주기 자유 서술)
    public let schedule: String
    public let startDate: Date
    /// 종료 예정일 (기간 미정이면 nil)
    public let endDate: Date?
    public let maxMembers: Int
    public let deadline: Date
    public let requirement: String
    public let contactMethod: String
    public let linkURL: URL?
    public let authorID: UUID
    public let authorName: String
    public let status: RecruitStatus
    public let commentCount: Int
    public let createdAt: Date
    public let updatedAt: Date?

    public init(
        id: UUID,
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
        linkURL: URL?,
        authorID: UUID,
        authorName: String,
        status: RecruitStatus,
        commentCount: Int,
        createdAt: Date,
        updatedAt: Date? = nil
    ) {
        self.id = id
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
        self.authorID = authorID
        self.authorName = authorName
        self.status = status
        self.commentCount = commentCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var isEdited: Bool { updatedAt != nil }

    // ponytail: 마감일 경과 시 자동 마감은 서버 상태 변경 없이 표시/필터 레벨에서 처리
    public func isRecruiting(asOf now: Date = Date()) -> Bool {
        status == .recruiting && deadline >= now
    }
}

public enum RecruitStatus: String, Equatable, Sendable, CaseIterable {
    case recruiting
    case closed
}

public enum RecruitField: String, Equatable, Sendable, Hashable, CaseIterable {
    case flightAttendant = "flight_attendant"
    case announcer
    case generalInterview = "general_interview"
    case speech
    case etc

    public var displayText: String {
        switch self {
        case .flightAttendant: return "승무원"
        case .announcer: return "아나운서"
        case .generalInterview: return "일반 면접"
        case .speech: return "스피치"
        case .etc: return "기타"
        }
    }
}

public enum RecruitMeetingType: String, Equatable, Sendable, Hashable, CaseIterable {
    case online
    case offline
    case hybrid

    public var displayText: String {
        switch self {
        case .online: return "온라인"
        case .offline: return "오프라인"
        case .hybrid: return "온·오프라인"
        }
    }

    public var requiresRegion: Bool { self != .online }
}
