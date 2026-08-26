import Foundation
import Supabase
import Core

/// Supabase Storage를 통한 파일 업로드/다운로드 서비스.
public struct StorageService: Sendable {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    /// 영상 파일 스토리지 경로 — 버킷은 private이며 재생 시 서명 URL로 접근한다.
    static func videoPath(studyID: UUID, videoID: UUID) -> String {
        "\(studyID)/\(videoID).mp4"
    }

    static func quickFeedbackVideoPath(userID: UUID, requestID: UUID) -> String {
        "quick/\(userID.uuidString.lowercased())/\(requestID).mp4"
    }

    func uploadQuickFeedbackVideo(data: Data, userID: UUID, requestID: UUID) async throws -> String {
        let path = Self.quickFeedbackVideoPath(userID: userID, requestID: requestID)
        try await client.storage.from(SupabaseConfig.Bucket.videos)
            .upload(path, data: data, options: .init(contentType: "video/mp4"))
        return path
    }

    func signedVideoURL(path: String) async throws -> URL {
        try await client.storage.from(SupabaseConfig.Bucket.videos)
            .createSignedURL(path: path, expiresIn: AppConstants.signedVideoURLExpirySeconds)
    }

    func deleteQuickFeedbackVideo(path: String) async {
        _ = try? await client.storage.from(SupabaseConfig.Bucket.videos).remove(paths: [path])
    }

    /// 빠른 피드백 썸네일을 업로드하고 공개 URL을 반환한다.
    func uploadQuickFeedbackThumbnail(data: Data, userID: UUID, requestID: UUID) async throws -> URL {
        let path = "quick/\(userID.uuidString.lowercased())/\(requestID).jpg"
        try await client.storage.from(SupabaseConfig.Bucket.thumbnails)
            .upload(path, data: data, options: .init(contentType: "image/jpeg"))
        return try client.storage.from(SupabaseConfig.Bucket.thumbnails).getPublicURL(path: path)
    }

    func deleteQuickFeedbackThumbnail(userID: UUID, requestID: UUID) async {
        let path = "quick/\(userID.uuidString.lowercased())/\(requestID).jpg"
        _ = try? await client.storage.from(SupabaseConfig.Bucket.thumbnails).remove(paths: [path])
    }

    /// 영상 파일을 업로드하고 스토리지 경로를 반환한다.
    func uploadVideo(
        data: Data,
        studyID: UUID,
        videoID: UUID
    ) async throws -> String {
        let path = Self.videoPath(studyID: studyID, videoID: videoID)
        try await client.storage.from(SupabaseConfig.Bucket.videos)
            .upload(path, data: data, options: .init(contentType: "video/mp4"))
        return path
    }

    /// 영상 경로들의 서명 URL을 일괄 발급한다 (스터디 멤버만 허용 — Storage RLS).
    /// 발급에 실패한 경로는 결과에서 제외되므로, 호출부는 경로로 조회해 실패 항목을 건너뛴다.
    func signedVideoURLs(paths: [String]) async throws -> [String: URL] {
        guard !paths.isEmpty else { return [:] }
        let results: [SignedURLResult] = try await client.storage.from(SupabaseConfig.Bucket.videos)
            .createSignedURLs(paths: paths, expiresIn: AppConstants.signedVideoURLExpirySeconds)
        var urls: [String: URL] = [:]
        for result in results {
            switch result {
            case .success(let path, let signedURL):
                urls[path] = signedURL
            case .failure(let path, let error):
                FMLogger.error("영상 서명 URL 발급 실패 — path: \(path), error: \(error)", category: .video)
            }
        }
        return urls
    }

    /// 썸네일 이미지를 업로드하고 공개 URL을 반환한다.
    func uploadThumbnail(
        data: Data,
        studyID: UUID,
        videoID: UUID
    ) async throws -> URL {
        let path = "\(studyID)/\(videoID).jpg"
        try await client.storage.from(SupabaseConfig.Bucket.thumbnails)
            .upload(path, data: data, options: .init(contentType: "image/jpeg"))
        let publicURL = try client.storage.from(SupabaseConfig.Bucket.thumbnails)
            .getPublicURL(path: path)
        return publicURL
    }

    /// 영상/썸네일 파일들을 삭제한다. 파일 정리 실패가 탈퇴 흐름을 막지 않도록 best-effort.
    func deleteVideoFiles(studyID: UUID, videoIDs: [UUID]) async {
        guard !videoIDs.isEmpty else { return }
        let videoPaths = videoIDs.map { "\(studyID)/\($0).mp4" }
        let thumbnailPaths = videoIDs.map { "\(studyID)/\($0).jpg" }
        _ = try? await client.storage.from(SupabaseConfig.Bucket.videos)
            .remove(paths: videoPaths)
        _ = try? await client.storage.from(SupabaseConfig.Bucket.thumbnails)
            .remove(paths: thumbnailPaths)
    }

    /// 프로필 이미지를 업로드하고 공개 URL을 반환한다.
    func uploadProfileImage(data: Data, userID: UUID) async throws -> URL {
        let path = "\(userID).jpg"
        try await client.storage.from(SupabaseConfig.Bucket.profileImages)
            .upload(path, data: data, options: .init(contentType: "image/jpeg", upsert: true))
        let publicURL = try client.storage.from(SupabaseConfig.Bucket.profileImages)
            .getPublicURL(path: path)
        return publicURL
    }
}
