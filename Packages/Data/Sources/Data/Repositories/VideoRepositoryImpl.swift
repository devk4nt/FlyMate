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
        return try await mapWithSignedURLs(dtos)
    }

    public func fetchFeedVideos(studyIDs: [UUID], cursor: Date?) async throws -> [Video] {
        guard !studyIDs.isEmpty else { return [] }
        let dtos: [VideoDTO]
        if let cursor {
            dtos = try await client.from(SupabaseConfig.Table.videos)
                .select()
                .in("study_id", values: studyIDs)
                .lt("created_at", value: ISO8601DateFormatter().string(from: cursor))
                .order("created_at", ascending: false)
                .limit(AppConstants.defaultPageSize)
                .execute()
                .value
        } else {
            dtos = try await client.from(SupabaseConfig.Table.videos)
                .select()
                .in("study_id", values: studyIDs)
                .order("created_at", ascending: false)
                .limit(AppConstants.defaultPageSize)
                .execute()
                .value
        }
        return try await mapWithSignedURLs(dtos)
    }

    public func fetchPendingFeedbackVideos(studyIDs: [UUID], userID: UUID) async throws -> [Video] {
        guard !studyIDs.isEmpty else { return [] }

        // 스터디원 영상 (내가 올린 것 제외, 오래된 순 — 오래 기다린 영상부터)
        // ponytail: anti-join 대신 2쿼리 + 클라이언트 필터 — 스터디 규모상 데이터가 작아 충분
        let dtos: [VideoDTO] = try await client.from(SupabaseConfig.Table.videos)
            .select()
            .in("study_id", values: studyIDs)
            .neq("uploader_id", value: userID)
            .order("created_at", ascending: true)
            .limit(AppConstants.pendingFeedbackFetchLimit)
            .execute()
            .value

        // 내가 피드백을 남긴 영상 ID 목록
        struct FeedbackedVideoID: Decodable {
            let videoID: UUID
            enum CodingKeys: String, CodingKey {
                case videoID = "video_id"
            }
        }
        let feedbacked: [FeedbackedVideoID] = try await client.from(SupabaseConfig.Table.feedbacks)
            .select("video_id")
            .eq("author_id", value: userID)
            .execute()
            .value
        let completedVideoIDs = Set(feedbacked.map(\.videoID))

        return try await mapWithSignedURLs(
            dtos.filter { !completedVideoIDs.contains($0.id) }
        )
    }

    public func fetchVideo(id: UUID) async throws -> Video {
        let dto: VideoDTO = try await client.from(SupabaseConfig.Table.videos)
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        guard let video = try await mapWithSignedURLs([dto]).first else {
            throw AppError.unexpected("영상 서명 URL 발급에 실패했습니다.")
        }
        return video
    }

    public func uploadVideo(
        _ request: UploadVideoRequest,
        progress: @Sendable (Double) -> Void
    ) async throws -> Video {
        let videoID = UUID()

        // 영상 업로드
        progress(0.1)
        let videoPath = try await storageService.uploadVideo(
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
            let focusPoints: String?
            let feedbackRequest: String?
            enum CodingKeys: String, CodingKey {
                case id, title
                case studyID = "study_id"
                case uploaderID = "uploader_id"
                case videoURL = "video_url"
                case thumbnailURL = "thumbnail_url"
                case durationSeconds = "duration_seconds"
                case focusPoints = "focus_points"
                case feedbackRequest = "feedback_request"
            }
        }

        let userID = try await client.auth.session.user.id
        let dto: VideoDTO = try await client.from(SupabaseConfig.Table.videos)
            .insert(InsertVideo(
                id: videoID,
                studyID: request.studyID,
                uploaderID: userID,
                title: request.title,
                videoURL: videoPath,
                thumbnailURL: thumbnailURL?.absoluteString,
                durationSeconds: request.durationSeconds,
                focusPoints: request.focusPoints,
                feedbackRequest: request.feedbackRequest
            ))
            .select()
            .single()
            .execute()
            .value

        progress(1.0)
        guard let video = try await mapWithSignedURLs([dto]).first else {
            throw AppError.unexpected("영상 서명 URL 발급에 실패했습니다.")
        }
        return video
    }

    public func deleteVideo(id: UUID) async throws {
        try await client.from(SupabaseConfig.Table.videos)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Signed URL

    /// private 버킷 영상의 재생용 서명 URL을 일괄 발급해 도메인 모델로 변환한다.
    private func mapWithSignedURLs(_ dtos: [VideoDTO]) async throws -> [Video] {
        guard !dtos.isEmpty else { return [] }
        let paths = dtos.map { StorageService.videoPath(studyID: $0.studyID, videoID: $0.id) }
        let urls = try await storageService.signedVideoURLs(paths: paths)
        // 전건 실패는 스토리지 장애/권한 문제 — 빈 목록(데이터 없음)으로 위장하지 않고 에러로 알린다
        guard !urls.isEmpty else { throw AppError.network(.invalidResponse) }
        // 일부 실패한 영상만 제외하고 나머지는 그대로 노출한다
        return zip(dtos, paths).compactMap { dto, path in
            urls[path].map { DTOMapper.toDomain(dto, videoURL: $0) }
        }
    }
}
