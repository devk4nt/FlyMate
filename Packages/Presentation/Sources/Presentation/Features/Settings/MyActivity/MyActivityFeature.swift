import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct MyActivityFeature {
    @ObservableState
    public struct State: Equatable {
        public let currentUser: User
        public var stats: LoadingState<MyActivityStats> = .idle

        public init(currentUser: User) {
            self.currentUser = currentUser
        }
    }

    public enum Action {
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
                return .run { send in
                    do {
                        let stats = try await client.fetchMyActivityStats()
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
