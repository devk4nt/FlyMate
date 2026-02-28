import Testing
import ComposableArchitecture
import Domain
import Core
@testable import Presentation

@MainActor
struct CommentInputFeatureTests {

    // MARK: - 댓글 모드 제출

    @Test
    func 댓글_모드_제출_성공시_delegate_feedbackCreated_전달() async {
        let videoID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let mockFeedback = Feedback.commentInputMock

        var capturedRequest: CreateFeedbackRequest?
        let store = TestStore(
            initialState: CommentInputFeature.State(videoID: videoID)
        ) {
            CommentInputFeature()
        } withDependencies: {
            $0.feedbackClient.createFeedback = { request in
                capturedRequest = request
                return mockFeedback
            }
        }

        await store.send(.textChanged("좋은 답변이었습니다!")) {
            $0.text = "좋은 답변이었습니다!"
        }

        await store.send(.submitTapped(timestampSeconds: 30.0)) {
            $0.isSubmitting = true
        }

        await store.receive(\.feedbackSubmitResponse.success) {
            $0.isSubmitting = false
            $0.isFocused = false
            $0.text = ""
            $0.mentionedUserIDs = []
        }

        await store.receive(\.delegate.feedbackCreated)

        #expect(capturedRequest?.videoID == videoID)
        #expect(capturedRequest?.content == "좋은 답변이었습니다!")
        #expect(capturedRequest?.timestampSeconds == 30.0)
    }

    @Test
    func 댓글_모드_제출_실패시_에러_설정() async {
        let videoID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let store = TestStore(
            initialState: CommentInputFeature.State(videoID: videoID)
        ) {
            CommentInputFeature()
        } withDependencies: {
            $0.feedbackClient.createFeedback = { _ in
                throw AppError.network(.serverError(statusCode: 500))
            }
        }

        await store.send(.textChanged("테스트")) {
            $0.text = "테스트"
        }

        await store.send(.submitTapped(timestampSeconds: 0)) {
            $0.isSubmitting = true
        }

        await store.receive(\.feedbackSubmitResponse.failure) {
            $0.isSubmitting = false
            $0.error = .network(.serverError(statusCode: 500))
        }
    }

    // MARK: - 답글 모드 진입/해제

    @Test
    func 답글_모드_진입시_replyContext_설정_및_텍스트_자동삽입() async {
        let videoID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let feedbackID = UUID(uuidString: "00000000-0000-0000-0000-000000000100")!

        let store = TestStore(
            initialState: CommentInputFeature.State(videoID: videoID)
        ) {
            CommentInputFeature()
        }

        await store.send(.enterReplyMode(feedbackID: feedbackID, authorName: "김테스트")) {
            $0.replyContext = CommentInputFeature.ReplyContext(
                feedbackID: feedbackID,
                authorName: "김테스트"
            )
            $0.text = "@김테스트 "
            $0.isFocused = true
        }
    }

    @Test
    func 답글_모드_해제시_상태_초기화() async {
        let videoID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let feedbackID = UUID(uuidString: "00000000-0000-0000-0000-000000000100")!

        var state = CommentInputFeature.State(videoID: videoID)
        state.replyContext = CommentInputFeature.ReplyContext(
            feedbackID: feedbackID,
            authorName: "김테스트"
        )
        state.text = "@김테스트 답글 내용"

        let store = TestStore(initialState: state) {
            CommentInputFeature()
        }

        await store.send(.exitReplyMode) {
            $0.replyContext = nil
            $0.text = ""
            $0.isFocused = false
            $0.mentionedUserIDs = []
            $0.showMentionSuggestions = false
            $0.mentionQuery = ""
        }
    }

    // MARK: - 답글 모드 제출

    @Test
    func 답글_모드_제출_성공시_delegate_commentCreated_전달() async {
        let videoID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let feedbackID = UUID(uuidString: "00000000-0000-0000-0000-000000000100")!
        let mockComment = FeedbackComment.commentInputMock

        var capturedRequest: CreateFeedbackCommentRequest?

        var state = CommentInputFeature.State(videoID: videoID)
        state.replyContext = CommentInputFeature.ReplyContext(
            feedbackID: feedbackID,
            authorName: "테스트 유저"
        )
        state.text = "@테스트 유저 답글 내용"

        let store = TestStore(initialState: state) {
            CommentInputFeature()
        } withDependencies: {
            $0.feedbackCommentClient.createComment = { request in
                capturedRequest = request
                return mockComment
            }
        }

        await store.send(.submitTapped(timestampSeconds: 30.0)) {
            $0.isSubmitting = true
        }

        await store.receive(\.commentSubmitResponse.success) {
            $0.isSubmitting = false
            $0.isFocused = false
            $0.text = ""
            $0.mentionedUserIDs = []
            $0.replyContext = nil
            $0.showMentionSuggestions = false
            $0.mentionQuery = ""
        }

        await store.receive(\.delegate.commentCreated)

        #expect(capturedRequest?.feedbackID == feedbackID)
        #expect(capturedRequest?.content == "@테스트 유저 답글 내용")
    }

    // MARK: - 멘션 자동완성

