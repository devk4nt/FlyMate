import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct VideoFeedFeature {
    /// 피드 범위
    /// - pendingFeedback: 내 스터디원 영상 중 아직 피드백하지 않은 것 (오래된 순, 할 일 큐)
    /// - study: 특정 스터디의 전체 영상 (최신순)
    public enum FeedScope: Equatable, Sendable {
        case pendingFeedback
        case study(UUID)
    }

    @ObservableState
    public struct State: Equatable {
        // `scope`는 Store.scope(state:action:) 메서드와 이름이 충돌하므로 feedScope로 명명
        public var feedScope: FeedScope
        public var currentUserID: UUID?
        public var initialVideoID: UUID?
        public var focusedFeedbackID: UUID?

        public var loadingState: LoadingState<[Video]> = .idle
        public var pages: IdentifiedArrayOf<VideoDetailFeature.State> = []
        public var currentVideoID: UUID?
        public var presentedVideoID: UUID?
        public var cursor: Date?
        public var hasMore = true
        public var isLoadingMore = false

        public init(
            scope: FeedScope,
            initialVideoID: UUID? = nil,
            focusedFeedbackID: UUID? = nil,
            currentUserID: UUID? = nil
        ) {
            self.feedScope = scope
            self.initialVideoID = initialVideoID
            self.focusedFeedbackID = focusedFeedbackID
            self.currentUserID = currentUserID
        }
    }

    public enum Action {
        case onAppear
        case viewDisappeared
        case backTapped
        case retryTapped
        case videosResponse(Result<[Video], AppError>)
        case videoTapped(UUID)
        case playerDismissed
        case currentVideoChanged(UUID?)
        case loadMore
        case loadMoreResponse(Result<[Video], AppError>)
        case pages(IdentifiedActionOf<VideoDetailFeature>)
    }

    /// 끝에서 N번째 페이지 진입 시 다음 페이지를 미리 로드
    private static let loadMoreThreshold = 3

    /// 시트 닫힘이 pop 이전에 한 프레임 렌더되도록 확보하는 지연
    private static let sheetCloseRenderDelay: Duration = .milliseconds(100)

    @Dependency(\.videoClient) private var videoClient
    @Dependency(\.studyClient) private var studyClient
    @Dependency(\.continuousClock) private var clock
    @Dependency(\.dismiss) private var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // 스터디 피드와 이미 열린 플레이어만 재활성화한다.
                // 메인 피드의 카드 목록에서는 영상이 보이지 않으므로 자동 재생하지 않는다.
                if case .loaded = state.loadingState {
                    switch state.feedScope {
                    case .pendingFeedback:
                        return state.presentedVideoID == nil
                            ? .none
                            : activate(state.currentVideoID)
                    case .study:
                        return activate(state.currentVideoID)
                    }
                }
                guard case .idle = state.loadingState else { return .none }
                state.loadingState = .loading
                return fetchVideos(scope: state.feedScope, userID: state.currentUserID, cursor: nil) {
                    .videosResponse($0)
                }

            case .viewDisappeared:
                guard let currentID = state.currentVideoID else { return .none }
                return .send(.pages(.element(id: currentID, action: .onDisappear)))

            case .backTapped:
                // 시트가 열린 채 pop되면 스택 요소가 제거된 뒤 뷰가 캐시된 상태(시트 열림)를
                // 읽어 시트가 뒤늦게 사라진다 — 시트를 먼저 닫아 한 프레임 렌더한 뒤 pop한다
                if let currentID = state.currentVideoID {
                    state.pages[id: currentID]?.showFeedbackSheet = false
                }
                let clock = clock
                let dismiss = dismiss
                return .run { _ in
                    try? await clock.sleep(for: Self.sheetCloseRenderDelay)
                    await dismiss()
                }

            case .retryTapped:
                // 로드된 콘텐츠는 유지 — pull-to-refresh 시 스켈레톤 대신 .refreshable 스피너가 로딩 표시
                // (에러 후 재시도는 .failed → .loading으로 스켈레톤 유지)
                if state.loadingState.value == nil { state.loadingState = .loading }
                return fetchVideos(scope: state.feedScope, userID: state.currentUserID, cursor: nil) {
                    .videosResponse($0)
                }

            case .videosResponse(.success(let videos)):
                state.loadingState = .loaded(videos)
                state.pages = IdentifiedArray(
                    uniqueElements: videos.map { makePageState($0, state: state) }
                )
                state.cursor = videos.last?.createdAt
                // 피드백 대기 큐는 단일 조회 (pendingFeedbackFetchLimit) — 페이지네이션 없음
                if case .pendingFeedback = state.feedScope {
                    state.hasMore = false
                } else {
                    state.hasMore = videos.count >= AppConstants.defaultPageSize
                }
                let startID = state.presentedVideoID.flatMap { state.pages[id: $0]?.video.id }
                    ?? state.initialVideoID.flatMap { state.pages[id: $0]?.video.id }
                    ?? videos.first?.id
                state.currentVideoID = startID
                if let presentedVideoID = state.presentedVideoID,
                   state.pages[id: presentedVideoID] == nil {
                    state.presentedVideoID = nil
                }
                // 초기 진입 포커스는 1회성 — 새로고침 시 재적용 방지
                state.initialVideoID = nil
                state.focusedFeedbackID = nil
                switch state.feedScope {
                case .pendingFeedback:
                    return state.presentedVideoID == nil ? .none : activate(startID)
                case .study:
                    return activate(startID)
                }

            case .videosResponse(.failure(let error)):
                state.loadingState = .failed(error)
                return .none

            case .videoTapped(let videoID):
                guard state.pages[id: videoID] != nil else { return .none }
                let previousID = state.currentVideoID
                state.presentedVideoID = videoID
                state.currentVideoID = videoID

                var effects: [Effect<Action>] = []
                if let previousID, previousID != videoID {
                    effects.append(.send(.pages(.element(id: previousID, action: .onDisappear))))
                }
                effects.append(activate(videoID))
                return .merge(effects)

            case .playerDismissed:
                state.presentedVideoID = nil
                guard let currentID = state.currentVideoID else { return .none }
                // 시트는 pop과 같은 트랜잭션에서 동기적으로 닫는다 — onDisappear effect에
                // 맡기면 다음 틱에 처리되어 시트가 pop 애니메이션 뒤에 늦게 사라진다
                state.pages[id: currentID]?.showFeedbackSheet = false
                return .send(.pages(.element(id: currentID, action: .onDisappear)))

            case .currentVideoChanged(let newID):
                let previousID = state.currentVideoID
                guard newID != previousID else { return .none }
                state.currentVideoID = newID
                var effects: [Effect<Action>] = []
                if let previousID {
                    effects.append(.send(.pages(.element(id: previousID, action: .onDisappear))))
                }
                effects.append(activate(newID))
                // 끝에 가까워지면 다음 페이지 로드
                if let newID,
                   let index = state.pages.index(id: newID),
                   index >= state.pages.count - Self.loadMoreThreshold {
                    effects.append(.send(.loadMore))
                }
                return .merge(effects)

            case .loadMore:
                guard state.hasMore, !state.isLoadingMore else { return .none }
                state.isLoadingMore = true
                return fetchVideos(scope: state.feedScope, userID: state.currentUserID, cursor: state.cursor) {
                    .loadMoreResponse($0)
                }

            case .loadMoreResponse(.success(let newVideos)):
                state.isLoadingMore = false
                for video in newVideos where state.pages[id: video.id] == nil {
                    state.pages.append(makePageState(video, state: state))
                }
                state.cursor = newVideos.last?.createdAt ?? state.cursor
                state.hasMore = newVideos.count >= AppConstants.defaultPageSize
                return .none

            case .loadMoreResponse(.failure):
                state.isLoadingMore = false
                return .none

            case .pages(.element(id: let videoID, action: .commentInput(.delegate(.feedbackCreated)))):
                // 할 일 큐에서 완료 영상 제거 — pages는 세션 동안 유지해 페이저 점프 방지
                guard case .pendingFeedback = state.feedScope,
                      case .loaded(var videos) = state.loadingState else { return .none }
                videos.removeAll { $0.id == videoID }
                state.loadingState = .loaded(videos)
                return .none

            case .pages:
                return .none
            }
        }
        .forEach(\.pages, action: \.pages) {
            VideoDetailFeature()
        }
    }

    // MARK: - Helpers

    private func makePageState(_ video: Video, state: State) -> VideoDetailFeature.State {
        VideoDetailFeature.State(
            video: video,
            focusedFeedbackID: video.id == state.initialVideoID ? state.focusedFeedbackID : nil,
            currentUserID: state.currentUserID
        )
    }

    /// 페이지 활성화: 피드백 로드 + 실시간 구독 + 자동 재생
    private func activate(_ videoID: UUID?) -> Effect<Action> {
        guard let videoID else { return .none }
        return .merge(
            .send(.pages(.element(id: videoID, action: .onAppear))),
            .send(.pages(.element(id: videoID, action: .play)))
        )
    }

    private func fetchVideos(
        scope: FeedScope,
        userID: UUID?,
        cursor: Date?,
        transform: @escaping @Sendable (Result<[Video], AppError>) -> Action
    ) -> Effect<Action> {
        let video = videoClient
        let study = studyClient
        return .run { send in
            do {
                let videos: [Video]
                switch scope {
                case .pendingFeedback:
                    guard let userID else {
                        await send(transform(.success([])))
                        return
                    }
                    let studyIDs = try await study.fetchMyStudies().map(\.id)
                    videos = try await video.fetchPendingFeedbackVideos(studyIDs, userID)
                case .study(let id):
                    videos = try await video.fetchFeedVideos([id], cursor)
                }
                await send(transform(.success(videos)))
            } catch {
                let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                await send(transform(.failure(appError)))
            }
        }
    }
}
