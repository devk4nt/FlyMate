import Foundation

public protocol BlockRepository: Sendable {
    /// 사용자를 차단한다. 이미 차단한 경우 무시된다.
    /// - Parameter name: 차단 시점의 사용자 이름 (users 테이블은 RLS로 타인 조회가 불가하므로 비정규화 저장)
    func blockUser(_ userID: UUID, name: String) async throws

    /// 차단을 해제한다.
    func unblockUser(_ userID: UUID) async throws

    /// 내가 차단한 사용자 목록을 조회한다 (최근 차단 순).
    func fetchBlockedUsers() async throws -> [BlockedUser]
}
