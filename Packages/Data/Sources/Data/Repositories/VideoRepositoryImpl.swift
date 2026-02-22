import Foundation
import Domain
import Supabase
import Core

public struct VideoRepositoryImpl: VideoRepository {
    private let client: SupabaseClient
    private let storageService: StorageService

    public init(client: SupabaseClient) {
        self.client = client
        self.storageService = StorageService(client: client)
    }

    public func fetchVideos(studyID: UUID, cursor: Date?) async throws -> [Video] {
        let dtos: [VideoDTO]
        if let cursor {
            dtos = try await client.from(SupabaseConfig.Table.videos)
                .select()
                .eq("study_id", value: studyID)
                .lt("created_at", value: ISO8601DateFormatter().string(from: cursor))
                .order("created_at", ascending: false)
                .limit(AppConstants.defaultPageSize)
                .execute()
                .value
        } else {
            dtos = try await client.from(SupabaseConfig.Table.videos)
                .select()
                .eq("study_id", value: studyID)
                .order("created_at", ascending: false)
                .limit(AppConstants.defaultPageSize)
                .execute()
                .value
        }
        return dtos.map(DTOMapper.toDomain)
    }

    public func fetchVideo(id: UUID) async throws -> Video {
        let dto: VideoDTO = try await client.from(SupabaseConfig.Table.videos)
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        return DTOMapper.toDomain(dto)
    }

    public func uploadVideo(
        _ request: UploadVideoRequest,
        progress: @Sendable (Double) -> Void
    ) async throws -> Video {
        let videoID = UUID()

        // 영상 업로드
        progress(0.1)
        let videoURL = try await storageService.uploadVideo(
            data: request.videoData,
            studyID: request.studyID,
            videoID: videoID
        )
        progress(0.7)

        // 썸네일 업로드
        var thumbnailURL: URL?
        if let thumbnailData = request.thumbnailData {
            thumbnailURL = try await storageService.uploadThumbnail(
                data: thumbnailData,
                studyID: request.studyID,
                videoID: videoID
            )
        }
        progress(0.9)

        // DB에 영상 레코드 생성
        struct InsertVideo: Codable {
            let id: UUID
            let studyID: UUID
            let uploaderID: UUID
            let title: String
            let videoURL: String
            let thumbnailURL: String?
            let durationSeconds: Double
            enum CodingKeys: String, CodingKey {
                case id, title
                case studyID = "study_id"
                case uploaderID = "uploader_id"
                case videoURL = "video_url"
                case thumbnailURL = "thumbnail_url"
                case durationSeconds = "duration_seconds"
            }
        }

        let userID = try await client.auth.session.user.id
        let dto: VideoDTO = try await client.from(SupabaseConfig.Table.videos)
            .insert(InsertVideo(
                id: videoID,
                studyID: request.studyID,
                uploaderID: userID,
                title: request.title,
                videoURL: videoURL.absoluteString,
                thumbnailURL: thumbnailURL?.absoluteString,
                durationSeconds: 0
            ))
            .select()
            .single()
            .execute()
            .value

        progress(1.0)
        return DTOMapper.toDomain(dto)
    }

    public func deleteVideo(id: UUID) async throws {
        try await client.from(SupabaseConfig.Table.videos)
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
