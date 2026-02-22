import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct StudyListFeature {
    @ObservableState
    public struct State: Equatable {
        public var studies: LoadingState<[Study]> = .idle
        @Presents public var createStudy: StudyCreateFeature.State?
        @Presents public var joinStudyAlert: AlertState<Action.JoinStudyAlert>?
        public var inviteCodeInput = ""

        public init() {}
    }

    public enum Action {
        case onAppear
        case refresh
        case studiesResponse(Result<[Study], AppError>)
        case studyTapped(Study)
        case createStudyTapped
        case joinStudyTapped
        case createStudy(PresentationAction<StudyCreateFeature.Action>)
        case joinStudyAlert(PresentationAction<JoinStudyAlert>)
        case inviteCodeChanged(String)
        case joinStudyResponse(Result<Study, AppError>)

        public enum JoinStudyAlert: Equatable {
            case confirmTapped
        }
    }

    @Dependency(\.studyClient) private var studyClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard case .idle = state.studies else { return .none }
                state.studies = .loading
                let client = studyClient
                return .run { send in
                    do {
                        let studies = try await client.fetchMyStudies()
                        await send(.studiesResponse(.success(studies)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.studiesResponse(.failure(appError)))
                    }
                }

            case .refresh:
                state.studies = .loading
                let client = studyClient
                return .run { send in
                    do {
                        let studies = try await client.fetchMyStudies()
                        await send(.studiesResponse(.success(studies)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.studiesResponse(.failure(appError)))
                    }
                }

            case .studiesResponse(.success(let studies)):
                state.studies = .loaded(studies)
                return .none

            case .studiesResponse(.failure(let error)):
                state.studies = .failed(error)
                return .none

            case .studyTapped:
                return .none // Handled by parent

            case .createStudyTapped:
                state.createStudy = StudyCreateFeature.State()
                return .none

            case .joinStudyTapped:
                state.joinStudyAlert = AlertState {
                    TextState("스터디 참여")
                } actions: {
                    ButtonState(action: .confirmTapped) {
                        TextState("참여하기")
                    }
                    ButtonState(role: .cancel) {
                        TextState("취소")
                    }
                } message: {
                    TextState("초대 코드를 입력해주세요.")
                }
                return .none

            case .inviteCodeChanged(let code):
                state.inviteCodeInput = code.uppercased()
                return .none

            case .joinStudyAlert(.presented(.confirmTapped)):
                let code = state.inviteCodeInput
                let client = studyClient
                return .run { send in
                    do {
                        let study = try await client.joinStudy(code)
                        await send(.joinStudyResponse(.success(study)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.joinStudyResponse(.failure(appError)))
                    }
                }

            case .joinStudyResponse(.success):
                state.inviteCodeInput = ""
                return .send(.refresh)

            case .joinStudyResponse(.failure):
                return .none

            case .createStudy(.presented(.studyCreated)):
                state.createStudy = nil
                return .send(.refresh)

            case .createStudy, .joinStudyAlert:
                return .none
            }
        }
        .ifLet(\.$createStudy, action: \.createStudy) {
            StudyCreateFeature()
        }
    }
}
