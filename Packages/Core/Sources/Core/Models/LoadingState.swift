import Foundation

/// 모든 비동기 데이터 로딩 상태를 표현하는 제네릭 enum.
/// View에서 idle/loading/loaded/failed 각각에 맞는 UI를 분기하여 렌더링한다.
public enum LoadingState<T: Equatable & Sendable>: Equatable, Sendable {
    case idle
    case loading
    case loaded(T)
    case failed(AppError)

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var value: T? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    public var error: AppError? {
        if case .failed(let error) = self { return error }
        return nil
    }
}
