import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core
@testable import Presentation

@MainActor
struct VideoFeedFeatureTests {

    // MARK: - onAppear (피드백 대기 큐)

    @Test
    func onAppear시_피드백_대기_큐만_로드하고_자동재생하지_않음() async {
        let videos = [Video.feedMock(1), Video.feedMock(2)]
        let userID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!

        let store = TestStore(
            initialState: VideoFeedFeature.State(scope: .pendingFeedback, currentUserID: userID)
        ) {
            VideoFeedFeature()
        } withDependencies: {
            $0.studyClient.fetchMyStudies = { [.mock] }
            $0.videoClient.fetchPendingFeedbackVideos = { studyIDs, requesterID in
                #expect(studyIDs == [Study.mock.id])
                #expect(requesterID == userID)
                return videos
            }
            $0.feedbackClient.fetchFeedbacks = { _ in [] }
            $0.feedbackClient.observeFeedbacks = { _ in .finished }
            $0.feedbackCommentClient.fetchLatestComments = { _ in [:] }
            $0.studyClient.fetchStudy = { _ in .mock }
        }
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.loadingState = .loading
        }

        await store.receive(\.videosResponse.success) {
            $0.loadingState = .loaded(videos)
            $0.currentVideoID = videos[0].id
            // 대기 큐는 단일 조회 — 페이지네이션 없음
            $0.hasMore = false
        }

