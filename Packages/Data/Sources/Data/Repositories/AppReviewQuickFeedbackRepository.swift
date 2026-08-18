import Foundation
import Domain
import Supabase

/// App Store 심사 계정에 빠른 피드백 검수용 콘텐츠를 제공한다.
///
/// 영상 파일까지 포함한 관계형 데이터를 운영 DB에 심는 대신, 심사 계정에만
/// 결정적인 데모 콘텐츠를 합성한다. 신고와 차단은 기존 Repository를 통해
/// 서버에 기록되며, 다음 조회부터 해당 콘텐츠를 숨긴다.
public struct AppReviewQuickFeedbackRepository: QuickFeedbackRepository {
    private let client: SupabaseClient
    private let liveRepository: QuickFeedbackRepositoryImpl
    private let demoStore = AppReviewQuickFeedbackStore()

    public init(client: SupabaseClient) {
        self.client = client
        self.liveRepository = QuickFeedbackRepositoryImpl(client: client)
    }

    public func fetchDashboard() async throws -> QuickFeedbackDashboard {
        guard let reviewerID = try await reviewerID() else {
            return try await liveRepository.fetchDashboard()
        }

        async let blockedUserIDs = fetchBlockedUserIDs(reviewerID: reviewerID)
        async let reportedTargets = fetchReportedTargets(reviewerID: reviewerID)
        let blocked = try await blockedUserIDs
        let reported = try await reportedTargets
        return await demoStore.dashboard(
            reviewerID: reviewerID,
            blockedUserIDs: blocked,
            reportedTargets: reported
        )
    }

    public func upload(
        _ request: UploadQuickFeedbackRequest,
        progress: @Sendable (Double) -> Void
    ) async throws -> QuickFeedbackRequest {
        try await liveRepository.upload(request, progress: progress)
    }

    public func claim(requestID: UUID) async throws -> ClaimedQuickFeedback {
        guard try await reviewerID() != nil,
              let claimed = await demoStore.claim(requestID: requestID) else {
            return try await liveRepository.claim(requestID: requestID)
        }
        return claimed
    }

    public func cancelAssignment(id: UUID) async throws {
        guard try await reviewerID() != nil,
              await demoStore.cancelAssignment(id: id) else {
            try await liveRepository.cancelAssignment(id: id)
            return
        }
    }

    public func submitReview(_ request: CreateQuickFeedbackReviewRequest) async throws -> QuickFeedbackReview {
        guard try await reviewerID() != nil,
              let review = await demoStore.submitReview(request) else {
            return try await liveRepository.submitReview(request)
        }
        return review
    }

    public func closeRequest(id: UUID) async throws {
        guard try await reviewerID() != nil,
              await demoStore.closeRequest(id: id) else {
            try await liveRepository.closeRequest(id: id)
            return
        }
    }

    private func reviewerID() async throws -> UUID? {
        let session = try await client.auth.session
        guard session.user.email?.lowercased() == AppReviewQuickFeedbackStore.reviewerEmail else {
            return nil
        }
        return session.user.id
    }

    private func fetchBlockedUserIDs(reviewerID: UUID) async throws -> Set<UUID> {
        struct BlockedIDDTO: Decodable {
            let blockedID: UUID

            enum CodingKeys: String, CodingKey {
                case blockedID = "blocked_id"
            }
        }

        let rows: [BlockedIDDTO] = try await client.from(SupabaseConfig.Table.blockedUsers)
            .select("blocked_id")
            .eq("blocker_id", value: reviewerID)
            .execute()
            .value
        return Set(rows.map(\.blockedID))
    }

    private func fetchReportedTargets(reviewerID: UUID) async throws -> Set<ReportedTarget> {
        struct ReportTargetDTO: Decodable {
            let targetType: String
            let targetID: UUID

            enum CodingKeys: String, CodingKey {
                case targetType = "target_type"
                case targetID = "target_id"
            }
        }

        let rows: [ReportTargetDTO] = try await client.from(SupabaseConfig.Table.reports)
            .select("target_type,target_id")
            .eq("reporter_id", value: reviewerID)
            .execute()
            .value
        return Set(rows.map { ReportedTarget(type: $0.targetType, id: $0.targetID) })
    }
}

private struct ReportedTarget: Hashable, Sendable {
    let type: String
    let id: UUID
}

