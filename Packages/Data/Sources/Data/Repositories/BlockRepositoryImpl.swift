import Foundation
import Domain
import Supabase

public struct BlockRepositoryImpl: BlockRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func blockUser(_ userID: UUID) async throws {
        let blockerID = try await client.auth.session.user.id

        struct InsertBlock: Codable {
            let blockerID: UUID
            let blockedID: UUID
            enum CodingKeys: String, CodingKey {
                case blockerID = "blocker_id"
                case blockedID = "blocked_id"
            }
        }

        // upsert: 이미 차단한 경우에도 에러 없이 멱등 처리
        try await client.from(SupabaseConfig.Table.blockedUsers)
            .upsert(InsertBlock(blockerID: blockerID, blockedID: userID))
            .execute()
    }

    public func unblockUser(_ userID: UUID) async throws {
        let blockerID = try await client.auth.session.user.id

        try await client.from(SupabaseConfig.Table.blockedUsers)
            .delete()
            .eq("blocker_id", value: blockerID)
            .eq("blocked_id", value: userID)
            .execute()
    }

    public func fetchBlockedUsers() async throws -> [BlockedUser] {
        // RLS가 내 차단 목록만 반환한다
        let blocks: [BlockedUserDTO] = try await client.from(SupabaseConfig.Table.blockedUsers)
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value

        guard !blocks.isEmpty else { return [] }

        // 탈퇴한 사용자는 users에 없을 수 있으므로 매퍼에서 폴백 처리
        let users: [UserDTO] = try await client.from(SupabaseConfig.Table.users)
            .select()
            .in("id", values: blocks.map(\.blockedID))
            .execute()
            .value
        let usersByID = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

        return blocks.map { DTOMapper.toDomain($0, user: usersByID[$0.blockedID]) }
    }
}
