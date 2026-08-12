import Foundation
import ComposableArchitecture
import Domain

@Reducer
public struct FeedbackManagementFeature {
    @ObservableState
    public struct State: Equatable {
        public let userID: UUID
        public var selectedSegment: Segment = .pending
        public var pending: VideoFeedFeature.State
        public var received: FeedbackListFeature.State
        public var given: FeedbackListFeature.State

        public init(userID: UUID) {
            self.userID = userID
            self.pending = VideoFeedFeature.State(scope: .pendingFeedback, currentUserID: userID)
            self.received = FeedbackListFeature.State(userID: userID, listType: .received)
            self.given = FeedbackListFeature.State(userID: userID, listType: .given)
        }

        public enum Segment: String, CaseIterable, Equatable {
            case pending = "할 일"
            case received = "받은 피드백"
            case given = "작성한 피드백"
        }
    }

    public enum Action {
        case segmentChanged(State.Segment)
        case pending(VideoFeedFeature.Action)
        case received(FeedbackListFeature.Action)
        case given(FeedbackListFeature.Action)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.pending, action: \.pending) {
            VideoFeedFeature()
        }
        Scope(state: \.received, action: \.received) {
            FeedbackListFeature()
        }
        Scope(state: \.given, action: \.given) {
            FeedbackListFeature()
        }
        Reduce { state, action in
            switch action {
            case .segmentChanged(let segment):
                state.selectedSegment = segment
                return .none
            case .pending, .received, .given:
                return .none
            }
        }
    }
}
