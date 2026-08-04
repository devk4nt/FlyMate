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
