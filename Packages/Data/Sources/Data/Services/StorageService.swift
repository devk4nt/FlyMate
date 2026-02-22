import Foundation
import Supabase
import Core

/// Supabase Storage를 통한 파일 업로드/다운로드 서비스.
public struct StorageService: Sendable {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    /// 영상 파일을 업로드하고 공개 URL을 반환한다.
    func uploadVideo(
        data: Data,
        studyID: UUID,
        videoID: UUID
    ) async throws -> URL {
        let path = "\(studyID)/\(videoID).mp4"
        try await client.storage.from(SupabaseConfig.Bucket.videos)
            .upload(path, data: data, options: .init(contentType: "video/mp4"))
        let publicURL = try client.storage.from(SupabaseConfig.Bucket.videos)
            .getPublicURL(path: path)
        return publicURL
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