private actor AppReviewQuickFeedbackStore {
    static let reviewerEmail = "reviewer@flymate.app"

    private enum ID {
        static let myRequest = make(1)
        static let availableRequest = make(2)
        static let secondAvailableRequest = make(3)
        static let receivedReview = make(4)
        static let secondReceivedReview = make(5)
        static let firstAuthor = make(11)
        static let secondAuthor = make(12)
        static let firstReviewer = make(21)
        static let secondReviewer = make(22)
        static let firstAssignment = make(31)
        static let secondAssignment = make(32)
        static let submittedReview = make(41)

        private static func make(_ suffix: UInt8) -> UUID {
            UUID(uuid: (0xA1, 0x10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, suffix))
        }
    }

    private let createdAt = Date()
    private var claimedRequestIDs = Set<UUID>()
    private var closedRequestIDs = Set<UUID>()

    func dashboard(
        reviewerID: UUID,
        blockedUserIDs: Set<UUID>,
        reportedTargets: Set<ReportedTarget>
    ) -> QuickFeedbackDashboard {
        let ownRequest = QuickFeedbackRequest(
            id: ID.myRequest,
            uploaderID: reviewerID,
            uploaderName: "App Reviewer",
            title: "1분 자기소개 최종 점검",
            videoURL: Self.firstVideoURL,
            durationSeconds: 55,
            focusArea: .overall,
            feedbackRequest: "첫인상과 답변 전달력을 전체적으로 확인해 주세요.",
            status: closedRequestIDs.contains(ID.myRequest) ? .closed : .completed,
            feedbackCount: 2,
            targetFeedbackCount: 2,
            expiresAt: createdAt.addingTimeInterval(20 * 60 * 60),
            createdAt: createdAt.addingTimeInterval(-60 * 60)
        )

        let availableRequests = Self.availableRequests(createdAt: createdAt)
            .filter { !claimedRequestIDs.contains($0.id) }
            .filter { !blockedUserIDs.contains($0.uploaderID) }
            .filter {
                !reportedTargets.contains(
                    ReportedTarget(type: "quick_feedback_request", id: $0.id)
                )
            }
        let receivedReviews = Self.receivedReviews(createdAt: createdAt)
            .filter { !blockedUserIDs.contains($0.reviewerID) }
            .filter {
                !reportedTargets.contains(
                    ReportedTarget(type: "quick_feedback_review", id: $0.id)
                )
            }

        return QuickFeedbackDashboard(
            pointBalance: 5,
            myRequests: [ownRequest],
            availableRequests: availableRequests,
            receivedReviews: receivedReviews
        )
    }

    func claim(requestID: UUID) -> ClaimedQuickFeedback? {
        guard let request = Self.availableRequests(createdAt: createdAt)
            .first(where: { $0.id == requestID }) else { return nil }
        claimedRequestIDs.insert(requestID)
        return ClaimedQuickFeedback(
            assignmentID: requestID == ID.availableRequest ? ID.firstAssignment : ID.secondAssignment,
            request: request
        )
    }

    func cancelAssignment(id: UUID) -> Bool {
        guard let requestID = requestID(for: id) else { return false }
        claimedRequestIDs.remove(requestID)
        return true
    }

    func submitReview(_ request: CreateQuickFeedbackReviewRequest) -> QuickFeedbackReview? {
        guard let requestID = requestID(for: request.assignmentID) else { return nil }
        claimedRequestIDs.insert(requestID)
        return QuickFeedbackReview(
            id: ID.submittedReview,
            requestID: requestID,
            reviewerID: ID.firstReviewer,
            reviewerName: "App Reviewer",
            positiveText: request.positiveText,
            improvementText: request.improvementText,
            focusArea: request.focusArea,
            createdAt: Date()
        )
    }

    func closeRequest(id: UUID) -> Bool {
        guard id == ID.myRequest else { return false }
        closedRequestIDs.insert(id)
        return true
    }

    private func requestID(for assignmentID: UUID) -> UUID? {
        switch assignmentID {
        case ID.firstAssignment: ID.availableRequest
        case ID.secondAssignment: ID.secondAvailableRequest
        default: nil
        }
    }

    private static func availableRequests(createdAt: Date) -> [QuickFeedbackRequest] {
        [
            QuickFeedbackRequest(
                id: ID.availableRequest,
                uploaderID: ID.firstAuthor,
                uploaderName: "김하늘",
                title: "항공사 지원동기 1분 답변",
                videoURL: firstVideoURL,
                durationSeconds: 52,
                focusArea: .answer,
                feedbackRequest: "지원 동기가 구체적으로 들리는지 봐주세요.",
                status: .open,
                feedbackCount: 0,
                targetFeedbackCount: 2,
                expiresAt: createdAt.addingTimeInterval(30 * 60 * 60),
                createdAt: createdAt.addingTimeInterval(-2 * 60 * 60)
            ),
            QuickFeedbackRequest(
                id: ID.secondAvailableRequest,
                uploaderID: ID.secondAuthor,
                uploaderName: "박서연",
                title: "영상면접 첫인사 연습",
                videoURL: secondVideoURL,
                durationSeconds: 38,
                focusArea: .expression,
                feedbackRequest: "시선과 미소가 자연스러운지 알려주세요.",
                status: .open,
                feedbackCount: 1,
                targetFeedbackCount: 2,
                expiresAt: createdAt.addingTimeInterval(18 * 60 * 60),
                createdAt: createdAt.addingTimeInterval(-4 * 60 * 60)
            )
        ]
    }

    private static func receivedReviews(createdAt: Date) -> [QuickFeedbackReview] {
        [
            QuickFeedbackReview(
                id: ID.receivedReview,
                requestID: ID.myRequest,
                reviewerID: ID.firstReviewer,
                reviewerName: "김하늘",
                positiveText: "첫 문장의 미소와 목소리가 밝아 편안하고 자신감 있는 인상을 받았어요.",
                improvementText: "지원 동기를 말하는 중간 부분의 속도를 조금 늦추면 핵심 경험이 더 잘 전달될 것 같아요.",
                focusArea: .voice,
                createdAt: createdAt.addingTimeInterval(-35 * 60)
            ),
            QuickFeedbackReview(
                id: ID.secondReceivedReview,
                requestID: ID.myRequest,
                reviewerID: ID.secondReviewer,
                reviewerName: "박서연",
                positiveText: "답변의 시작과 마무리가 명확하고 카메라를 보는 시선도 전반적으로 자연스러웠어요.",
                improvementText: "마지막 문장에서 끝까지 렌즈를 바라보며 미소를 유지하면 더 안정적인 인상이 될 것 같아요.",
                focusArea: .expression,
                createdAt: createdAt.addingTimeInterval(-20 * 60)
            )
        ]
    }

    private static let firstVideoURL = URL(string: "https://media.w3.org/2010/05/sintel/trailer.mp4")
    private static let secondVideoURL = URL(string: "https://download.blender.org/durian/trailer/sintel_trailer-720p.mp4")
}
