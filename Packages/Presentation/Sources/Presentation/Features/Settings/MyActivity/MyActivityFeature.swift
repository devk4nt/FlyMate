import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct MyActivityFeature {
    @ObservableState
    public struct State: Equatable, Identifiable {
        public let userID: UUID
        public let userName: String
        public let profileImageURL: URL?
        public let isCurrentUser: Bool
        public var stats: LoadingState<MyActivityStats> = .idle

        public var id: UUID { userID }

        public init(currentUser: User) {
            self.userID = currentUser.id
            self.userName = currentUser.name
            self.profileImageURL = currentUser.profileImageURL
            self.isCurrentUser = true
        }

        public init(userID: UUID, userName: String, profileImageURL: URL?) {
            self.userID = userID
            self.userName = userName
            self.profileImageURL = profileImageURL
            self.isCurrentUser = false
        }
    }

    public enum Action: Equatable {
        case onAppear
        case statsResponse(Result<MyActivityStats, AppError>)
        case retry
    }

    @Dependency(\.userClient) private var userClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard case .idle = state.stats else { return .none }
                state.stats = .loading
                let client = userClient
                let userID = state.userID
                let isCurrentUser = state.isCurrentUser
                return .run { send in
                    do {
                        let stats: MyActivityStats
                        if isCurrentUser {
                            stats = try await client.fetchMyActivityStats()
                        } else {
                            stats = try await client.fetchActivityStats(userID)
                        }
                        await send(.statsResponse(.success(stats)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.statsResponse(.failure(appError)))
                    }
                }

            case .statsResponse(.success(let stats)):
                state.stats = .loaded(stats)
                return .none

            case .statsResponse(.failure(let error)):
                state.stats = .failed(error)
                return .none

            case .retry:
                state.stats = .idle
                return .send(.onAppear)
            }
        }
    }
}
