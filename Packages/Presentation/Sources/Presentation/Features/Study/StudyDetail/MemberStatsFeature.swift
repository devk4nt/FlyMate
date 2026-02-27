import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct MemberStatsFeature {
    @ObservableState
    public struct State: Equatable, Identifiable {
        public var id: UUID { member.id }
        public let member: StudyMember
        public let studyID: UUID
        public var stats: LoadingState<MemberStats> = .idle

        public init(member: StudyMember, studyID: UUID) {
            self.member = member
            self.studyID = studyID
        }
    }

    public enum Action {
        case onAppear
        case statsResponse(Result<MemberStats, AppError>)
        case retry
    }

    @Dependency(\.studyClient) private var studyClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard case .idle = state.stats else { return .none }
                state.stats = .loading
                let studyID = state.studyID
                let userID = state.member.userID
                let client = studyClient
                return .run { send in
                    do {
                        let stats = try await client.fetchMemberStats(studyID, userID)
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
