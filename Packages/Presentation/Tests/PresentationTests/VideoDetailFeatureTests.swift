import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core
@testable import Presentation

@MainActor
struct VideoDetailFeatureTests {

    // MARK: - onAppear

    @Test
    func onAppear시_피드백_로드_성공_및_최신_답글_로드() async {
        let feedback = Feedback.videoDetailMock()
        let comment = FeedbackComment.videoDetailMock

        let store = TestStore(
            initialState: VideoDetailFeature.State(video: .videoDetailMock)
        ) {
            VideoDetailFeature()
        } withDependencies: {
            $0.feedbackClient.fetchFeedbacks = { _ in [feedback] }
            $0.feedbackClient.observeFeedbacks = { _ in .finished }
            $0.feedbackCommentClient.fetchLatestComments = { _ in [feedback.id: comment] }
            $0.studyClient.fetchStudy = { _ in .mock }
        }
        // onAppear는 fetch/observe/멤버 로드 3개 Effect를 merge하므로 수신 순서가 비결정적 — 핵심 액션만 검증
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.feedbacks = .loading
            $0.player.duration = Video.videoDetailMock.durationSeconds
        }

        await store.receive(\.feedbacksResponse.success) {
            $0.feedbacks = .loaded([feedback])
        }

        await store.receive(\.latestCommentsResponse.success) {
            $0.latestComments = [feedback.id: comment]
        }
    }

    @Test
    func onAppear시_피드백_로드_실패() async {
        let store = TestStore(
            initialState: VideoDetailFeature.State(video: .videoDetailMock)
        ) {
            VideoDetailFeature()
        } withDependencies: {
            $0.feedbackClient.fetchFeedbacks = { _ in
                throw AppError.network(.serverError(statusCode: 500))
            }
            $0.feedbackClient.observeFeedbacks = { _ in .finished }
            $0.studyClient.fetchStudy = { _ in .mock }
        }
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.feedbacks = .loading
            $0.player.duration = Video.videoDetailMock.durationSeconds
        }

        await store.receive(\.feedbacksResponse.failure) {
            $0.feedbacks = .failed(.network(.serverError(statusCode: 500)))
        }
    }

    @Test
    func onAppear시_멤버_로드되면_commentInput에_전달() async {
        let store = TestStore(
            initialState: VideoDetailFeature.State(video: .videoDetailMock)
        ) {
            VideoDetailFeature()
        } withDependencies: {
            $0.feedbackClient.fetchFeedbacks = { _ in [] }
            $0.feedbackClient.observeFeedbacks = { _ in .finished }
            $0.feedbackCommentClient.fetchLatestComments = { _ in [:] }
            $0.studyClient.fetchStudy = { _ in .mock }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)

        await store.receive(\.membersResponse.success) {
            $0.commentInput.members = Study.mock.members
        }
    }

    // MARK: - 실시간 스트림

    @Test
    func 실시간_스트림으로_피드백_업데이트() async {
        let initial = Feedback.videoDetailMock()
        let added = Feedback.videoDetailMock(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        )

        let store = TestStore(
            initialState: VideoDetailFeature.State(video: .videoDetailMock)
        ) {
            VideoDetailFeature()
        } withDependencies: {
            $0.feedbackClient.fetchFeedbacks = { _ in [initial] }
            $0.feedbackClient.observeFeedbacks = { _ in
                AsyncStream { continuation in
                    continuation.yield([initial, added])
                    continuation.finish()
                }
            }
            $0.feedbackCommentClient.fetchLatestComments = { _ in [:] }
            $0.studyClient.fetchStudy = { _ in .mock }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)

        await store.receive(\.feedbacksUpdated) {
            $0.feedbacks = .loaded([initial, added])
        }
    }

    @Test
    func onDisappear시_실시간_스트림_구독_취소() async {
        let (stream, continuation) = AsyncStream<[Feedback]>.makeStream()

        let store = TestStore(
            initialState: VideoDetailFeature.State(video: .videoDetailMock)
        ) {
            VideoDetailFeature()
        } withDependencies: {
            $0.feedbackClient.fetchFeedbacks = { _ in [] }
            $0.feedbackClient.observeFeedbacks = { _ in stream }
            $0.feedbackCommentClient.fetchLatestComments = { _ in [:] }
            $0.studyClient.fetchStudy = { _ in .mock }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)

        continuation.yield([.videoDetailMock()])
        await store.receive(\.feedbacksUpdated)

        await store.send(.play) {
            $0.player.isPlaying = true
        }

        await store.send(.onDisappear) {
            $0.player.isPlaying = false
        }

        // 스트림은 아직 열려 있으므로, 구독이 취소되지 않았다면 finish가 타임아웃으로 실패한다
        await store.finish(timeout: .seconds(1))
    }

    // MARK: - 피드백 시트

    @Test
    func 재생중_피드백_시트_열면_해당_초수에서_정지() async {
        var initialState = VideoDetailFeature.State(video: .videoDetailMock)
        initialState.player.isPlaying = true
        initialState.player.currentTime = 42

        let store = TestStore(initialState: initialState) {
            VideoDetailFeature()
        }

        await store.send(.feedbackSheetTapped) {
            $0.showFeedbackSheet = true
            $0.player.isPlaying = false
            // currentTime은 그대로 유지 — 피드백이 이 초수에 달린다
            $0.player.currentTime = 42
        }
    }

    // MARK: - 피드백 탭 → seek

    @Test
    func 피드백_탭시_해당_타임스탬프로_seek() async {
        let feedback = Feedback.videoDetailMock()

        let store = TestStore(
            initialState: VideoDetailFeature.State(video: .videoDetailMock)
        ) {
            VideoDetailFeature()
        }

        await store.send(.feedbackTapped(feedback))

        await store.receive(\.seek) {
            $0.player.isSeeking = true
            $0.player.currentTime = feedback.timestampSeconds
        }
    }

    // MARK: - 딥링크 (초기 focusedFeedbackID)

    @Test
    func 초기_focusedFeedbackID가_있으면_로드_후_seek_및_포커스_해제() async {
        let feedback = Feedback.videoDetailMock()

        let store = TestStore(
            initialState: VideoDetailFeature.State(
                video: .videoDetailMock,
                focusedFeedbackID: feedback.id
            )
        ) {
            VideoDetailFeature()
        } withDependencies: {
            $0.feedbackClient.fetchFeedbacks = { _ in [feedback] }
            $0.feedbackClient.observeFeedbacks = { _ in .finished }
            $0.feedbackCommentClient.fetchLatestComments = { _ in [:] }
            $0.studyClient.fetchStudy = { _ in .mock }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)

        await store.receive(\.feedbacksResponse.success) {
            $0.feedbacks = .loaded([feedback])
        }

        await store.receive(\.seek) {
            $0.player.isSeeking = true
            $0.player.currentTime = feedback.timestampSeconds
        }

        // Feature가 클록 주입 없이 Task.sleep(2초)을 직접 사용하므로 실제로 대기해야 함
        await store.receive(\.clearFocusedFeedback, timeout: .seconds(3)) {
            $0.focusedFeedbackID = nil
        }
    }

    // MARK: - 댓글 목록 시트

    @Test
    func 댓글_목록_탭시_시트_presentation() async {
        let feedback = Feedback.videoDetailMock()
        let userID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!

        let store = TestStore(
            initialState: VideoDetailFeature.State(
                video: .videoDetailMock,
                currentUserID: userID
            )
        ) {
            VideoDetailFeature()
        }

        await store.send(.commentListTapped(feedback)) {
            $0.feedbackCommentList = FeedbackCommentListFeature.State(
                feedback: feedback,
                studyID: Video.videoDetailMock.studyID,
                currentUserID: userID
            )
        }
    }

    // MARK: - 답글 토글

    @Test
    func 답글_최초_펼침시_로드_후_재탭시_접힘() async {
        let feedback = Feedback.videoDetailMock()
        let comment = FeedbackComment.videoDetailMock

        let store = TestStore(
            initialState: VideoDetailFeature.State(video: .videoDetailMock)
        ) {
            VideoDetailFeature()
        } withDependencies: {
            $0.feedbackCommentClient.fetchComments = { _ in [comment] }
        }

        await store.send(.toggleRepliesTapped(feedback)) {
            $0.expandedFeedbackIDs = [feedback.id]
            $0.repliesByFeedback = [feedback.id: .loading]
        }

        await store.receive(\.repliesResponse) {
            $0.repliesByFeedback = [feedback.id: .loaded([comment])]
        }

        await store.send(.toggleRepliesTapped(feedback)) {
            $0.expandedFeedbackIDs = []
        }
    }

    @Test
    func 답글_로드_실패_후_다시_펼치면_재시도한다() async {
        let feedback = Feedback.videoDetailMock()
        let comment = FeedbackComment.videoDetailMock

        var state = VideoDetailFeature.State(video: .videoDetailMock)
        state.repliesByFeedback = [feedback.id: .failed(.network(.noConnection))]

        let store = TestStore(initialState: state) {
            VideoDetailFeature()
        } withDependencies: {
            $0.feedbackCommentClient.fetchComments = { _ in [comment] }
        }

        await store.send(.toggleRepliesTapped(feedback)) {
            $0.expandedFeedbackIDs = [feedback.id]
            $0.repliesByFeedback = [feedback.id: .loading]
        }

        await store.receive(\.repliesResponse) {
            $0.repliesByFeedback = [feedback.id: .loaded([comment])]
        }
    }

    // MARK: - 답글 삭제

    @Test
    func 답글_삭제_성공시_목록_제거_및_카운트_감소() async {
        let feedback = Feedback.videoDetailMock(commentCount: 1)
        let comment = FeedbackComment.videoDetailMock

        var state = VideoDetailFeature.State(video: .videoDetailMock)
        state.feedbacks = .loaded([feedback])
        state.expandedFeedbackIDs = [feedback.id]
        state.repliesByFeedback = [feedback.id: .loaded([comment])]

        let deletedID = LockIsolated<UUID?>(nil)
        let store = TestStore(initialState: state) {
            VideoDetailFeature()
        } withDependencies: {
            $0.feedbackCommentClient.deleteComment = { id in
                deletedID.setValue(id)
            }
        }

        await store.send(.deleteReplyTapped(comment))

        await store.receive(\.deleteReplyResponse) {
            $0.repliesByFeedback = [feedback.id: .loaded([])]
            $0.feedbacks = .loaded([Feedback.videoDetailMock(commentCount: 0)])
        }

        #expect(deletedID.value == comment.id)
    }

    @Test
    func 답글_삭제_실패시_상태_유지() async {
        let feedback = Feedback.videoDetailMock(commentCount: 1)
        let comment = FeedbackComment.videoDetailMock

        var state = VideoDetailFeature.State(video: .videoDetailMock)
        state.feedbacks = .loaded([feedback])
        state.repliesByFeedback = [feedback.id: .loaded([comment])]

        let store = TestStore(initialState: state) {
            VideoDetailFeature()
        } withDependencies: {
            $0.feedbackCommentClient.deleteComment = { _ in
                throw AppError.network(.serverError(statusCode: 500))
            }
        }

        await store.send(.deleteReplyTapped(comment))

        // 실패 시 답글 목록과 commentCount 모두 변경 없음
        await store.receive(\.deleteReplyResponse)
    }

    // MARK: - 사용자 신고 / 차단

    @Test
    func 사용자_신고_탭시_report_시트_표시() async {
        let feedback = Feedback.videoDetailMock()
        var state = VideoDetailFeature.State(video: .videoDetailMock)
        state.feedbacks = .loaded([feedback])

        let store = TestStore(initialState: state) {
            VideoDetailFeature()
        } withDependencies: {
            // ReportFeature.onAppear가 중복 신고를 조회한다
            $0.reportClient.checkAlreadyReported = { _, _ in false }
        }

        await store.send(.reportUserTapped(authorID: feedback.authorID)) {
            $0.report = ReportFeature.State(targetType: .user, targetID: feedback.authorID)
        }
    }

    @Test
    func 사용자_차단_확인시_피드백_답글_최신댓글에서_모두_제거() async {
        let blockedAuthorID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let otherAuthorID = UUID(uuidString: "00000000-0000-0000-0000-000000000030")!

        let blockedFeedback = Feedback.videoDetailMock()
        let otherFeedback = Feedback(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            videoID: blockedFeedback.videoID,
            studyID: blockedFeedback.studyID,
            authorID: otherAuthorID,
            authorName: "다른 유저",
            content: "목소리가 좋아요",
            timestampSeconds: 10.0,
            createdAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let blockedComment = FeedbackComment.videoDetailMock
        let otherComment = FeedbackComment(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
            feedbackID: otherFeedback.id,
            studyID: blockedFeedback.studyID,
            authorID: otherAuthorID,
            authorName: "다른 유저",
            content: "저도 동의해요",
            createdAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        var state = VideoDetailFeature.State(video: .videoDetailMock)
        state.feedbacks = .loaded([blockedFeedback, otherFeedback])
        state.repliesByFeedback = [otherFeedback.id: .loaded([blockedComment, otherComment])]
        state.latestComments = [otherFeedback.id: blockedComment]

        let blocked = LockIsolated<(UUID, String)?>(nil)
        let store = TestStore(initialState: state) {
            VideoDetailFeature()
        } withDependencies: {
            $0.blockClient.blockUser = { userID, userName in blocked.setValue((userID, userName)) }
        }

        await store.send(.blockUserTapped(authorID: blockedAuthorID, authorName: "김테스트")) {
            $0.blockAlert = AlertState {
                TextState("김테스트님을 차단할까요?")
            } actions: {
                ButtonState(role: .destructive, action: .confirmBlock(userID: blockedAuthorID, userName: "김테스트")) {
                    TextState("차단하기")
                }
                ButtonState(role: .cancel) {
                    TextState("취소")
                }
            } message: {
                TextState("차단한 사용자의 영상과 피드백이 더 이상 보이지 않아요. 설정 > 차단한 사용자에서 해제할 수 있어요.")
            }
        }

        await store.send(.blockAlert(.presented(.confirmBlock(userID: blockedAuthorID, userName: "김테스트")))) {
            $0.blockAlert = nil
        }

        await store.receive(\.blockResponse.success) {
            $0.feedbacks = .loaded([otherFeedback])
            $0.repliesByFeedback = [otherFeedback.id: .loaded([otherComment])]
            $0.latestComments = [:]
            $0.showToast = true
            $0.toastMessage = "사용자를 차단했습니다"
            $0.toastType = .success
        }

        #expect(blocked.value?.0 == blockedAuthorID)
        #expect(blocked.value?.1 == "김테스트")
    }

    // MARK: - 피드백 수정

    @Test
    func 수정_탭시_수정_시트_표시() async {
        let feedback = Feedback.videoDetailMock()
        var state = VideoDetailFeature.State(video: .videoDetailMock)
        state.feedbacks = .loaded([feedback])

        let store = TestStore(initialState: state) {
            VideoDetailFeature()
        }

        await store.send(.editFeedbackTapped(feedback)) {
            $0.edit = FeedbackEditFeature.State(feedback: feedback)
        }
    }

    @Test
    func 수정_완료시_피드백_목록_갱신_및_토스트() async {
        let feedback = Feedback.videoDetailMock()
        let updated = Feedback(
            id: feedback.id,
            videoID: feedback.videoID,
            studyID: feedback.studyID,
            authorID: feedback.authorID,
            authorName: feedback.authorName,
            content: "수정된 내용",
            timestampSeconds: feedback.timestampSeconds,
            createdAt: feedback.createdAt
        )
        var state = VideoDetailFeature.State(video: .videoDetailMock)
        state.feedbacks = .loaded([feedback])
        state.edit = FeedbackEditFeature.State(feedback: feedback)

        let store = TestStore(initialState: state) {
            VideoDetailFeature()
        }

        await store.send(.edit(.presented(.delegate(.feedbackUpdated(updated))))) {
            $0.edit = nil
            $0.feedbacks = .loaded([updated])
            $0.showToast = true
            $0.toastMessage = "댓글이 수정되었습니다"
            $0.toastType = .success
        }
    }
}

// MARK: - Mock Data

private extension Video {
    static let videoDetailMock = Video(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        studyID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        uploaderID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        uploaderName: "김테스트",
        title: "기내 방송 연습 영상",
        videoURL: URL(string: "https://example.com/video.mp4")!,
        durationSeconds: 120,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

private extension Feedback {
    static func videoDetailMock(
        id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000100")!,
        commentCount: Int = 0
    ) -> Feedback {
        Feedback(
            id: id,
            videoID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            studyID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            authorID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            authorName: "김테스트",
            content: "시선 처리가 좋았습니다",
            timestampSeconds: 30.0,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            commentCount: commentCount
        )
    }
}

private extension FeedbackComment {
    static let videoDetailMock = FeedbackComment(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000200")!,
        feedbackID: UUID(uuidString: "00000000-0000-0000-0000-000000000100")!,
        studyID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        authorID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        authorName: "김테스트",
        content: "동의합니다",
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
