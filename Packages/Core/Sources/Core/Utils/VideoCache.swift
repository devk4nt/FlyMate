import Foundation

/// 재생한 영상을 기기에 캐시해 같은 영상의 재다운로드를 막는다.
///
/// AVPlayer는 progressive MP4에 `URLCache`를 사용하지 않아, 같은 영상을 두 번 보면
/// 두 번 모두 서버에서 내려받는다. Supabase Cached Egress는 전송 바이트로 과금되므로
/// 재시청 트래픽이 그대로 비용이 된다 — 첫 재생만 네트워크를 쓰도록 디스크에 보관한다.
public enum VideoCache {
    private static let directory = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("VideoCache", isDirectory: true)

    /// 기본 보관 기간 — 스터디 피드백 주기를 고려한 값.
    public static let defaultTTL: TimeInterval = 7 * 24 * 60 * 60

    /// 서명 URL은 재발급마다 토큰이 바뀌므로 쿼리를 제외한 스토리지 경로를 키로 쓴다.
    ///
    /// `String.hashValue`는 프로세스마다 시드가 달라 실행 간 값이 바뀌므로 캐시 키로 쓸 수 없다.
    /// 경로 자체를 파일명으로 평탄화해 런치를 넘어 안정적인 키를 만든다.
    static func cacheFileURL(for remoteURL: URL) -> URL {
        let key = remoteURL.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent(key)
    }

    /// 캐시에 있으면 로컬 파일 URL을, 없으면 내려받아 저장한 뒤 그 URL을 반환한다.
    /// 다운로드에 실패하면 원본 URL을 그대로 돌려줘 기존 스트리밍 재생으로 폴백한다.
    public static func localURL(for remoteURL: URL) async -> URL {
        guard !remoteURL.isFileURL else { return remoteURL }

        let file = cacheFileURL(for: remoteURL)
        if FileManager.default.fileExists(atPath: file.path) {
            // TTL 정리가 LRU처럼 동작하도록 접근 시각을 갱신한다
            try? FileManager.default.setAttributes(
                [.modificationDate: Date()],
                ofItemAtPath: file.path
            )
            return file
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let (downloaded, response) = try await URLSession.shared.download(from: remoteURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                try? FileManager.default.removeItem(at: downloaded)
                FMLogger.error("영상 캐시 다운로드 실패 — 스트리밍으로 폴백", category: .video)
                return remoteURL
            }
            try? FileManager.default.removeItem(at: file)
            try FileManager.default.moveItem(at: downloaded, to: file)
            return file
        } catch {
            FMLogger.error("영상 캐시 저장 실패: \(error) — 스트리밍으로 폴백", category: .video)
            return remoteURL
        }
    }

    /// ponytail: TTL 일괄 삭제. 영상 1개가 평균 5MB라 용량 기반 LRU는 아직 과하다 —
    /// 캐시 폴더가 수백MB로 불어나면 그때 용량 상한을 추가할 것.
    public static func purgeStale(olderThan ttl: TimeInterval = defaultTTL) {
        let cutoff = Date().addingTimeInterval(-ttl)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []

        for file in files {
            let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate
            guard let modified, modified < cutoff else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }
}
