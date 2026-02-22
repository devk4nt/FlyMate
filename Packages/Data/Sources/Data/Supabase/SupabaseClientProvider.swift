import Foundation
import Supabase

public final class SupabaseClientProvider: Sendable {
    public static let shared = SupabaseClientProvider()

    public let client: SupabaseClient

    private init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: .init(
                auth: .init(autoRefreshToken: true, emitLocalSessionAsInitialSession: true)
            )
        )
    }
}
