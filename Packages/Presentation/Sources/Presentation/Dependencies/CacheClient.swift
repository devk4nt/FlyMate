import Foundation
import ComposableArchitecture
import Kingfisher

public struct CacheClient: Sendable {
    public var diskCacheSize: @Sendable () async throws -> UInt
    public var clearCache: @Sendable () async -> Void

    public init(
        diskCacheSize: @escaping @Sendable () async throws -> UInt,
        clearCache: @escaping @Sendable () async -> Void
    ) {
        self.diskCacheSize = diskCacheSize
        self.clearCache = clearCache
    }
}

extension CacheClient: DependencyKey {
    public static let testValue = CacheClient(
        diskCacheSize: unimplemented("\(Self.self).diskCacheSize"),
        clearCache: unimplemented("\(Self.self).clearCache")
    )

    public static let liveValue: CacheClient = CacheClient(
        diskCacheSize: { try await ImageCache.default.diskStorageSize},
        clearCache: {
            ImageCache.default.clearMemoryCache()
            await ImageCache.default.clearDiskCache()
        }
    )
}

extension DependencyValues {
    public var cacheClient: CacheClient {
        get { self[CacheClient.self] }
        set { self[CacheClient.self] = newValue }
    }
}
