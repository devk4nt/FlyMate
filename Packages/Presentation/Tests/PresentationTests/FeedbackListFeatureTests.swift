import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct FeedbackListFeatureTests {
    private let userID = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!

    // MARK: - 초기 로드

    @Test
    func 받은_피드백_로딩_성공_풀페이지면_hasMore_유지() async {
        let firstPage = (1...AppConstants.defaultPageSize).map { Feedback.mock(index: $0) }

        let store = TestStore(
            initialState: FeedbackListFeature.State(userID: userID, listType: .received)
        ) {
            FeedbackListFeature()
        } withDependencies: {
            $0.feedbackClient.fetchReceived = { _, _ in firstPage }
        }

        await store.send(.onAppear) {
            $0.loadingState = .loading
        }

        await store.receive(\.feedbacksResponse.success) {
            $0.feedbacks.items = firstPage
            $0.feedbacks.cursor = firstPage.last?.createdAt
            $0.feedbacks.hasMore = true
            $0.loadingState = .loaded(firstPage)
        }
    }

    @Test
    func 작성한_피드백은_fetchGiven으로_로딩() async {
        let feedbacks = [Feedback.mock(index: 1)]

        let store = TestStore(
            initialState: FeedbackListFeature.State(userID: userID, listType: .given)
        ) {
            FeedbackListFeature()
        } withDependencies: {
            $0.feedbackClient.fetchGiven = { _, _ in feedbacks }
        }

        await store.send(.onAppear) {
            $0.loadingState = .loading
        }

        // 한 페이지 미만이면 hasMore = false
        await store.receive(\.feedbacksResponse.success) {
            $0.feedbacks.items = feedbacks
            $0.feedbacks.cursor = feedbacks.last?.createdAt
            $0.feedbacks.hasMore = false
            $0.loadingState = .loaded(feedbacks)
        }
    }

    @Test
    func 피드백_로딩_실패() async {
        let store = TestStore(
            initialState: FeedbackListFeature.State(userID: userID, listType: .received)
        ) {
            FeedbackListFeature()
        } withDependencies: {
            $0.feedbackClient.fetchReceived = { _, _ in throw AppError.network(.noConnection) }
        }

        await store.send(.onAppear) {
            $0.loadingState = .loading
        }

        await store.receive(\.feedbacksResponse.failure) {
            $0.loadingState = .failed(.network(.noConnection))
        }
    }

    @Test
    func 이미_로딩된_상태에서_onAppear_무시() async {
        var state = FeedbackListFeature.State(userID: userID, listType: .received)
        state.loadingState = .loaded([])

        let store = TestStore(initialState: state) {
            FeedbackListFeature()
        }

        // idle이 아니면 재요청하지 않는다 (클라이언트 미구현이므로 호출 시 테스트 실패)
        await store.send(.onAppear)
    }

    // MARK: - 재시도 (refresh)

    @Test
    func 실패_후_새로고침시_페이지네이션_초기화_후_재로딩() async {
        var state = FeedbackListFeature.State(userID: userID, listType: .received)
        state.loadingState = .failed(.network(.timeout))
        state.feedbacks.items = [Feedback.mock(index: 1)]
        state.feedbacks.cursor = Feedback.mock(index: 1).createdAt
        state.feedbacks.hasMore = false

        let feedbacks = [Feedback.mock(index: 2)]

        let store = TestStore(initialState: state) {
            FeedbackListFeature()
        } withDependencies: {
            $0.feedbackClient.fetchReceived = { _, _ in feedbacks }
        }

        await store.send(.refresh) {
            $0.loadingState = .loading
            $0.feedbacks = PaginatedState<Feedback>()
        }

        await store.receive(\.feedbacksResponse.success) {
            $0.feedbacks.items = feedbacks
            $0.feedbacks.cursor = feedbacks.last?.createdAt
            $0.feedbacks.hasMore = false
            $0.loadingState = .loaded(feedbacks)
        }
    }

    // MARK: - 페이지네이션

    @Test
    func loadMore_성공시_다음_페이지_추가_및_커서_전달() async {
        let firstPage = (1...AppConstants.defaultPageSize).map { Feedback.mock(index: $0) }
        var state = FeedbackListFeature.State(userID: userID, listType: .received)
        state.loadingState = .loaded(firstPage)
        state.feedbacks.items = firstPage
        state.feedbacks.cursor = firstPage.last?.createdAt
        state.feedbacks.hasMore = true

        let nextPage = [Feedback.mock(index: AppConstants.defaultPageSize + 1)]
        let capturedCursor = LockIsolated<Date?>(nil)

        let store = TestStore(initialState: state) {
            FeedbackListFeature()
        } withDependencies: {
            $0.feedbackClient.fetchReceived = { _, cursor in
                capturedCursor.setValue(cursor)
                return nextPage
            }
        }

        await store.send(.loadMore) {
            $0.feedbacks.isLoadingMore = true
        }

        await store.receive(\.loadMoreResponse.success) {
            $0.feedbacks.isLoadingMore = false
            $0.feedbacks.items = firstPage + nextPage
            $0.feedbacks.cursor = nextPage.last?.createdAt
            $0.feedbacks.hasMore = false
            $0.loadingState = .loaded(firstPage + nextPage)
        }

        #expect(capturedCursor.value == firstPage.last?.createdAt)
    }

    @Test
    func hasMore_없으면_loadMore_무시() async {
        var state = FeedbackListFeature.State(userID: userID, listType: .received)
        state.loadingState = .loaded([Feedback.mock(index: 1)])
        state.feedbacks.items = [Feedback.mock(index: 1)]
        state.feedbacks.hasMore = false

        let store = TestStore(initialState: state) {
            FeedbackListFeature()
        }

        await store.send(.loadMore)
    }

    @Test
    func 로딩중_중복_loadMore_방어() async {
        var state = FeedbackListFeature.State(userID: userID, listType: .received)
        state.feedbacks.hasMore = true
        state.feedbacks.isLoadingMore = true

        let store = TestStore(initialState: state) {
            FeedbackListFeature()
        }

        await store.send(.loadMore)
    }

    @Test
    func loadMore_실패시_isLoadingMore만_해제() async {
        var state = FeedbackListFeature.State(userID: userID, listType: .received)
        state.feedbacks.items = [Feedback.mock(index: 1)]
        state.feedbacks.cursor = Feedback.mock(index: 1).createdAt
        state.feedbacks.hasMore = true
        state.loadingState = .loaded([Feedback.mock(index: 1)])

        let store = TestStore(initialState: state) {
            FeedbackListFeature()
        } withDependencies: {
            $0.feedbackClient.fetchReceived = { _, _ in throw AppError.network(.timeout) }
        }

        await store.send(.loadMore) {
            $0.feedbacks.isLoadingMore = true
        }

        // 기존 목록과 hasMore는 유지되어 재시도 가능
        await store.receive(\.loadMoreResponse.failure) {
            $0.feedbacks.isLoadingMore = false
        }
    }

    // MARK: - 셀 탭

    @Test
    func 셀_탭은_부모가_처리하므로_상태_변경_없음() async {
        let store = TestStore(
            initialState: FeedbackListFeature.State(userID: userID, listType: .received)
        ) {
            FeedbackListFeature()
        }

        await store.send(.feedbackTapped(Feedback.mock(index: 1)))
    }

    // MARK: - 사용자 차단

    @Test
    func 사용자_차단_확인시_해당_작성자_피드백_제거_및_토스트() async {
        let feedbacks = [Feedback.mock(index: 1), Feedback.mock(index: 2)]
        var state = FeedbackListFeature.State(userID: userID, listType: .received)
        state.feedbacks.items = feedbacks
        state.loadingState = .loaded(feedbacks)

        let blocked = LockIsolated<(UUID, String)?>(nil)
        let store = TestStore(initialState: state) {
            FeedbackListFeature()
        } withDependencies: {
            $0.blockClient.blockUser = { userID, userName in blocked.setValue((userID, userName)) }
        }

        let target = feedbacks[0]
        await store.send(.blockUserTapped(target)) {
            $0.blockAlert = AlertState {
                TextState("\(target.authorName)님을 차단할까요?")
            } actions: {
                ButtonState(role: .destructive, action: .confirmBlock(userID: target.authorID, userName: target.authorName)) {
                    TextState("차단하기")
                }
                ButtonState(role: .cancel) {
                    TextState("취소")
                }
            } message: {
                TextState("차단한 사용자의 영상과 피드백이 더 이상 보이지 않아요. 설정 > 차단한 사용자에서 해제할 수 있어요.")
            }
        }

        await store.send(.blockAlert(.presented(.confirmBlock(userID: target.authorID, userName: target.authorName)))) {
            $0.blockAlert = nil
        }

        // 두 피드백 모두 같은 작성자 — 전부 제거된다
        await store.receive(\.blockResponse.success) {
            $0.feedbacks.items = []
            $0.loadingState = .loaded([])
            $0.toastMessage = "사용자를 차단했습니다"
            $0.showToast = true
        }

        #expect(blocked.value?.0 == target.authorID)
        #expect(blocked.value?.1 == target.authorName)
    }

    @Test
    func 사용자_차단_실패시_목록_유지_및_에러_토스트() async {
        let feedbacks = [Feedback.mock(index: 1)]
        var state = FeedbackListFeature.State(userID: userID, listType: .received)
        state.feedbacks.items = feedbacks
        state.loadingState = .loaded(feedbacks)
        state.blockAlert = AlertState {
            TextState("\(feedbacks[0].authorName)님을 차단할까요?")
        } actions: {
            ButtonState(role: .destructive, action: .confirmBlock(userID: feedbacks[0].authorID, userName: feedbacks[0].authorName)) {
                TextState("차단하기")
            }
            ButtonState(role: .cancel) {
                TextState("취소")
            }
        }

        let store = TestStore(initialState: state) {
            FeedbackListFeature()
        } withDependencies: {
            $0.blockClient.blockUser = { _, _ in
                throw AppError.network(.noConnection)
            }
        }

        await store.send(.blockAlert(.presented(.confirmBlock(userID: feedbacks[0].authorID, userName: feedbacks[0].authorName)))) {
            $0.blockAlert = nil
        }

        await store.receive(\.blockResponse.failure) {
            $0.toastMessage = "차단에 실패했습니다. 다시 시도해 주세요."
            $0.showToast = true
        }

        #expect(store.state.feedbacks.items == feedbacks)
    }
}

// MARK: - Mock Data

private extension Feedback {
    static func mock(index: Int) -> Feedback {
        Feedback(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0001-%012d", index))!,
            videoID: UUID(uuidString: "00000000-0000-0000-0002-000000000001")!,
            studyID: UUID(uuidString: "00000000-0000-0000-0002-000000000002")!,
            authorID: UUID(uuidString: "00000000-0000-0000-0002-000000000003")!,
            authorName: "피드백 작성자",
            content: "피드백 내용 \(index)",
            timestampSeconds: 30.0,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000 + TimeInterval(index))
        )
    }
}
