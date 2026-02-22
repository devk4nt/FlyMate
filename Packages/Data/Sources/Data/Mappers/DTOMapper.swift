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
            createdAt: parseDate(dto.createdAt)
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
            mentionedUserID: dto.mentionedUserID
        )
    }
}