    @Test
    func 멘션_트리거_감지시_서제스천_표시() async {
        let videoID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let store = TestStore(
            initialState: CommentInputFeature.State(videoID: videoID)
        ) {
            CommentInputFeature()
        }

        await store.send(.textChanged("@김")) {
            $0.text = "@김"
        }

        await store.receive(\.mentionTriggerDetected) {
            $0.mentionQuery = "김"
            $0.showMentionSuggestions = true
        }
    }

    @Test
    func 멘션_서제스천_선택시_텍스트_치환() async {
        let videoID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let member = StudyMember(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            userID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            userName: "김테스트",
            role: .member,
            joinedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        var state = CommentInputFeature.State(videoID: videoID)
        state.text = "@김"
        state.members = [member]
        state.showMentionSuggestions = true
        state.mentionQuery = "김"

        let store = TestStore(initialState: state) {
            CommentInputFeature()
        }

        await store.send(.mentionSuggestionTapped(member)) {
            $0.text = "@김테스트 "
            $0.mentionedUserIDs = [member.userID]
            $0.showMentionSuggestions = false
            $0.mentionQuery = ""
        }
    }

    @Test
    func 전체_멘션_선택시_모든_멤버_포함() async {
        let videoID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let member1 = StudyMember(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            userID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            userName: "김테스트",
            role: .owner,
            joinedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let member2 = StudyMember(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
            userID: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
            userName: "이멤버",
            role: .member,
            joinedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        var state = CommentInputFeature.State(videoID: videoID)
        state.text = "@"
        state.members = [member1, member2]
        state.showMentionSuggestions = true

        let store = TestStore(initialState: state) {
            CommentInputFeature()
        }

        await store.send(.mentionAllTapped) {
            $0.text = "@전체 "
            $0.mentionedUserIDs = [member1.userID, member2.userID]
            $0.showMentionSuggestions = false
            $0.mentionQuery = ""
        }
    }

    // MARK: - 텍스트 길이 제한

    @Test
    func 댓글_모드_텍스트_길이_maxFeedbackLength로_제한() async {
        let videoID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let longText = String(repeating: "가", count: 600)

        let store = TestStore(
            initialState: CommentInputFeature.State(videoID: videoID)
        ) {
            CommentInputFeature()
        }

        await store.send(.textChanged(longText)) {
            $0.text = String(repeating: "가", count: AppConstants.maxFeedbackLength)
        }
    }

    @Test
    func 답글_모드_텍스트_길이_maxCommentLength로_제한() async {
        let videoID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let feedbackID = UUID(uuidString: "00000000-0000-0000-0000-000000000100")!
        let longText = String(repeating: "가", count: 400)

        var state = CommentInputFeature.State(videoID: videoID)
        state.replyContext = CommentInputFeature.ReplyContext(
            feedbackID: feedbackID,
            authorName: "김테스트"
        )

        let store = TestStore(initialState: state) {
            CommentInputFeature()
        }

        await store.send(.textChanged(longText)) {
            $0.text = String(repeating: "가", count: AppConstants.maxCommentLength)
        }
    }

    // MARK: - 유효성 검증

    @Test
    func 빈_텍스트일때_isValid_false() {
        let state = CommentInputFeature.State(
            videoID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )
        #expect(state.isValid == false)
    }

    @Test
    func 공백만_있을때_isValid_false() {
        var state = CommentInputFeature.State(
            videoID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )
        state.text = "   "
        #expect(state.isValid == false)
    }

    @Test
    func 정상_텍스트일때_isValid_true() {
        var state = CommentInputFeature.State(
            videoID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )
        state.text = "좋은 피드백!"
        #expect(state.isValid == true)
    }

    // MARK: - cancelTapped

    @Test
    func 답글_모드에서_cancelTapped시_댓글_모드로_복귀() async {
        let videoID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let feedbackID = UUID(uuidString: "00000000-0000-0000-0000-000000000100")!

        var state = CommentInputFeature.State(videoID: videoID)
        state.replyContext = CommentInputFeature.ReplyContext(
            feedbackID: feedbackID,
            authorName: "김테스트"
        )
        state.text = "@김테스트 "

        let store = TestStore(initialState: state) {
            CommentInputFeature()
        }

        await store.send(.cancelTapped)

        await store.receive(\.exitReplyMode) {
            $0.replyContext = nil
            $0.text = ""
            $0.isFocused = false
            $0.mentionedUserIDs = []
            $0.showMentionSuggestions = false
            $0.mentionQuery = ""
        }
    }

    @Test
    func 댓글_모드에서_cancelTapped시_텍스트_초기화() async {
        let videoID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        var state = CommentInputFeature.State(videoID: videoID)
        state.text = "작성 중인 내용"

        let store = TestStore(initialState: state) {
            CommentInputFeature()
        }

        await store.send(.cancelTapped) {
            $0.text = ""
            $0.isFocused = false
            $0.mentionedUserIDs = []
            $0.showMentionSuggestions = false
            $0.mentionQuery = ""
        }
    }
}

// MARK: - Mock Data

private extension Feedback {
    static let commentInputMock = Feedback(
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

private extension FeedbackComment {
    static let commentInputMock = FeedbackComment(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000200")!,
        feedbackID: UUID(uuidString: "00000000-0000-0000-0000-000000000100")!,
        studyID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        authorID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        authorName: "테스트 유저",
        content: "@테스트 유저 답글 내용",
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
