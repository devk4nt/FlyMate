import Foundation
import Domain

enum DTOMapper {
    nonisolated(unsafe) private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func parseDate(_ string: String) -> Date {
        isoFormatter.date(from: string) ?? Date()
    }

    // MARK: - User

    static func toDomain(_ dto: UserDTO) -> User {
        User(
            id: dto.id,
            email: dto.email,
            name: dto.name,
            profileImageURL: dto.profileImageURL.flatMap(URL.init(string:)),
            provider: AuthProvider(rawValue: dto.provider) ?? .apple,
            createdAt: parseDate(dto.createdAt)
        )
    }

    // MARK: - Study

    static func toDomain(_ dto: StudyDTO, members: [StudyMemberDTO]) -> Study {
        Study(
            id: dto.id,
            name: dto.name,
            description: dto.description,
            ownerID: dto.ownerID,
            inviteCode: dto.inviteCode,
            maxMembers: dto.maxMembers,
            members: members.map(toDomain),
            createdAt: parseDate(dto.createdAt),
            notice: dto.notice,
            noticeUpdatedAt: dto.noticeUpdatedAt.map(parseDate)
        )
    }

    static func toDomain(_ dto: StudyMemberDTO) -> StudyMember {
        StudyMember(
            id: dto.id,
            userID: dto.userID,
            userName: dto.userName,
            profileImageURL: dto.profileImageURL.flatMap(URL.init(string:)),
            role: MemberRole(rawValue: dto.role) ?? .member,
            joinedAt: parseDate(dto.joinedAt)
        )
    }

    // MARK: - JoinRequest

    static func toDomain(_ dto: JoinRequestDTO) -> JoinRequest {
        JoinRequest(
            id: dto.id,
            studyID: dto.studyID,
            studyName: dto.studyName,
            userID: dto.userID,
            userName: dto.userName,
            profileImageURL: dto.profileImageURL.flatMap(URL.init(string:)),
            status: JoinRequestStatus(rawValue: dto.status) ?? .pending,
            createdAt: parseDate(dto.createdAt),
            respondedAt: dto.respondedAt.map(parseDate)
        )
    }

    // MARK: - Video

    static func toDomain(_ dto: VideoDTO) -> Video {
        Video(
            id: dto.id,
            studyID: dto.studyID,
            uploaderID: dto.uploaderID,
            uploaderName: dto.uploaderName,
            title: dto.title,
            videoURL: URL(string: dto.videoURL)!,
            thumbnailURL: dto.thumbnailURL.flatMap(URL.init(string:)),
            durationSeconds: dto.durationSeconds,
            feedbackCount: dto.feedbackCount,
            focusPoints: dto.focusPoints,
            feedbackRequest: dto.feedbackRequest,
            createdAt: parseDate(dto.createdAt)
        )
    }

    // MARK: - Feedback

    static func toDomain(_ dto: FeedbackDTO) -> Feedback {
        Feedback(
            id: dto.id,
            videoID: dto.videoID,
            studyID: dto.studyID,
            authorID: dto.authorID,
            authorName: dto.authorName,
            authorProfileURL: dto.authorProfileURL.flatMap(URL.init(string:)),
            content: dto.content,
            timestampSeconds: dto.timestampSeconds,
            createdAt: parseDate(dto.createdAt),
            mentionedUserIDs: dto.mentionedUserIDs ?? []
        )
    }

    // MARK: - Report

    static func toDomain(_ dto: ReportDTO) -> Report {
        Report(
            id: dto.id,
            reporterID: dto.reporterID,
            targetType: ReportTargetType(rawValue: dto.targetType) ?? .feedback,
            targetID: dto.targetID,
            reason: ReportReason(rawValue: dto.reason) ?? .other,
            detail: dto.detail,
            createdAt: parseDate(dto.createdAt)
        )
    }

    // MARK: - Notification

    static func toDomain(_ dto: NotificationDTO) -> AppNotification {
        AppNotification(
            id: dto.id,
            recipientID: dto.recipientID,
            type: NotificationType(rawValue: dto.type) ?? .feedbackOnMyVideo,
            title: dto.title,
            body: dto.body,
            referenceVideoID: dto.referenceVideoID,
            referenceFeedbackID: dto.referenceFeedbackID,
            isRead: dto.isRead,
            createdAt: parseDate(dto.createdAt)
        )
    }
}
