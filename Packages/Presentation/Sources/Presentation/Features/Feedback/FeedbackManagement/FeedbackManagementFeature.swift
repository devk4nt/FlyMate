import Foundation
import ComposableArchitecture
import Domain

@Reducer
public struct FeedbackManagementFeature {
    @ObservableState
    public struct State: Equatable {
        public let userID: UUID
        public var selectedSegment: Segment = .received
        public var received: FeedbackListFeature.State
        public var given: FeedbackListFeature.State

        public init(userID: UUID) {
            self.userID = userID
            self.received = FeedbackListFeature.State(userID: userID, listType: .received)
            self.given = FeedbackListFeature.State(userID: userID, listType: .given)
        }

        public enum Segment: String, CaseIterable, Equatable {
            case received = "받은 피드백"
            case given = "작성한 피드백"
        }
    }

    public enum Action {
        case segmentChanged(State.Segment)
        case received(FeedbackListFeature.Action)
        case given(FeedbackListFeature.Action)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
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
            case .received, .given:
                return .none
            }
        }
    }
}
