import Foundation
import ComposableArchitecture
import Domain

public struct BlockClient: Sendable {
    public var blockUser: @Sendable (_ userID: UUID, _ name: String) async throws -> Void
    public var unblockUser: @Sendable (UUID) async throws -> Void
    public var fetchBlockedUsers: @Sendable () async throws -> [BlockedUser]

    public init(
        blockUser: @escaping @Sendable (_ userID: UUID, _ name: String) async throws -> Void,
        unblockUser: @escaping @Sendable (UUID) async throws -> Void,
        fetchBlockedUsers: @escaping @Sendable () async throws -> [BlockedUser]
    ) {
        self.blockUser = blockUser
        self.unblockUser = unblockUser
        self.fetchBlockedUsers = fetchBlockedUsers
    }
}

extension BlockClient: TestDependencyKey {
    public static let testValue = BlockClient(
        blockUser: unimplemented("\(Self.self).blockUser"),
        unblockUser: unimplemented("\(Self.self).unblockUser"),
        fetchBlockedUsers: unimplemented("\(Self.self).fetchBlockedUsers")
    )
}

extension DependencyValues {
    public var blockClient: BlockClient {
        get { self[BlockClient.self] }
        set { self[BlockClient.self] = newValue }
    }
}
