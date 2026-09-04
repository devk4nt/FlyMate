import Foundation
import Domain
import Supabase

public struct FeedbackCommentRepositoryImpl: FeedbackCommentRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func fetchComments(feedbackID: UUID) async throws -> [FeedbackComment] {
        let dtos: [FeedbackCommentDTO] = try await client
            .from(SupabaseConfig.Table.feedbackComments)
            .select()
            .eq("feedback_id", value: feedbackID)
            .order("created_at", ascending: false)
            .execute()
            .value
        return dtos.map(DTOMapper.toDomain)
    }

    public func fetchLatestComments(feedbackIDs: [UUID]) async throws -> [UUID: FeedbackComment] {
        guard !feedbackIDs.isEmpty else { return [:] }

        let dtos: [FeedbackCommentDTO] = try await client
            .rpc("fetch_latest_feedback_comments", params: ["p_feedback_ids": feedbackIDs])
            .execute()
            .value

        var result: [UUID: FeedbackComment] = [:]
        for dto in dtos {
            result[dto.feedbackID] = DTOMapper.toDomain(dto)
        }
        return result
    }

    public func createComment(_ request: CreateFeedbackCommentRequest) async throws -> FeedbackComment {
        let user = try await client.auth.session.user

        // author_name / author_profile_url 은 hydrate_author_profile 트리거가
        // public.users 에서 채운다 (auth userMetadata 는 Apple 계정에서 비어 있을 수 있음)
        struct InsertComment: Codable {
            let feedbackID: UUID
            let studyID: UUID
            let authorID: UUID
            let content: String
            let mentionedUserIDs: [UUID]
            enum CodingKeys: String, CodingKey {
                case feedbackID = "feedback_id"
                case studyID = "study_id"
                case authorID = "author_id"
                case content
                case mentionedUserIDs = "mentioned_user_ids"
            }
        }

        // feedback의 study_id를 조회
        struct FeedbackStudyDTO: Codable {
            let studyID: UUID
            enum CodingKeys: String, CodingKey {
                case studyID = "study_id"
            }
        }

        let feedbackInfo: FeedbackStudyDTO = try await client
            .from(SupabaseConfig.Table.feedbacks)
            .select("study_id")
            .eq("id", value: request.feedbackID)
            .single()
            .execute()
            .value

        let dto: FeedbackCommentDTO = try await client
            .from(SupabaseConfig.Table.feedbackComments)
            .insert(InsertComment(
                feedbackID: request.feedbackID,
                studyID: feedbackInfo.studyID,
                authorID: user.id,
                content: request.content,
                mentionedUserIDs: request.mentionedUserIDs
            ))
            .select()
            .single()
            .execute()
            .value

        return DTOMapper.toDomain(dto)
    }

    public func deleteComment(id: UUID) async throws {
        try await client
            .from(SupabaseConfig.Table.feedbackComments)
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
