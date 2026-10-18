import Foundation
import Testing
@testable import Core

struct VideoCacheTests {
    /// 서명 URL은 재발급마다 토큰이 바뀐다 — 같은 영상이면 같은 캐시 파일을 가리켜야 한다.
    @Test
    func 서명_토큰이_달라도_같은_캐시_파일() throws {
        let first = try #require(URL(string:
            "https://x.supabase.co/storage/v1/object/sign/videos/study-1/video-1.mp4?token=aaa"))
        let second = try #require(URL(string:
            "https://x.supabase.co/storage/v1/object/sign/videos/study-1/video-1.mp4?token=bbb"))

        #expect(VideoCache.cacheFileURL(for: first) == VideoCache.cacheFileURL(for: second))
    }

    @Test
    func 다른_영상은_다른_캐시_파일() throws {
        let first = try #require(URL(string:
            "https://x.supabase.co/storage/v1/object/sign/videos/study-1/video-1.mp4?token=aaa"))
        let second = try #require(URL(string:
            "https://x.supabase.co/storage/v1/object/sign/videos/study-1/video-2.mp4?token=aaa"))

        #expect(VideoCache.cacheFileURL(for: first) != VideoCache.cacheFileURL(for: second))
    }

    /// String.hashValue를 키로 쓰면 실행마다 값이 달라 캐시가 매번 미스가 된다 —
    /// 경로 기반 키라서 문자열이 같으면 항상 같은 결과여야 한다.
    @Test
    func 캐시_키는_경로에서_결정된다() throws {
        let url = try #require(URL(string:
            "https://x.supabase.co/storage/v1/object/sign/videos/quick/user-1/req-1.mp4?token=t"))

        #expect(VideoCache.cacheFileURL(for: url).lastPathComponent
            == "storage_v1_object_sign_videos_quick_user-1_req-1.mp4")
    }

    @Test
    func purgeStale은_오래된_파일만_지운다() throws {
        let fresh = try #require(URL(string:
            "https://x.supabase.co/storage/v1/object/sign/videos/purge/fresh.mp4"))
        let stale = try #require(URL(string:
            "https://x.supabase.co/storage/v1/object/sign/videos/purge/stale.mp4"))
        let freshFile = VideoCache.cacheFileURL(for: fresh)
        let staleFile = VideoCache.cacheFileURL(for: stale)
        let fileManager = FileManager.default

        try fileManager.createDirectory(
            at: freshFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer {
            try? fileManager.removeItem(at: freshFile)
            try? fileManager.removeItem(at: staleFile)
        }
        try Data("fresh".utf8).write(to: freshFile)
        try Data("stale".utf8).write(to: staleFile)
        try fileManager.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-10 * 24 * 60 * 60)],
            ofItemAtPath: staleFile.path
        )

        VideoCache.purgeStale()

        #expect(fileManager.fileExists(atPath: freshFile.path))
        #expect(!fileManager.fileExists(atPath: staleFile.path))
    }

    /// 로컬 파일 URL은 캐시 대상이 아니다 — 그대로 반환해야 한다.
    @Test
    func 파일_URL은_그대로_반환() async {
        let fileURL = URL(fileURLWithPath: "/tmp/sample.mp4")
        #expect(await VideoCache.localURL(for: fileURL) == fileURL)
    }
}
