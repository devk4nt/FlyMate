import Foundation
import Domain
import Supabase

public struct UserRepositoryImpl: UserRepository {
    private let client: SupabaseClient
    private let storageService: StorageService

    public init(client: SupabaseClient) {
        self.client = client
        self.storageService = StorageService(client: client)
    }

    public func fetchUser(id: UUID) async throws -> Domain.User {
        let dto: UserDTO = try await client.from(SupabaseConfig.Table.users)
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        return DTOMapper.toDomain(dto)
    }

    public func updateProfile(_ request: UpdateProfileRequest) async throws -> Domain.User {
        let userID = try await client.auth.session.user.id

        var profileImageURL: String?
        if let imageData = request.profileImageData {
            let url = try await storageService.uploadProfileImage(data: imageData, userID: userID)
            profileImageURL = url.absoluteString
        }

        struct UpdateUser: Codable {
            let name: String
            let profileImageURL: String?
            enum CodingKeys: String, CodingKey {
                case name
                case profileImageURL = "profile_image_url"
            }
        }

        let dto: UserDTO = try await client.from(SupabaseConfig.Table.users)
            .update(UpdateUser(name: request.name, profileImageURL: profileImageURL))
            .eq("id", value: userID)
            .select()
            .single()
            .execute()
            .value

        return DTOMapper.toDomain(dto)
    }

    public func registerDeviceToken(_ token: String) async throws {
        let userID = try await client.auth.session.user.id

        struct DeviceToken: Codable {
            let userID: UUID
            let fcmToken: String
            let platform: String
            enum CodingKeys: String, CodingKey {
                case userID = "user_id"
                case fcmToken = "fcm_token"
                case platform
            }
        }

        try await client.from(SupabaseConfig.Table.deviceTokens)
            .upsert(
                DeviceToken(userID: userID, fcmToken: token, platform: "ios"),
                onConflict: "fcm_token"
            )
            .execute()
    }

    public func removeDeviceToken(_ token: String) async throws {
        try await client.from(SupabaseConfig.Table.deviceTokens)
            .delete()
            .eq("fcm_token", value: token)
            .execute()
    }

    public func updateNotificationSettings(enabled: Bool) async throws {
        let userID = try await client.auth.session.user.id

        struct NotificationSetting: Codable {
            let notificationsEnabled: Bool
            enum CodingKeys: String, CodingKey { case notificationsEnabled = "notifications_enabled" }
        }

        try await client.from(SupabaseConfig.Table.users)
            .update(NotificationSetting(notificationsEnabled: enabled))
            .eq("id", value: userID)
            .execute()
    }
}
