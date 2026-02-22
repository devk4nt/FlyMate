import Foundation
import Domain
import Supabase
import Core

public struct FeedbackRepositoryImpl: FeedbackRepository {
    private let client: SupabaseClient
    private let realtimeService: RealtimeService

    public init(client: SupabaseClient) {
        self.client = client
        self.realtimeService = RealtimeService(client: client)
    }

    public func fetchFeedbacks(videoID: UUID) async throws -> [Feedback] {
        let dtos: [FeedbackDTO] = try await client.from(SupabaseConfig.Table.feedbacks)
            .select()
            .eq("video_id", value: videoID)
            .order("timestamp_seconds")
            .execute()
            .value
        return dtos.map(DTOMapper.toDomain)
    }

    public func createFeedback(_ request: CreateFeedbackRequest) async throws -> Feedback {
        let userID = try await client.auth.session.user.id

        struct InsertFeedback: Codable {
            let videoID: UUID
            let authorID: UUID
            let content: String
            let timestampSeconds: Double
            let mentionedUserID: UUID?
            enum CodingKeys: String, CodingKey {
                case content
                case videoID = "video_id"
                case authorID = "author_id"
                case timestampSeconds = "timestamp_seconds"
                case mentionedUserID = "mentioned_user_id"
            }
        }

        let dto: FeedbackDTO = try await client.from(SupabaseConfig.Table.feedbacks)
            .insert(InsertFeedback(
                videoID: request.videoID,
                authorID: userID,
                content: request.content,
                timestampSeconds: request.timestampSeconds,
                mentionedUserID: request.mentionedUserID
            ))
            .select()
            .single()
            .execute()
            .value

        return DTOMapper.toDomain(dto)
    }

    public func fetchReceivedFeedbacks(userID: UUID, cursor: Date?) async throws -> [Feedback] {
        let dtos: [FeedbackDTO]
        if let cursor {
            dtos = try await client.from(SupabaseConfig.Table.feedbacks)
                .select("*, videos!inner(uploader_id)")
                .eq("videos.uploader_id", value: userID)
                .lt("created_at", value: ISO8601DateFormatter().string(from: cursor))
                .order("created_at", ascending: false)
                .limit(AppConstants.defaultPageSize)
                .execute()
                .value
        } else {
            dtos = try await client.from(SupabaseConfig.Table.feedbacks)
                .select("*, videos!inner(uploader_id)")
                .eq("videos.uploader_id", value: userID)
                .order("created_at", ascending: false)
                .limit(AppConstants.defaultPageSize)
                .execute()
                .value
        }
        return dtos.map(DTOMapper.toDomain)
    }

    public func fetchGivenFeedbacks(userID: UUID, cursor: Date?) async throws -> [Feedback] {
        let dtos: [FeedbackDTO]
        if let cursor {
            dtos = try await client.from(SupabaseConfig.Table.feedbacks)
                .select()
                .eq("author_id", value: userID)
                .lt("created_at", value: ISO8601DateFormatter().string(from: cursor))
                .order("created_at", ascending: false)
                .limit(AppConstants.defaultPageSize)
                .execute()
                .value
        } else {
            dtos = try await client.from(SupabaseConfig.Table.feedbacks)
                .select()
                .eq("author_id", value: userID)
                .order("created_at", ascending: false)
                .limit(AppConstants.defaultPageSize)
                .execute()
                .value
        }
        return dtos.map(DTOMapper.toDomain)
    }

    public func observeFeedbacks(videoID: UUID) -> AsyncStream<[Feedback]> {
        realtimeService.observeFeedbacks(videoID: videoID)
    }

    public func deleteFeedback(id: UUID) async throws {
        try await client.from(SupabaseConfig.Table.feedbacks)
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
