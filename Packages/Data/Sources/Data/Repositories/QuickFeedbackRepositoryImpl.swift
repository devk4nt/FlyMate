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

        struct WalletDTO: Decodable { let balance: Int }
        let wallet: WalletDTO = try await client.from(SupabaseConfig.Table.quickFeedbackWallets)
            .select("balance")
            .eq("user_id", value: userID)
            .single()
            .execute()
            .value

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

        struct AssignmentRequestID: Decodable {
            let requestID: UUID
            enum CodingKeys: String, CodingKey { case requestID = "request_id" }
        }
        let assignments: [AssignmentRequestID] = try await client
            .from(SupabaseConfig.Table.quickFeedbackAssignments)
            .select("request_id")
            .eq("reviewer_id", value: userID)
            .execute()
            .value
        let assignedRequestIDs = Set(assignments.map(\.requestID))

        let availableDTOs: [QuickFeedbackRequestDTO] = try await client
            .from(SupabaseConfig.Table.quickFeedbackRequests)
            .select()
            .eq("status", value: QuickFeedbackRequestStatus.open.rawValue)
            .neq("uploader_id", value: userID)
            .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
            .order("created_at", ascending: true)
            .limit(AppConstants.defaultPageSize)
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
            pointBalance: wallet.balance,
            myRequests: myRequests,
            availableRequests: availableDTOs
                .filter { !assignedRequestIDs.contains($0.id) }
                .map { DTOMapper.toDomain($0) },
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
        progress(0.8)

        struct Params: Encodable {
            let p_id: UUID
            let p_title: String
            let p_video_path: String
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
        if message.contains("insufficient_feedback_points") { return .business(.insufficientFeedbackPoints) }
        if message.contains("active_quick_feedback_exists") { return .business(.activeQuickFeedbackExists) }
        if message.contains("quick_feedback_expired") { return .business(.quickFeedbackExpired) }
        if message.contains("quick_feedback_unavailable") { return .business(.quickFeedbackUnavailable) }
        return error as? AppError ?? .unexpected(error.localizedDescription)
    }
}