        #expect(store.state.pages[id: videos[0].id]?.player.isPlaying == false)
    }

    @Test
    func 피드_카드를_선택하면_플레이어를_열고_재생함() async {
        let videos = [Video.feedMock(1), Video.feedMock(2)]
        var state = VideoFeedFeature.State(scope: .pendingFeedback)
        state.loadingState = .loaded(videos)
        state.pages = IdentifiedArray(
            uniqueElements: videos.map { VideoDetailFeature.State(video: $0) }
        )
        state.currentVideoID = videos[0].id

        let store = TestStore(initialState: state) {
            VideoFeedFeature()
        } withDependencies: {
            $0.feedbackClient.fetchFeedbacks = { _ in [] }
            $0.feedbackClient.observeFeedbacks = { _ in .finished }
            $0.feedbackCommentClient.fetchLatestComments = { _ in [:] }
            $0.studyClient.fetchStudy = { _ in .mock }
        }
        store.exhaustivity = .off

        await store.send(.videoTapped(videos[1].id)) {
            $0.presentedVideoID = videos[1].id
            $0.currentVideoID = videos[1].id
        }

        await store.receive(\.pages[id: videos[1].id].play) {
            $0.pages[id: videos[1].id]?.player.isPlaying = true
        }

        await store.send(.playerDismissed) {
            $0.presentedVideoID = nil
        }

        await store.receive(\.pages[id: videos[1].id].onDisappear) {
            $0.pages[id: videos[1].id]?.player.isPlaying = false
        }
    }

    @Test
    func 스터디_스코프_진입시_선택한_영상부터_시작() async {
        let videos = [Video.feedMock(1), Video.feedMock(2), Video.feedMock(3)]
        let studyID = Video.feedMock(1).studyID

        let store = TestStore(
            initialState: VideoFeedFeature.State(
                scope: .study(studyID),
                initialVideoID: videos[1].id
            )
        ) {
            VideoFeedFeature()
        } withDependencies: {
            $0.videoClient.fetchFeedVideos = { studyIDs, _ in
                #expect(studyIDs == [studyID])
                return videos
            }
            $0.feedbackClient.fetchFeedbacks = { _ in [] }
            $0.feedbackClient.observeFeedbacks = { _ in .finished }
            $0.feedbackCommentClient.fetchLatestComments = { _ in [:] }
            $0.studyClient.fetchStudy = { _ in .mock }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)

        await store.receive(\.videosResponse.success) {
            $0.currentVideoID = videos[1].id
            $0.initialVideoID = nil
        }
    }

    @Test
    func onAppear시_로드_실패() async {
        let userID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let store = TestStore(
            initialState: VideoFeedFeature.State(scope: .pendingFeedback, currentUserID: userID)
        ) {
            VideoFeedFeature()
        } withDependencies: {
            $0.studyClient.fetchMyStudies = {
                throw AppError.network(.serverError(statusCode: 500))
            }
        }

        await store.send(.onAppear) {
            $0.loadingState = .loading
        }

        await store.receive(\.videosResponse.failure) {
            $0.loadingState = .failed(.network(.serverError(statusCode: 500)))
        }
    }

    // MARK: - 페이지 전환

    @Test
    func 스와이프로_페이지_전환시_이전_페이지_정지_및_새_페이지_재생() async {
        let videos = [Video.feedMock(1), Video.feedMock(2)]
        var state = VideoFeedFeature.State(scope: .study(videos[0].studyID))
        state.loadingState = .loaded(videos)
        state.pages = IdentifiedArray(
            uniqueElements: videos.map { VideoDetailFeature.State(video: $0) }
        )
        state.currentVideoID = videos[0].id
        state.pages[id: videos[0].id]?.player.isPlaying = true
        state.hasMore = false

        let store = TestStore(initialState: state) {
            VideoFeedFeature()
        } withDependencies: {
            $0.feedbackClient.fetchFeedbacks = { _ in [] }
            $0.feedbackClient.observeFeedbacks = { _ in .finished }
            $0.feedbackCommentClient.fetchLatestComments = { _ in [:] }
            $0.studyClient.fetchStudy = { _ in .mock }
        }
        store.exhaustivity = .off

        await store.send(.currentVideoChanged(videos[1].id)) {
            $0.currentVideoID = videos[1].id
        }

        await store.receive(\.pages[id: videos[0].id].onDisappear) {
            $0.pages[id: videos[0].id]?.player.isPlaying = false
        }

        await store.receive(\.pages[id: videos[1].id].play) {
            $0.pages[id: videos[1].id]?.player.isPlaying = true
        }
    }

    // MARK: - 페이지네이션

    @Test
    func 끝에_가까워지면_다음_페이지_로드() async {
        let videos = (1...4).map { Video.feedMock($0) }
        let nextVideos = [Video.feedMock(5)]

        var state = VideoFeedFeature.State(scope: .study(videos[0].studyID))
        state.loadingState = .loaded(videos)
        state.pages = IdentifiedArray(
            uniqueElements: videos.map { VideoDetailFeature.State(video: $0) }
        )
        state.currentVideoID = videos[0].id
        state.hasMore = true
        state.cursor = videos.last?.createdAt

        let store = TestStore(initialState: state) {
            VideoFeedFeature()
        } withDependencies: {
            $0.videoClient.fetchFeedVideos = { _, cursor in
                #expect(cursor == videos.last?.createdAt)
                return nextVideos
            }
            $0.feedbackClient.fetchFeedbacks = { _ in [] }
            $0.feedbackClient.observeFeedbacks = { _ in .finished }
            $0.feedbackCommentClient.fetchLatestComments = { _ in [:] }
            $0.studyClient.fetchStudy = { _ in .mock }
        }
        store.exhaustivity = .off

        // 4개 중 2번째(index 1) 진입 → count - 3 임계값 도달
        await store.send(.currentVideoChanged(videos[1].id))

        await store.receive(\.loadMore) {
            $0.isLoadingMore = true
        }

        await store.receive(\.loadMoreResponse.success) {
            $0.isLoadingMore = false
            $0.pages.append(VideoDetailFeature.State(video: nextVideos[0]))
            $0.cursor = nextVideos.last?.createdAt
            $0.hasMore = false
        }
    }

    @Test
    func 중복_영상은_페이지에_추가하지_않음() async {
        let videos = [Video.feedMock(1), Video.feedMock(2)]

        var state = VideoFeedFeature.State(scope: .study(videos[0].studyID))
        state.loadingState = .loaded(videos)
        state.pages = IdentifiedArray(
            uniqueElements: videos.map { VideoDetailFeature.State(video: $0) }
        )
        state.hasMore = true

        let store = TestStore(initialState: state) {
            VideoFeedFeature()
        } withDependencies: {
            // 이미 있는 영상(1)과 새 영상(3)이 섞여 응답
            $0.videoClient.fetchFeedVideos = { _, _ in [Video.feedMock(1), Video.feedMock(3)] }
        }

        await store.send(.loadMore) {
            $0.isLoadingMore = true
        }

        await store.receive(\.loadMoreResponse.success) {
            $0.isLoadingMore = false
            $0.pages.append(VideoDetailFeature.State(video: .feedMock(3)))
            $0.cursor = Video.feedMock(3).createdAt
            $0.hasMore = false
        }
    }
}

// MARK: - Mock Data

private extension Video {
    static func feedMock(_ suffix: Int) -> Video {
        Video(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 100 + suffix))!,
            studyID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            uploaderID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            uploaderName: "김테스트",
            title: "연습 영상 \(suffix)",
            videoURL: URL(string: "https://example.com/video\(suffix).mp4")!,
            durationSeconds: 120,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000 - TimeInterval(suffix) * 3_600)
        )
    }
}
