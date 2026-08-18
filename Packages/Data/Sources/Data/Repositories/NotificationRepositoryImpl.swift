import Core
import Domain
import Foundation
import Supabase

public struct NotificationRepositoryImpl: NotificationRepository {
    private let client: SupabaseClient
    private let realtimeService: RealtimeService

    public init(client: SupabaseClient) {
        self.client = client
        self.realtimeService = RealtimeService(client: client)
    }

    public func fetchNotifications(userID: UUID, cursor: Date?) async throws -> [AppNotification] {
        let dtos: [NotificationDTO]
        if let cursor {
            dtos = try await client.from(SupabaseConfig.Table.notifications)
                .select()
                .eq("recipient_id", value: userID)
                .lt("created_at", value: ISO8601DateFormatter().string(from: cursor))
                .order("created_at", ascending: false)
                .limit(AppConstants.defaultPageSize)
                .execute()
                .value
        } else {
            dtos = try await client.from(SupabaseConfig.Table.notifications)
                .select()
                .eq("recipient_id", value: userID)
                .order("created_at", ascending: false)
                .limit(AppConstants.defaultPageSize)
                .execute()
                .value
        }
        return dtos.map(DTOMapper.toDomain)
    }

    public func fetchUnreadCount(userID: UUID) async throws -> Int {
        let response = try await client.from(SupabaseConfig.Table.notifications)
            .select("id", head: true, count: .exact)
            .eq("recipient_id", value: userID)
            .eq("is_read", value: false)
            .execute()
        return response.count ?? 0
    }

    public func fetchStartupAnnouncement() async throws -> AppNotification? {
        let dtos: [NotificationDTO] = try await client
            .rpc(SupabaseConfig.RPC.syncStartupAnnouncement)
            .execute()
            .value
        return dtos.first.map(DTOMapper.toDomain)
    }

    public func markAsRead(id: UUID) async throws {
        struct IsReadUpdate: Codable {
            let isRead: Bool
            enum CodingKeys: String, CodingKey {
                case isRead = "is_read"
            }
        }
        try await client.from(SupabaseConfig.Table.notifications)
            .update(IsReadUpdate(isRead: true))
            .eq("id", value: id)
            .execute()
    }

    public func markAllAsRead(userID: UUID) async throws {
        struct IsReadUpdate: Codable {
            let isRead: Bool
            enum CodingKeys: String, CodingKey {
                case isRead = "is_read"
            }
        }
        try await client.from(SupabaseConfig.Table.notifications)
            .update(IsReadUpdate(isRead: true))
            .eq("recipient_id", value: userID)
            .eq("is_read", value: false)
            .execute()
    }

    public func observeNotifications(userID: UUID) -> AsyncStream<AppNotification> {
        AsyncStream { continuation in
            let task = Task {
                let channel = client.realtimeV2.channel(
                    "\(SupabaseConfig.RealtimeChannel.notifications):\(userID)"
                )

                let changes = channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: SupabaseConfig.Table.notifications,
                    filter: "recipient_id=eq.\(userID)"
                )

                await channel.subscribe()

                for await change in changes {
                    do {
                        let dto = try change.decodeRecord(as: NotificationDTO.self, decoder: JSONDecoder())
                        let notification = DTOMapper.toDomain(dto)
                        continuation.yield(notification)
                    } catch {
                        FMLogger.error(
                            "Failed to decode notification from realtime: \(error)",
                            category: .notification
                        )
                    }
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
