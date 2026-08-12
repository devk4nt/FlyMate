import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core
@testable import Presentation

@MainActor
struct FeedbackCommentListFeatureTests {

    private static func makeState() -> FeedbackCommentListFeature.State {
        FeedbackCommentListFeature.State(
            feedback: .mock,
            studyID: Study.mock.id,
            currentUserID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        )
    }

    // MARK: - 목록 로딩

    @Test
    func onAppear_성공시_댓글과_멤버_로드() async {
        let store = TestStore(initialState: Self.makeState()) {
            FeedbackCommentListFeature()
        } withDependencies: {
            $0.feedbackCommentClient.fetchComments = { _ in [.listMock] }
            $0.studyClient.fetchStudy = { _ in .mock }
        }
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.comments = .loading
        }

        await store.receive(\.commentsResponse.success) {
            $0.comments = .loaded([.listMock])
        }
        await store.receive(\.membersResponse.success) {
            $0.members = Study.mock.members
        }
    }

    @Test
    func onAppear_실패시_failed_상태() async {
        let store = TestStore(initialState: Self.makeState()) {
            FeedbackCommentListFeature()
        } withDependencies: {
            $0.feedbackCommentClient.fetchComments = { _ in
                throw AppError.network(.serverError(statusCode: 500))
            }
            $0.studyClient.fetchStudy = { _ in
                throw AppError.network(.serverError(statusCode: 500))
            }
        }
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.comments = .loading
        }

        await store.receive(\.commentsResponse.failure) {
            $0.comments = .failed(.network(.serverError(statusCode: 500)))
        }
    }

    // MARK: - 댓글 작성

    @Test
    func 댓글_작성_성공시_목록_맨앞_삽입_및_입력_초기화() async {
        var state = Self.makeState()
        state.comments = .loaded([])
        state.commentText = "동의합니다!"

        let store = TestStore(initialState: state) {
            FeedbackCommentListFeature()
        } withDependencies: {
            $0.feedbackCommentClient.createComment = { _ in .listMock }
        }

        await store.send(.submitTapped) {
            $0.isSubmitting = true
        }

        await store.receive(\.submitResponse.success) {
            $0.isSubmitting = false
            $0.commentText = ""
            $0.mentionedUserIDs = []
            $0.comments = .loaded([.listMock])
        }
    }

    @Test
    func 댓글_작성_실패시_에러_설정_및_입력_내용_유지() async {
        var state = Self.makeState()
        state.comments = .loaded([])
        state.commentText = "동의합니다!"

        let store = TestStore(initialState: state) {
            FeedbackCommentListFeature()
        } withDependencies: {
            $0.feedbackCommentClient.createComment = { _ in
                throw AppError.network(.noConnection)
            }
        }

        await store.send(.submitTapped) {
            $0.isSubmitting = true
        }

        await store.receive(\.submitResponse.failure) {
            $0.isSubmitting = false
            $0.error = .network(.noConnection)
        }

        #expect(store.state.commentText == "동의합니다!")
    }

    @Test
    func 빈_입력_또는_공백만_있으면_제출_안됨() async {
        var state = Self.makeState()
        state.commentText = "   "

        let store = TestStore(initialState: state) {
            FeedbackCommentListFeature()
        }

        await store.send(.submitTapped)
        #expect(state.isValid == false)
    }

    // MARK: - 글자 수 제한

    @Test
    func 입력_텍스트_maxCommentLength로_잘림() async {
        let store = TestStore(initialState: Self.makeState()) {
            FeedbackCommentListFeature()
        }

        let longText = String(repeating: "가", count: AppConstants.maxCommentLength + 100)
        await store.send(.commentTextChanged(longText)) {
            $0.commentText = String(repeating: "가", count: AppConstants.maxCommentLength)
        }
    }

    // MARK: - 댓글 삭제

    @Test
    func 댓글_삭제_성공시_목록에서_제거() async {
        var state = Self.makeState()
        state.comments = .loaded([.listMock])

        let store = TestStore(initialState: state) {
            FeedbackCommentListFeature()
        } withDependencies: {
            $0.feedbackCommentClient.deleteComment = { _ in }
        }

        await store.send(.deleteCommentTapped(.listMock))

        await store.receive(\.deleteResponse.success) {
            $0.comments = .loaded([])
        }
    }

    @Test
    func 댓글_삭제_실패시_에러_설정_및_목록_유지() async {
        var state = Self.makeState()
        state.comments = .loaded([.listMock])

        let store = TestStore(initialState: state) {
            FeedbackCommentListFeature()
        } withDependencies: {
            $0.feedbackCommentClient.deleteComment = { _ in
                throw AppError.network(.serverError(statusCode: 500))
            }
        }

        await store.send(.deleteCommentTapped(.listMock))

        await store.receive(\.deleteResponse.failure) {
            $0.error = .network(.serverError(statusCode: 500))
        }

        #expect(store.state.comments == .loaded([.listMock]))
    }

    // MARK: - 멘션

    @Test
    func 멘션_서제스천_선택시_텍스트_치환_및_유저ID_동기화() async {
        var state = Self.makeState()
        state.members = Study.mock.members
        state.commentText = "@김"
        state.showMentionSuggestions = true
        state.mentionQuery = "김"

        let store = TestStore(initialState: state) {
            FeedbackCommentListFeature()
        }

        let member = Study.mock.members[0]
        await store.send(.mentionSuggestionTapped(member)) {
            $0.commentText = "@\(member.userName) "
            $0.mentionedUserIDs = [member.userID]
            $0.showMentionSuggestions = false
            $0.mentionQuery = ""
        }
    }
}

// MARK: - Mock Data

private extension FeedbackComment {
    static let listMock = FeedbackComment(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000200")!,
        feedbackID: UUID(uuidString: "00000000-0000-0000-0000-000000000100")!,
        studyID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        authorID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        authorName: "테스트 유저",
        content: "동의합니다!",
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
