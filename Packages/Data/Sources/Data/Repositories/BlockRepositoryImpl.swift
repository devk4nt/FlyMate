import Foundation
import Domain
import Supabase

public struct BlockRepositoryImpl: BlockRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func blockUser(_ userID: UUID, name: String) async throws {
        let blockerID = try await client.auth.session.user.id

        struct InsertBlock: Codable {
            let blockerID: UUID
            let blockedID: UUID
            let blockedName: String
            enum CodingKeys: String, CodingKey {
                case blockerID = "blocker_id"
                case blockedID = "blocked_id"
                case blockedName = "blocked_name"
            }
        }

        // upsert: 이미 차단한 경우에도 에러 없이 멱등 처리
        try await client.from(SupabaseConfig.Table.blockedUsers)
            .upsert(InsertBlock(blockerID: blockerID, blockedID: userID, blockedName: name))
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
        // RLS가 내 차단 목록만 반환한다. 이름은 차단 시점에 비정규화 저장됨
        // (users 테이블은 RLS로 타인 row 조회가 불가)
        let blocks: [BlockedUserDTO] = try await client.from(SupabaseConfig.Table.blockedUsers)
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value

        return blocks.map(DTOMapper.toDomain)
    }
}
