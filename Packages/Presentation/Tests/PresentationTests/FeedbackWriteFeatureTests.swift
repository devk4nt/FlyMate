import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct FeedbackWriteFeatureTests {
    private let videoID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    @Test
    func 피드백_작성_성공() async {
        let mockFeedback = Feedback.mock

        let store = TestStore(
            initialState: FeedbackWriteFeature.State(
                videoID: videoID,
                timestampSeconds: 30.0
            )
        ) {
            FeedbackWriteFeature()
        } withDependencies: {
            $0.feedbackClient.createFeedback = { _ in mockFeedback }
            $0.dismiss = DismissEffect { }
        }

        await store.send(.contentChanged("좋은 답변이었습니다!")) {
            $0.content = "좋은 답변이었습니다!"
        }

        await store.send(.submitTapped) {
            $0.isSubmitting = true
        }

        await store.receive(\.submitResponse.success) {
            $0.isSubmitting = false
        }

        await store.receive(\.feedbackSubmitted)
    }

    @Test
    func 피드백_작성_실패() async {
        let store = TestStore(
            initialState: FeedbackWriteFeature.State(
                videoID: videoID,
                timestampSeconds: 30.0
            )
        ) {
            FeedbackWriteFeature()
        } withDependencies: {
            $0.feedbackClient.createFeedback = { _ in
                throw AppError.network(.serverError(statusCode: 500))
            }
        }

        await store.send(.contentChanged("테스트 피드백")) {
            $0.content = "테스트 피드백"
        }

        await store.send(.submitTapped) {
            $0.isSubmitting = true
        }

        await store.receive(\.submitResponse.failure) {
            $0.isSubmitting = false
            $0.error = .network(.serverError(statusCode: 500))
        }
    }

    @Test
    func 빈_내용은_제출_불가() async {
        let store = TestStore(
            initialState: FeedbackWriteFeature.State(
                videoID: videoID,
                timestampSeconds: 30.0
            )
        ) {
            FeedbackWriteFeature()
        }

        // isValid가 false이므로 submitTapped은 상태 변경 없이 무시됨
        await store.send(.submitTapped)
    }

    @Test
    func 글자수_제한_적용() async {
        let store = TestStore(
            initialState: FeedbackWriteFeature.State(
                videoID: videoID,
                timestampSeconds: 30.0
            )
        ) {
            FeedbackWriteFeature()
        }

        let longText = String(repeating: "가", count: 600)
        await store.send(.contentChanged(longText)) {
            $0.content = String(longText.prefix(AppConstants.maxFeedbackLength))
        }
    }
}

// MARK: - Mock Data

extension Feedback {
    static let mock = Feedback(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000100")!,
        videoID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        studyID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        authorID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        authorName: "테스트 유저",
        content: "좋은 답변이었습니다!",
        timestampSeconds: 30.0,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
