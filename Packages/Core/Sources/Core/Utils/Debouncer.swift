import Foundation

/// 연속된 호출을 debounce하여 마지막 호출만 실행하는 유틸리티.
/// 검색 입력, 빠른 연속 탭 방어 등에 사용한다.
public actor Debouncer {
    private let nanoseconds: UInt64
    private var task: Task<Void, Never>?

    public init(seconds: TimeInterval = 0.3) {
        self.nanoseconds = UInt64(seconds * 1_000_000_000)
    }

    /// 이전 호출을 취소하고, 설정된 시간 이후에 operation을 실행한다.
    public func debounce(operation: @escaping @Sendable () async -> Void) {
        task?.cancel()
        task = Task {
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else { return }
                await operation()
            } catch {
                // Task가 취소된 경우 — 의도된 동작
            }
        }
    }

    /// 대기 중인 작업을 취소한다.
    public func cancel() {
        task?.cancel()
        task = nil
    }
}
