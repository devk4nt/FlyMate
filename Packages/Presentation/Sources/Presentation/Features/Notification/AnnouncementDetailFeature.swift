import Foundation
import ComposableArchitecture
import Domain

@Reducer
public struct AnnouncementDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public let notification: AppNotification

        public init(notification: AppNotification) {
            self.notification = notification
        }
    }

    public enum Action: Equatable {
        case closeTapped
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { _, _ in .none }
    }
}
