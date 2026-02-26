import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct JoinStudyFeature {
    @ObservableState
    public struct State: Equatable {
        public var inviteCode: String
        public var joinState: LoadingState<JoinRequest> = .idle
        public var errorMessage: String?

        public init(inviteCode: String = "") {
            self.inviteCode = inviteCode
        }

        public var isCodeValid: Bool {
            inviteCode.count == AppConstants.inviteCodeLength
        }

        public var isJoining: Bool {
            if case .loading = joinState { return true }
            return false
        }

        public var isRequestSent: Bool {
            if case .loaded = joinState { return true }
            return false
        }
    }

    public enum Action: Equatable {
        case inviteCodeChanged(String)
        case joinTapped
        case requestResponse(Result<JoinRequest, AppError>)
        case confirmTapped
        case cancelTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case joinRequested
        }
    }

    @Dependency(\.studyClient) private var studyClient
    @Dependency(\.dismiss) private var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .inviteCodeChanged(let code):
                state.inviteCode = String(code.uppercased().prefix(AppConstants.inviteCodeLength))
                state.errorMessage = nil
                return .none

            case .joinTapped:
                guard state.isCodeValid else { return .none }
                state.joinState = .loading
                state.errorMessage = nil
                let code = state.inviteCode
                let client = studyClient
                return .run { send in
                    do {
                        let request = try await client.requestJoinStudy(code)
                        await send(.requestResponse(.success(request)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.requestResponse(.failure(appError)))
                    }
                }

            case .requestResponse(.success(let joinRequest)):
                state.joinState = .loaded(joinRequest)
                return .none

            case .requestResponse(.failure(let error)):
                state.joinState = .failed(error)
                state.errorMessage = error.errorDescription ?? "알 수 없는 오류가 발생했습니다."
                return .none

            case .confirmTapped:
                return .send(.delegate(.joinRequested))

            case .cancelTapped:
                let dismiss = dismiss
                return .run { _ in await dismiss() }

            case .delegate:
                return .none
            }
        }
    }
}
