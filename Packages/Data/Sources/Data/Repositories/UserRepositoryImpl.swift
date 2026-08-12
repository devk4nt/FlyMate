import Foundation
import Core
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

        do {
            let dto: UserDTO = try await client.from(SupabaseConfig.Table.users)
                .update(UpdateUser(name: request.name, profileImageURL: profileImageURL))
                .eq("id", value: userID)
                .select()
                .single()
                .execute()
                .value
            return DTOMapper.toDomain(dto)
        } catch {
            // users_name_lower_key unique index violation → 닉네임 중복
            let message = error.localizedDescription
            if message.contains("users_name_lower_key") || message.contains("23505") {
                throw AppError.business(.nameAlreadyTaken)
            }
            throw error
        }
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

    public func fetchMyActivityStats() async throws -> MyActivityStats {
        let response: MyActivityStatsResponse = try await client.rpc("get_my_activity_stats")
            .single()
            .execute()
            .value

        return MyActivityStats(
            studiesCount: response.studiesCount,
            videosUploadedCount: response.videosUploadedCount,
            feedbackReceivedCount: response.feedbackReceivedCount,
            feedbackGivenCount: response.feedbackGivenCount
        )
    }
}

private struct MyActivityStatsResponse: Codable, Sendable {
    let studiesCount: Int
    let videosUploadedCount: Int
    let feedbackReceivedCount: Int
    let feedbackGivenCount: Int

    enum CodingKeys: String, CodingKey {
        case studiesCount = "studies_count"
        case videosUploadedCount = "videos_uploaded_count"
        case feedbackReceivedCount = "feedback_received_count"
        case feedbackGivenCount = "feedback_given_count"
    }
}
