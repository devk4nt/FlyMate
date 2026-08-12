import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct BlockedUsersFeature {
    @ObservableState
    public struct State: Equatable {
        public var blockedUsers: LoadingState<[BlockedUser]> = .idle
        public var showToast = false
        public var toastMessage = ""

        public init() {}
    }

    public enum Action: Equatable {
        case onAppear
        case retryTapped
        case blockedUsersResponse(Result<[BlockedUser], AppError>)
        case unblockTapped(BlockedUser)
        case unblockResponse(Result<UUID, AppError>)
        case dismissToast
    }

    @Dependency(\.blockClient) private var blockClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard case .idle = state.blockedUsers else { return .none }
                state.blockedUsers = .loading
                return fetchBlockedUsers()

            case .retryTapped:
                state.blockedUsers = .loading
                return fetchBlockedUsers()

            case .blockedUsersResponse(.success(let users)):
                state.blockedUsers = .loaded(users)
                return .none

            case .blockedUsersResponse(.failure(let error)):
                state.blockedUsers = .failed(error)
                return .none

            case .unblockTapped(let user):
                let userID = user.id
                let client = blockClient
                return .run { send in
                    do {
                        try await client.unblockUser(userID)
                        await send(.unblockResponse(.success(userID)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.unblockResponse(.failure(appError)))
                    }
                }

            case .unblockResponse(.success(let userID)):
                if case .loaded(var users) = state.blockedUsers {
                    users.removeAll { $0.id == userID }
                    state.blockedUsers = .loaded(users)
                }
                state.showToast = true
                state.toastMessage = "차단을 해제했습니다"
                return .none

            case .unblockResponse(.failure):
                state.showToast = true
                state.toastMessage = "차단 해제에 실패했습니다. 다시 시도해 주세요."
                return .none

            case .dismissToast:
                state.showToast = false
                return .none
            }
        }
    }

    private func fetchBlockedUsers() -> Effect<Action> {
        let client = blockClient
        return .run { send in
            do {
                let users = try await client.fetchBlockedUsers()
                await send(.blockedUsersResponse(.success(users)))
            } catch {
                let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                await send(.blockedUsersResponse(.failure(appError)))
            }
        }
    }
}
