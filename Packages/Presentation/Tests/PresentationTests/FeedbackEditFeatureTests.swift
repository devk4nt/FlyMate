import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct FeedbackEditFeatureTests {
    private static let feedback = Feedback(
        id: UUID(uuidString: "00000000-0000-0000-0001-000000000001")!,
        videoID: UUID(uuidString: "00000000-0000-0000-0002-000000000001")!,
        studyID: UUID(uuidString: "00000000-0000-0000-0002-000000000002")!,
        authorID: UUID(uuidString: "00000000-0000-0000-0002-000000000003")!,
        authorName: "나",
        content: "원래 내용",
        timestampSeconds: 30.0,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    @Test
    func 내용_변경시_최대_길이로_잘림() async {
        let store = TestStore(initialState: FeedbackEditFeature.State(feedback: Self.feedback)) {
            FeedbackEditFeature()
        }

        let tooLong = String(repeating: "가", count: AppConstants.maxFeedbackLength + 10)
        await store.send(.contentChanged(tooLong)) {
            $0.content = String(repeating: "가", count: AppConstants.maxFeedbackLength)
        }
    }

    @Test
    func 내용이_원본과_같으면_저장_불가() async {
        let state = FeedbackEditFeature.State(feedback: Self.feedback)
        #expect(!state.isValid)

        let store = TestStore(initialState: state) {
            FeedbackEditFeature()
        }

        // isValid == false → 클라이언트 호출 없이 무시 (미구현 의존성이므로 호출 시 실패)
        await store.send(.saveTapped)
    }

    @Test
    func 저장_성공시_delegate로_수정된_피드백_전달() async {
        let updated = Feedback(
            id: Self.feedback.id,
            videoID: Self.feedback.videoID,
            studyID: Self.feedback.studyID,
            authorID: Self.feedback.authorID,
            authorName: Self.feedback.authorName,
            content: "수정된 내용",
            timestampSeconds: Self.feedback.timestampSeconds,
            createdAt: Self.feedback.createdAt
        )

        var state = FeedbackEditFeature.State(feedback: Self.feedback)
        state.content = "수정된 내용"

        let store = TestStore(initialState: state) {
            FeedbackEditFeature()
        } withDependencies: {
            $0.feedbackClient.updateFeedback = { _, _ in updated }
        }

        await store.send(.saveTapped) {
            $0.isSubmitting = true
        }

        await store.receive(\.saveResponse.success) {
            $0.isSubmitting = false
        }

        await store.receive(\.delegate.feedbackUpdated)
    }

    @Test
    func 저장_실패시_에러_표시_및_내용_유지() async {
        var state = FeedbackEditFeature.State(feedback: Self.feedback)
        state.content = "수정된 내용"

        let store = TestStore(initialState: state) {
            FeedbackEditFeature()
        } withDependencies: {
            $0.feedbackClient.updateFeedback = { _, _ in throw AppError.network(.noConnection) }
        }

        await store.send(.saveTapped) {
            $0.isSubmitting = true
        }

        await store.receive(\.saveResponse.failure) {
            $0.isSubmitting = false
            $0.error = .network(.noConnection)
        }

        #expect(store.state.content == "수정된 내용")
    }
}
