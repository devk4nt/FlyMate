import Foundation

/// Exponential backoff 기반의 재시도 유틸리티.
/// 네트워크 요청 등 일시적 실패에 대한 자동 재시도에 사용한다.
public func withRetry<T: Sendable>(
    maxAttempts: Int = 3,
    initialDelaySeconds: TimeInterval = 1.0,
    maxDelaySeconds: TimeInterval = 30.0,
    operation: @Sendable () async throws -> T
) async throws -> T {
    var currentDelay = initialDelaySeconds

    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            if attempt == maxAttempts {
                throw error
            }

            FMLogger.warning(
                "Retry attempt \(attempt)/\(maxAttempts) failed: \(error.localizedDescription). Retrying in \(currentDelay)s...",
                category: .network
            )

            try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))

            // Exponential backoff with jitter
            let nextDelay = currentDelay * 2
            let jitter = TimeInterval.random(in: 0...0.5)
            currentDelay = min(nextDelay + jitter, maxDelaySeconds)
        }
    }

    fatalError("Unreachable")
}
