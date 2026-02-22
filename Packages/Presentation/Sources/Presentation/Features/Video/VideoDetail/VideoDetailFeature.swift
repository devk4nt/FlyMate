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
        @Presents public var feedbackWrite: FeedbackWriteFeature.State?

        public init(video: Video) {
            self.video = video
        }
    }

    public struct VideoPlayerState: Equatable {
        public var isPlaying = false
        public var currentTime: TimeInterval = 0
        public var duration: TimeInterval = 0
        public var isSeeking = false
    }

    public enum Action {
        case onAppear
        case onDisappear
        case feedbacksResponse(Result<[Feedback], AppError>)
        case feedbacksUpdated([Feedback])
        // Player actions
        case play
        case pause
        case seek(to: TimeInterval)
        case currentTimeUpdated(TimeInterval)
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
                return .cancel(id: CancelID.realtimeFeedback)

            case .feedbacksResponse(.success(let feedbacks)):
                state.feedbacks = .loaded(feedbacks)
                return .none

            case .feedbacksResponse(.failure(let error)):
                state.feedbacks = .failed(error)
                return .none

            case .feedbacksUpdated(let feedbacks):
                state.feedbacks = .loaded(feedbacks)
                return .none

            case .play:
                state.player.isPlaying = true
                return .none

            case .pause:
                state.player.isPlaying = false
                return .none

            case .seek(let time):
                state.player.currentTime = time
                return .none

            case .currentTimeUpdated(let time):
                state.player.currentTime = time
                return .none

            case .writeFeedbackTapped:
                state.feedbackWrite = FeedbackWriteFeature.State(
                    videoID: state.video.id,
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
