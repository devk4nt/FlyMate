import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct VideoDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public var video: Video
        public var feedbacks: LoadingState<[Feedback]> = .idle
        public var player = VideoPlayerState()
        public var focusedFeedbackID: UUID?
        @Presents public var feedbackWrite: FeedbackWriteFeature.State?

        public init(video: Video, focusedFeedbackID: UUID? = nil) {
            self.video = video
            self.focusedFeedbackID = focusedFeedbackID
        }
    }

    public struct VideoPlayerState: Equatable {
        public var isPlaying = false
        public var currentTime: TimeInterval = 0
        public var duration: TimeInterval = 0
        public var isSeeking = false
        public var isMuted = false
        public var isFullscreen = false
    }

    public enum Action {
        case onAppear
        case onDisappear
        case feedbacksResponse(Result<[Feedback], AppError>)
        case feedbacksUpdated([Feedback])
        case clearFocusedFeedback
        // Player actions
        case playPauseTapped
        case play
        case pause
        case seek(to: TimeInterval)
        case seekCompleted
        case currentTimeUpdated(TimeInterval)
        case durationUpdated(TimeInterval)
        case playerReachedEnd
        case muteTapped
        case fullscreenTapped
        case dismissFullscreen
        // Feedback actions
        case writeFeedbackTapped
        case feedbackTapped(Feedback)
        case feedbackWrite(PresentationAction<FeedbackWriteFeature.Action>)
    }

    private enum CancelID { case realtimeFeedback }

    @Dependency(\.feedbackClient) private var feedbackClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let videoID = state.video.id
                state.feedbacks = .loading
                state.player.duration = state.video.durationSeconds
                let client = feedbackClient
                return .merge(
                    .run { send in
                        do {
                            let feedbacks = try await client.fetchFeedbacks(videoID)
                            await send(.feedbacksResponse(.success(feedbacks)))
                        } catch {
                            let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                            await send(.feedbacksResponse(.failure(appError)))
                        }
                    },
                    .run { send in
                        for await feedbacks in client.observeFeedbacks(videoID) {
                            await send(.feedbacksUpdated(feedbacks))
                        }
                    }
                    .cancellable(id: CancelID.realtimeFeedback)
                )

            case .onDisappear:
                state.player.isPlaying = false
                return .cancel(id: CancelID.realtimeFeedback)

            case .feedbacksResponse(.success(let feedbacks)):
                state.feedbacks = .loaded(feedbacks)
                // 포커스된 피드백이 있으면 해당 타임스탬프로 seek
                if let focusedID = state.focusedFeedbackID,
                   let feedback = feedbacks.first(where: { $0.id == focusedID }) {
                    return .merge(
                        .send(.seek(to: feedback.timestampSeconds)),
                        .run { send in
                            try await Task.sleep(for: .seconds(2))
                            await send(.clearFocusedFeedback)
                        }
                    )
                }
                return .none

            case .feedbacksResponse(.failure(let error)):
                state.feedbacks = .failed(error)
                return .none

            case .feedbacksUpdated(let feedbacks):
                state.feedbacks = .loaded(feedbacks)
                return .none

            case .clearFocusedFeedback:
                state.focusedFeedbackID = nil
                return .none

            case .playPauseTapped:
                if state.player.isPlaying {
                    return .send(.pause)
                } else {
                    return .send(.play)
                }

            case .play:
                state.player.isPlaying = true
                return .none

            case .pause:
                state.player.isPlaying = false
                return .none

            case .seek(let time):
                state.player.isSeeking = true
                state.player.currentTime = time
                return .none

            case .seekCompleted:
                state.player.isSeeking = false
                return .none

            case .currentTimeUpdated(let time):
                guard !state.player.isSeeking else { return .none }
                state.player.currentTime = time
                return .none

            case .durationUpdated(let duration):
                state.player.duration = duration
                return .none

            case .playerReachedEnd:
                state.player.isPlaying = false
                state.player.currentTime = 0
                return .none

            case .muteTapped:
                state.player.isMuted.toggle()
                return .none

            case .fullscreenTapped:
                state.player.isFullscreen = true
                return .none

            case .dismissFullscreen:
                state.player.isFullscreen = false
                return .none

            case .writeFeedbackTapped:
                state.feedbackWrite = FeedbackWriteFeature.State(
                    videoID: state.video.id,
                    studyID: state.video.studyID,
                    timestampSeconds: state.player.currentTime
                )
                return .send(.pause)

            case .feedbackTapped(let feedback):
                return .send(.seek(to: feedback.timestampSeconds))

            case .feedbackWrite(.presented(.feedbackSubmitted)):
                state.feedbackWrite = nil
                return .none

            case .feedbackWrite:
                return .none
            }
        }
        .ifLet(\.$feedbackWrite, action: \.feedbackWrite) {
            FeedbackWriteFeature()
        }
    }
}
