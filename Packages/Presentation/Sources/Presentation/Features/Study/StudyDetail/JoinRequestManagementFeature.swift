import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct JoinRequestManagementFeature {
    @ObservableState
    public struct State: Equatable {
        public let studyID: UUID
        public var requests: LoadingState<[JoinRequest]> = .idle
        public var actionInProgress: Set<UUID> = []
        @Presents public var confirmAlert: AlertState<Action.ConfirmAlert>?
        fileprivate var selectedRequest: JoinRequest?

        public init(studyID: UUID) {
            self.studyID = studyID
        }
    }

    public enum Action: Equatable {
        case onAppear
        case requestsResponse(Result<[JoinRequest], AppError>)
        case approveTapped(JoinRequest)
        case rejectTapped(JoinRequest)
        case confirmAlert(PresentationAction<ConfirmAlert>)
        case approveResponse(UUID, Result<Bool, AppError>)
        case rejectResponse(UUID, Result<Bool, AppError>)
        case delegate(Delegate)

        public enum ConfirmAlert: Equatable {
            case confirmReject
        }

        public enum Delegate: Equatable {
            case memberApproved
        }
    }

    @Dependency(\.studyClient) private var studyClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard case .idle = state.requests else { return .none }
                state.requests = .loading
                let studyID = state.studyID
                let client = studyClient
                return .run { send in
                    do {
                        let requests = try await client.fetchPendingRequests(studyID)
                        await send(.requestsResponse(.success(requests)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.requestsResponse(.failure(appError)))
                    }
                }

            case .requestsResponse(.success(let requests)):
                state.requests = .loaded(requests)
                return .none

            case .requestsResponse(.failure(let error)):
                state.requests = .failed(error)
                return .none

            case .approveTapped(let request):
                state.actionInProgress.insert(request.id)
                let client = studyClient
                return .run { send in
                    do {
                        try await client.approveJoinRequest(request.id)
                        await send(.approveResponse(request.id, .success(true)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.approveResponse(request.id, .failure(appError)))
                    }
                }

            case .rejectTapped(let request):
                state.selectedRequest = request
                state.confirmAlert = AlertState {
                    TextState("참여 요청 거절")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmReject) {
                        TextState("거절")
                    }
                    ButtonState(role: .cancel) {
                        TextState("취소")
                    }
                } message: {
                    TextState("\(request.userName)님의 참여 요청을 거절하시겠습니까?\n거절 후 다시 요청할 수 있습니다.")
                }
                return .none

            case .confirmAlert(.presented(.confirmReject)):
                guard let request = state.selectedRequest else { return .none }
                state.selectedRequest = nil
                state.actionInProgress.insert(request.id)
                let client = studyClient
                return .run { send in
                    do {
                        try await client.rejectJoinRequest(request.id)
                        await send(.rejectResponse(request.id, .success(true)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.rejectResponse(request.id, .failure(appError)))
                    }
                }

            case .confirmAlert:
                state.selectedRequest = nil
                return .none

            case .approveResponse(let requestID, .success):
                state.actionInProgress.remove(requestID)
                if case .loaded(var requests) = state.requests {
                    requests.removeAll { $0.id == requestID }
                    state.requests = .loaded(requests)
                }
                return .send(.delegate(.memberApproved))

            case .approveResponse(let requestID, .failure):
                state.actionInProgress.remove(requestID)
                return .none

            case .rejectResponse(let requestID, .success):
                state.actionInProgress.remove(requestID)
                if case .loaded(var requests) = state.requests {
                    requests.removeAll { $0.id == requestID }
                    state.requests = .loaded(requests)
                }
                return .none

            case .rejectResponse(let requestID, .failure):
                state.actionInProgress.remove(requestID)
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$confirmAlert, action: \.confirmAlert)
    }
}
