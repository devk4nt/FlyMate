import Foundation

/// 커서 기반 페이지네이션 상태를 표현하는 제네릭 구조체.
/// 무한 스크롤, 더보기 등의 UI에서 공통으로 사용한다.
public struct PaginatedState<T: Equatable & Sendable>: Equatable, Sendable {
    public var items: [T]
    public var cursor: Date?
    public var hasMore: Bool
    public var isLoadingMore: Bool

    public init(
        items: [T] = [],
        cursor: Date? = nil,
        hasMore: Bool = true,
        isLoadingMore: Bool = false
    ) {
        self.items = items
        self.cursor = cursor
        self.hasMore = hasMore
        self.isLoadingMore = isLoadingMore
    }
}
