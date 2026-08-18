import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct FeedbackManagementFeatureTests {
    private let userID = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!

    @Test
    func 초기_상태는_할_일_세그먼트() async {
        let state = FeedbackManagementFeature.State(userID: userID)

        #expect(state.selectedSegment == .pending)
        #expect(state.pending.feedScope == .pendingFeedback)
        #expect(state.pending.currentUserID == userID)
        #expect(state.received.listType == .received)
        #expect(state.given.listType == .given)
        #expect(state.received.userID == userID)
        #expect(state.given.userID == userID)
    }

    @Test
    func 세그먼트_전환() async {
        let dashboard = QuickFeedbackDashboard(
            pointBalance: 2,
            myRequests: [.managementMock],
            availableRequests: [],
            receivedReviews: []
        )
        let store = TestStore(
            initialState: FeedbackManagementFeature.State(userID: userID)
        ) {
            FeedbackManagementFeature()
        } withDependencies: {
            $0.quickFeedbackClient.fetchDashboard = { dashboard }
        }

        await store.send(.segmentChanged(.given)) {
            $0.selectedSegment = .given
        }

        await store.send(.segmentChanged(.received)) {
            $0.selectedSegment = .received
            $0.quickFeedback = .loading
        }
        await store.receive(\.quickFeedbackResponse.success) {
            $0.quickFeedback = .loaded(dashboard)
        }
    }

    @Test
    func 받은_피드백_자식_scope_배선() async {
        let feedbacks = [Feedback.managementMock]

        let store = TestStore(
            initialState: FeedbackManagementFeature.State(userID: userID)
        ) {
            FeedbackManagementFeature()
        } withDependencies: {
            $0.feedbackClient.fetchReceived = { _, _ in feedbacks }
        }

        await store.send(.received(.onAppear)) {
            $0.received.loadingState = .loading
        }

        await store.receive(\.received.feedbacksResponse.success) {
            $0.received.feedbacks.items = feedbacks
            $0.received.feedbacks.cursor = feedbacks.last?.createdAt
            $0.received.feedbacks.hasMore = false
            $0.received.loadingState = .loaded(feedbacks)
        }
    }

    @Test
    func 작성한_피드백_자식_scope_배선() async {
        let feedbacks = [Feedback.managementMock]

        let store = TestStore(
            initialState: FeedbackManagementFeature.State(userID: userID)
        ) {
            FeedbackManagementFeature()
        } withDependencies: {
            $0.feedbackClient.fetchGiven = { _, _ in feedbacks }
        }

        await store.send(.given(.onAppear)) {
            $0.given.loadingState = .loading
        }

        await store.receive(\.given.feedbacksResponse.success) {
            $0.given.feedbacks.items = feedbacks
            $0.given.feedbacks.cursor = feedbacks.last?.createdAt
            $0.given.feedbacks.hasMore = false
            $0.given.loadingState = .loaded(feedbacks)
        }
    }
}

// MARK: - Mock Data

private extension Feedback {
    static let managementMock = Feedback(
        id: UUID(uuidString: "00000000-0000-0000-0003-000000000001")!,
        videoID: UUID(uuidString: "00000000-0000-0000-0003-000000000002")!,
        studyID: UUID(uuidString: "00000000-0000-0000-0003-000000000003")!,
        authorID: UUID(uuidString: "00000000-0000-0000-0003-000000000004")!,
        authorName: "피드백 작성자",
        content: "좋은 답변이었습니다!",
        timestampSeconds: 30.0,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

private extension QuickFeedbackRequest {
    static let managementMock = QuickFeedbackRequest(
        id: UUID(uuidString: "00000000-0000-0000-0004-000000000001")!,
        uploaderID: UUID(uuidString: "00000000-0000-0000-0004-000000000002")!,
        uploaderName: "유나",
        title: "1분 자기소개",
        videoURL: URL(string: "https://example.com/quick.mp4"),
        durationSeconds: 55,
        focusArea: .overall,
        status: .completed,
        feedbackCount: 2,
        targetFeedbackCount: 2,
        expiresAt: Date(timeIntervalSince1970: 1_700_100_000),
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
