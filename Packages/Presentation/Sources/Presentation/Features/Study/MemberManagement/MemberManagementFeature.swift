import Foundation
import ComposableArchitecture
import Domain
import Core

@Reducer
public struct MemberManagementFeature {
    @ObservableState
    public struct State: Equatable {
        public var study: Study
        public var currentUserID: UUID?
        @Presents public var confirmAlert: AlertState<Action.ConfirmAlert>?
        public var removeMemberState: LoadingState<Bool> = .idle
        fileprivate var selectedMemberUserID: UUID?

        public var isOwner: Bool {
            guard let currentUserID else { return false }
            return study.ownerID == currentUserID
        }

        public var sortedMembers: [StudyMember] {
            study.members.sorted { lhs, rhs in
                if lhs.role == .owner && rhs.role != .owner { return true }
                if lhs.role != .owner && rhs.role == .owner { return false }
                return lhs.joinedAt < rhs.joinedAt
            }
        }

        public init(study: Study, currentUserID: UUID? = nil) {
            self.study = study
            self.currentUserID = currentUserID
        }
    }

    public enum Action {
        case removeMemberTapped(StudyMember)
        case confirmAlert(PresentationAction<ConfirmAlert>)
        case removeMemberResponse(Result<UUID, AppError>)
        case memberRemoved(UUID)

        public enum ConfirmAlert: Equatable {
            case confirmRemove
        }
    }

    @Dependency(\.studyClient) private var studyClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .removeMemberTapped(let member):
                state.selectedMemberUserID = member.userID
                state.confirmAlert = AlertState {
                    TextState("멤버 내보내기")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmRemove) {
                        TextState("내보내기")
                    }
                    ButtonState(role: .cancel) {
                        TextState("취소")
                    }
                } message: {
                    TextState("\(member.userName)님을 스터디에서 내보내시겠습니까?")
                }
                return .none

            case .confirmAlert(.presented(.confirmRemove)):
                guard let memberUserID = state.selectedMemberUserID else { return .none }
                state.removeMemberState = .loading
                let studyID = state.study.id
                let client = studyClient
                return .run { send in
                    do {
                        try await client.removeMember(studyID, memberUserID)
                        await send(.removeMemberResponse(.success(memberUserID)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.removeMemberResponse(.failure(appError)))
                    }
                }

            case .removeMemberResponse(.success(let removedUserID)):
                state.removeMemberState = .idle
                state.selectedMemberUserID = nil
                state.study.members.removeAll { $0.userID == removedUserID }
                return .send(.memberRemoved(removedUserID))

            case .removeMemberResponse(.failure(let error)):
                state.removeMemberState = .failed(error)
                state.selectedMemberUserID = nil
                return .none

            case .confirmAlert:
                return .none

            case .memberRemoved:
                return .none // Handled by parent
            }
        }
        .ifLet(\.$confirmAlert, action: \.confirmAlert)
    }
}
