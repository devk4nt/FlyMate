import Foundation
import ComposableArchitecture
import Domain

public struct QuickFeedbackClient: Sendable {
    public var fetchDashboard: @Sendable () async throws -> QuickFeedbackDashboard
    public var upload: @Sendable (
        UploadQuickFeedbackRequest,
        @Sendable (Double) -> Void
    ) async throws -> QuickFeedbackRequest
    public var claim: @Sendable (UUID) async throws -> ClaimedQuickFeedback
    public var cancelAssignment: @Sendable (UUID) async throws -> Void
    public var submitReview: @Sendable (CreateQuickFeedbackReviewRequest) async throws -> QuickFeedbackReview
    public var closeRequest: @Sendable (UUID) async throws -> Void

    public init(
        fetchDashboard: @escaping @Sendable () async throws -> QuickFeedbackDashboard,
        upload: @escaping @Sendable (
            UploadQuickFeedbackRequest,
            @Sendable (Double) -> Void
        ) async throws -> QuickFeedbackRequest,
        claim: @escaping @Sendable (UUID) async throws -> ClaimedQuickFeedback,
        cancelAssignment: @escaping @Sendable (UUID) async throws -> Void,
        submitReview: @escaping @Sendable (CreateQuickFeedbackReviewRequest) async throws -> QuickFeedbackReview,
        closeRequest: @escaping @Sendable (UUID) async throws -> Void
    ) {
        self.fetchDashboard = fetchDashboard
        self.upload = upload
        self.claim = claim
        self.cancelAssignment = cancelAssignment
        self.submitReview = submitReview
        self.closeRequest = closeRequest
    }
}

extension QuickFeedbackClient: TestDependencyKey {
    public static let testValue = QuickFeedbackClient(
        fetchDashboard: unimplemented("\(Self.self).fetchDashboard"),
        upload: { _, _ in throw QuickFeedbackUnimplementedError() },
        claim: unimplemented("\(Self.self).claim"),
        cancelAssignment: unimplemented("\(Self.self).cancelAssignment"),
        submitReview: unimplemented("\(Self.self).submitReview"),
        closeRequest: unimplemented("\(Self.self).closeRequest")
    )
}

private struct QuickFeedbackUnimplementedError: Error {}

extension DependencyValues {
    public var quickFeedbackClient: QuickFeedbackClient {
        get { self[QuickFeedbackClient.self] }
        set { self[QuickFeedbackClient.self] = newValue }
    }
}
