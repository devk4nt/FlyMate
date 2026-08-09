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
    func signedVideoURLs(paths: [String]) async throws -> [URL] {
        guard !paths.isEmpty else { return [] }
        return try await client.storage.from(SupabaseConfig.Bucket.videos)
            .createSignedURLs(paths: paths, expiresIn: AppConstants.signedVideoURLExpirySeconds)
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
