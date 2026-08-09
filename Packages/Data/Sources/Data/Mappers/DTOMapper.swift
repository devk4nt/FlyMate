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

    /// videoURL은 조회 시점에 발급한 서명 URL — DTO의 video_url(스토리지 경로)은 사용하지 않는다.
    static func toDomain(_ dto: VideoDTO, videoURL: URL) -> Video {
        Video(
            id: dto.id,
            studyID: dto.studyID,
            uploaderID: dto.uploaderID,
            uploaderName: dto.uploaderName,
            title: dto.title,
            videoURL: videoURL,
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
            mentionedUserIDs: dto.mentionedUserIDs ?? [],
            commentCount: dto.commentCount ?? 0
        )
    }


    // MARK: - FeedbackComment

    static func toDomain(_ dto: FeedbackCommentDTO) -> FeedbackComment {
        FeedbackComment(
            id: dto.id,
            feedbackID: dto.feedbackID,
            studyID: dto.studyID,
            authorID: dto.authorID,
            authorName: dto.authorName,
            authorProfileURL: dto.authorProfileURL.flatMap(URL.init(string:)),
            content: dto.content,
            mentionedUserIDs: dto.mentionedUserIDs ?? [],
            createdAt: parseDate(dto.createdAt)
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

    // MARK: - Subscription

    static func toDomain(_ dto: SubscriptionDTO) -> Subscription {
        Subscription(
            id: dto.id,
            userID: dto.userID,
            planID: dto.planID,
            status: SubscriptionStatus(rawValue: dto.status) ?? .active,
            originalTransactionID: dto.originalTransactionID,
            latestTransactionID: dto.latestTransactionID,
            productID: dto.productID,
            environment: SubscriptionEnvironment(rawValue: dto.environment ?? "production") ?? .production,
            purchaseDate: dto.purchaseDate.map(parseDate),
            expiresDate: dto.expiresDate.map(parseDate),
            isInBillingRetry: dto.isInBillingRetry,
            autoRenewStatus: dto.autoRenewStatus,
            createdAt: parseDate(dto.createdAt),
            updatedAt: parseDate(dto.updatedAt)
        )
    }

    static func toDomain(_ dto: SubscriptionPlanDTO) -> SubscriptionPlan {
        SubscriptionPlan(
            id: dto.id,
            name: dto.name,
            maxOwnedStudies: dto.maxOwnedStudies,
            maxJoinedStudies: dto.maxJoinedStudies,
            maxVideoDurationSeconds: dto.maxVideoDurationSeconds,
            maxStudyMembers: dto.maxStudyMembers
        )
    }

    static func toDomain(_ dto: EntitlementDTO) -> Entitlement {
        Entitlement(
            planID: dto.planID,
            status: dto.status,
            expiresDate: dto.expiresDate.map(parseDate),
            maxOwnedStudies: dto.maxOwnedStudies,
            maxJoinedStudies: dto.maxJoinedStudies,
            maxVideoDurationSeconds: dto.maxVideoDurationSeconds,
            maxStudyMembers: dto.maxStudyMembers,
            currentOwnedStudies: dto.currentOwnedStudies,
            currentJoinedStudies: dto.currentJoinedStudies
        )
    }

    static func toDomain(_ dto: FeatureLimitDTO) -> FeatureLimit {
        FeatureLimit(
            allowed: dto.allowed,
            current: dto.current,
            max: dto.max,
            feature: dto.feature
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
