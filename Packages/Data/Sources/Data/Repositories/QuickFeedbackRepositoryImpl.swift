import Foundation
import Core
import Domain
import Supabase

public struct QuickFeedbackRepositoryImpl: QuickFeedbackRepository {
    private let client: SupabaseClient
    private let storageService: StorageService

    public init(client: SupabaseClient) {
        self.client = client
        self.storageService = StorageService(client: client)
    }

    public func fetchDashboard() async throws -> QuickFeedbackDashboard {
        try await client.rpc(SupabaseConfig.RPC.reconcileQuickFeedbackRequests).execute()
        let userID = try await client.auth.session.user.id

        let myRequestDTOs: [QuickFeedbackRequestDTO] = try await client
            .from(SupabaseConfig.Table.quickFeedbackRequests)
            .select()
            .eq("uploader_id", value: userID)
            .order("created_at", ascending: false)
            .execute()
            .value
        let signedURLs = try await storageService.signedVideoURLs(
            paths: myRequestDTOs.map(\.videoPath)
        )
        let myRequests = myRequestDTOs.map {
            DTOMapper.toDomain($0, videoURL: signedURLs[$0.videoPath])
        }

        // 풀 목록은 프라이버시 강화 RPC로 조회 — 신원·영상·썸네일·요청상세 제외,
        // viewer_count<1(=미claim)만 반환하므로 배정 제외 필터도 서버에서 처리됨.
        let availableDTOs: [AvailableQuickFeedbackRequestDTO] = try await client
            .rpc(SupabaseConfig.RPC.listAvailableQuickFeedbackRequests)
            .execute()
            .value

        let reviewDTOs: [QuickFeedbackReviewDTO]
        if !myRequestDTOs.isEmpty {
            reviewDTOs = try await client.from(SupabaseConfig.Table.quickFeedbackReviews)
                .select()
                .in("request_id", values: myRequestDTOs.map(\.id))
                .order("created_at", ascending: false)
                .execute()
                .value
        } else {
            reviewDTOs = []
        }

        return QuickFeedbackDashboard(
            myRequests: myRequests,
            availableRequests: availableDTOs.map(DTOMapper.toDomain),
            receivedReviews: reviewDTOs.map(DTOMapper.toDomain)
        )
    }

    public func upload(
        _ request: UploadQuickFeedbackRequest,
        progress: @Sendable (Double) -> Void
    ) async throws -> QuickFeedbackRequest {
        let userID = try await client.auth.session.user.id
        let requestID = UUID()
        progress(0.1)
        let videoPath = try await storageService.uploadQuickFeedbackVideo(
            data: request.videoData,
            userID: userID,
            requestID: requestID
        )
        var thumbnailURL: URL?
        if let thumbnailData = request.thumbnailData {
            thumbnailURL = try? await storageService.uploadQuickFeedbackThumbnail(
                data: thumbnailData,
                userID: userID,
                requestID: requestID
            )
        }
        progress(0.8)

        struct Params: Encodable {
            let p_id: UUID
            let p_title: String
            let p_video_path: String
            let p_thumbnail_url: String?
            let p_duration_seconds: Double
            let p_focus_area: String
            let p_feedback_request: String?
        }

        do {
            let dto: QuickFeedbackRequestDTO = try await client.rpc(
                SupabaseConfig.RPC.createQuickFeedbackRequest,
                params: Params(
                    p_id: requestID,
                    p_title: request.title,
                    p_video_path: videoPath,
                    p_thumbnail_url: thumbnailURL?.absoluteString,
                    p_duration_seconds: request.durationSeconds,
                    p_focus_area: request.focusArea.rawValue,
                    p_feedback_request: request.feedbackRequest
                )
            )
            .single()
            .execute()
            .value
            progress(1)
            return DTOMapper.toDomain(dto)
        } catch {
            await storageService.deleteQuickFeedbackVideo(path: videoPath)
            await storageService.deleteQuickFeedbackThumbnail(userID: userID, requestID: requestID)
            throw mapError(error)
        }
    }

    public func claim(requestID: UUID) async throws -> ClaimedQuickFeedback {
        do {
            let dto: ClaimedQuickFeedbackDTO = try await client.rpc(
                SupabaseConfig.RPC.claimQuickFeedbackRequest,
                params: ["p_request_id": requestID.uuidString]
            )
            .single()
            .execute()
            .value
            let videoURL = try await storageService.signedVideoURL(path: dto.videoPath)
            return ClaimedQuickFeedback(
                assignmentID: dto.assignmentID,
                request: DTOMapper.toDomain(
                    dto.requestDTO(),
                    videoURL: videoURL
                )
            )
        } catch {
            throw mapError(error)
        }
    }

    public func cancelAssignment(id: UUID) async throws {
        do {
            try await client.rpc(
                SupabaseConfig.RPC.cancelQuickFeedbackAssignment,
                params: ["p_assignment_id": id.uuidString]
            )
            .execute()
        } catch {
            throw mapError(error)
        }
    }

    public func submitReview(_ request: CreateQuickFeedbackReviewRequest) async throws -> QuickFeedbackReview {
        struct Params: Encodable {
            let p_assignment_id: UUID
            let p_positive_text: String
            let p_improvement_text: String
            let p_focus_area: String
        }
        do {
            let dto: QuickFeedbackReviewDTO = try await client.rpc(
                SupabaseConfig.RPC.submitQuickFeedbackReview,
                params: Params(
                    p_assignment_id: request.assignmentID,
                    p_positive_text: request.positiveText,
                    p_improvement_text: request.improvementText,
                    p_focus_area: request.focusArea.rawValue
                )
            )
            .single()
            .execute()
            .value
            return DTOMapper.toDomain(dto)
        } catch {
            throw mapError(error)
        }
    }

    public func closeRequest(id: UUID) async throws {
        do {
            try await client.rpc(
                SupabaseConfig.RPC.closeQuickFeedbackRequest,
                params: ["p_request_id": id.uuidString]
            )
            .execute()
        } catch {
            throw mapError(error)
        }
    }

    private func mapError(_ error: Error) -> AppError {
        let message = error.localizedDescription.lowercased()
        if message.contains("active_quick_feedback_exists") { return .business(.activeQuickFeedbackExists) }
        if message.contains("quick_feedback_expired") { return .business(.quickFeedbackExpired) }
        if message.contains("quick_feedback_unavailable") { return .business(.quickFeedbackUnavailable) }
        return error as? AppError ?? .unexpected(error.localizedDescription)
    }
}
