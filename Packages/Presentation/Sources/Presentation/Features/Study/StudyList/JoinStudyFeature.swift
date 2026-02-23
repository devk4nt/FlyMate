import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct JoinStudyFeature {
    @ObservableState
    public struct State: Equatable {
        public var inviteCode: String
        public var joinState: LoadingState<Study> = .idle
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
    }

    public enum Action: Equatable {
        case inviteCodeChanged(String)
        case joinTapped
        case joinResponse(Result<Study, AppError>)
        case cancelTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case studyJoined(Study)
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
                        let study = try await client.joinStudy(code)
                        await send(.joinResponse(.success(study)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.joinResponse(.failure(appError)))
                    }
                }

            case .joinResponse(.success(let study)):
                state.joinState = .loaded(study)
                return .send(.delegate(.studyJoined(study)))

            case .joinResponse(.failure(let error)):
                state.joinState = .failed(error)
                state.errorMessage = error.errorDescription ?? "알 수 없는 오류가 발생했습니다."
                return .none

            case .cancelTapped:
                let dismiss = dismiss
                return .run { _ in await dismiss() }

            case .delegate:
                return .none
            }
        }
    }
}
