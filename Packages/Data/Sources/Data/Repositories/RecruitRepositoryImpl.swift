import Foundation
import Domain
import Supabase
import Core

public struct RecruitRepositoryImpl: RecruitRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Posts

    public func fetchPosts(filter: RecruitPostFilter, cursor: Date?) async throws -> [RecruitPost] {
        var query = client.from(SupabaseConfig.Table.recruitPosts)
            .select()
            .eq("is_hidden", value: false)

        if filter.recruitingOnly {
            query = query
                .eq("status", value: RecruitStatus.recruiting.rawValue)
                .gte("deadline", value: isoString(Date()))
        }
        if let field = filter.field {
            query = query.eq("field", value: field.rawValue)
        }
        if let meetingType = filter.meetingType {
            query = query.eq("meeting_type", value: meetingType.rawValue)
        }
        if let cursor {
            query = query.lt("created_at", value: isoString(cursor))
        }

        let dtos: [RecruitPostDTO] = try await query
            .order("created_at", ascending: false)
            .limit(AppConstants.defaultPageSize)
            .execute()
            .value
        return dtos.map(DTOMapper.toDomain)
    }

    public func fetchPost(id: UUID) async throws -> RecruitPost {
        let dto: RecruitPostDTO = try await client.from(SupabaseConfig.Table.recruitPosts)
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        return DTOMapper.toDomain(dto)
    }

    public func createPost(_ draft: RecruitPostDraft) async throws -> RecruitPost {
        let user = try await client.auth.session.user

        // author_name / author_profile_url 은 hydrate_author_profile 트리거가
        // public.users 에서 채운다 (auth userMetadata 는 Apple 계정에서 비어 있을 수 있음)
        struct InsertPost: Encodable {
            let payload: PostPayload
            let authorID: UUID

            func encode(to encoder: Encoder) throws {
                try payload.encode(to: encoder)
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(authorID, forKey: .authorID)
            }

            enum CodingKeys: String, CodingKey {
                case authorID = "author_id"
            }
        }

        let dto: RecruitPostDTO = try await client.from(SupabaseConfig.Table.recruitPosts)
            .insert(InsertPost(
                payload: postPayload(draft),
                authorID: user.id
            ))
            .select()
            .single()
            .execute()
            .value
        return DTOMapper.toDomain(dto)
    }

    public func updatePost(id: UUID, draft: RecruitPostDraft) async throws -> RecruitPost {
        let dto: RecruitPostDTO = try await client.from(SupabaseConfig.Table.recruitPosts)
            .update(postPayload(draft))
            .eq("id", value: id)
            .select()
            .single()
            .execute()
            .value
        return DTOMapper.toDomain(dto)
    }

    public func linkStudy(postID: UUID, studyID: UUID) async throws -> RecruitPost {
        struct StudyLinkUpdate: Encodable {
            let studyID: UUID

            enum CodingKeys: String, CodingKey {
                case studyID = "study_id"
            }
        }

        let dto: RecruitPostDTO = try await client.from(SupabaseConfig.Table.recruitPosts)
            .update(StudyLinkUpdate(studyID: studyID))
            .eq("id", value: postID)
            .select()
            .single()
            .execute()
            .value
        return DTOMapper.toDomain(dto)
    }

    public func closePost(id: UUID) async throws -> RecruitPost {
        try await updateStatus(id: id, status: .closed, deadline: nil)
    }

    public func reopenPost(id: UUID, deadline: Date) async throws -> RecruitPost {
        try await updateStatus(id: id, status: .recruiting, deadline: deadline)
    }

    public func deletePost(id: UUID) async throws {
        try await client.from(SupabaseConfig.Table.recruitPosts)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Comments

    public func fetchComments(postID: UUID) async throws -> [RecruitComment] {
        let dtos: [RecruitCommentDTO] = try await client.from(SupabaseConfig.Table.recruitComments)
            .select()
            .eq("post_id", value: postID)
            .order("created_at", ascending: true)
            .execute()
            .value
        return dtos.map(DTOMapper.toDomain)
    }

    public func createComment(_ request: CreateRecruitCommentRequest) async throws -> RecruitComment {
        let user = try await client.auth.session.user

        // author_name / author_profile_url 은 hydrate_author_profile 트리거가 채운다
        struct InsertComment: Encodable {
            let postID: UUID
            let parentID: UUID?
            let authorID: UUID
            let content: String

            enum CodingKeys: String, CodingKey {
                case postID = "post_id"
                case parentID = "parent_id"
                case authorID = "author_id"
                case content
            }
        }

        let dto: RecruitCommentDTO = try await client.from(SupabaseConfig.Table.recruitComments)
            .insert(InsertComment(
                postID: request.postID,
                parentID: request.parentID,
                authorID: user.id,
                content: request.content
            ))
            .select()
            .single()
            .execute()
            .value
        return DTOMapper.toDomain(dto)
    }

    public func deleteComment(id: UUID) async throws {
        try await client.from(SupabaseConfig.Table.recruitComments)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Private

    private struct PostPayload: Encodable {
        let title: String
        let description: String
        let field: String
        let meetingType: String
        let region: String?
        let schedule: String
        let startDate: String
        let endDate: String?
        let maxMembers: Int
        let deadline: String
        let requirement: String
        let contactMethod: String
        let linkURL: String?

        enum CodingKeys: String, CodingKey {
            case title
            case description
            case field
            case meetingType = "meeting_type"
            case region
            case schedule
            case startDate = "start_date"
            case endDate = "end_date"
            case maxMembers = "max_members"
            case deadline
            case requirement
            case contactMethod = "contact_method"
            case linkURL = "link_url"
        }
    }

    private func postPayload(_ draft: RecruitPostDraft) -> PostPayload {
        PostPayload(
            title: draft.title,
            description: draft.description,
            field: draft.field.rawValue,
            meetingType: draft.meetingType.rawValue,
            region: draft.region,
            schedule: draft.schedule,
            startDate: isoString(draft.startDate),
            endDate: draft.endDate.map(isoString),
            maxMembers: draft.maxMembers,
            deadline: isoString(draft.deadline),
            requirement: draft.requirement,
            contactMethod: draft.contactMethod,
            linkURL: draft.linkURL?.absoluteString
        )
    }

    private func updateStatus(id: UUID, status: RecruitStatus, deadline: Date?) async throws -> RecruitPost {
        struct StatusUpdate: Encodable {
            let status: String
            let deadline: String?
        }

        let dto: RecruitPostDTO = try await client.from(SupabaseConfig.Table.recruitPosts)
            .update(StatusUpdate(status: status.rawValue, deadline: deadline.map(isoString)))
            .eq("id", value: id)
            .select()
            .single()
            .execute()
            .value
        return DTOMapper.toDomain(dto)
    }

    private func isoString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
