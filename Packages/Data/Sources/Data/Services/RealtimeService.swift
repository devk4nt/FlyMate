import Foundation
import Supabase
import Realtime
import Domain
import Core

/// Supabase Realtime 채널 래퍼.
/// 테이블 변경 사항을 AsyncStream으로 변환하여 제공한다.
public struct RealtimeService: Sendable {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    /// 특정 영상의 피드백 변경을 실시간 구독한다.
    func observeFeedbacks(videoID: UUID) -> AsyncStream<[Feedback]> {
        AsyncStream { continuation in
            let task = Task {
                let channel = client.realtimeV2.channel("feedbacks:\(videoID)")

                let changes = channel.postgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: SupabaseConfig.Table.feedbacks,
                    filter: "video_id=eq.\(videoID)"
                )

                await channel.subscribe()

                for await _ in changes {
                    // 변경 발생 시 전체 목록을 다시 조회하여 일관성 보장
                    do {
                        let dtos: [FeedbackDTO] = try await client.from(SupabaseConfig.Table.feedbacks)
                            .select()
                            .eq("video_id", value: videoID)
                            .order("created_at")
                            .execute()
                            .value
                        let feedbacks = dtos.map(DTOMapper.toDomain)
                        continuation.yield(feedbacks)
                    } catch {
                        // 조회 실패 시 스트림 계속 유지
                        FMLogger.error(
                            "Failed to fetch feedbacks on realtime update: \(error)",
                            category: .feedback
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
