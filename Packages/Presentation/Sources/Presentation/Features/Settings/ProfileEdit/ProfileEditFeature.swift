import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct ProfileEditFeature {
    @ObservableState
    public struct State: Equatable {
        public var currentUser: User
        public var name: String
        public var selectedImageData: Data?
        public var isSubmitting = false
        public var error: AppError?
        @Presents public var alert: AlertState<Action.Alert>?
        /// 첫 로그인 직후 이름 설정 권유로 띄운 경우 — 문구만 달라지고 저장 로직은 같다
        public let isNameSetup: Bool

        public init(currentUser: User, isNameSetup: Bool = false) {
            self.currentUser = currentUser
            // 임시 이름(User28 등)을 그대로 두면 지우고 쓰는 수고가 생긴다
            self.name = isNameSetup ? "" : currentUser.name
            self.isNameSetup = isNameSetup
        }

        public var isValid: Bool {
            !name.isBlank
        }

        public var hasChanges: Bool {
            name != currentUser.name || selectedImageData != nil
        }
    }

    public enum Action: Equatable {
        case nameChanged(String)
        case imageSelected(Data)
        case saveTapped
        case saveResponse(Result<User, AppError>)
        case profileUpdated(User)
        case cancelTapped
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    @Dependency(\.userClient) private var userClient
    @Dependency(\.dismiss) private var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .nameChanged(let name):
                state.name = name
                return .none

            case .imageSelected(let data):
                state.selectedImageData = data
                return .none

            case .saveTapped:
                guard state.isValid, state.hasChanges else { return .none }
                state.isSubmitting = true
                let request = UpdateProfileRequest(
                    name: state.name,
                    profileImageData: state.selectedImageData
                )
                let client = userClient
                return .run { send in
                    do {
                        let user = try await client.updateProfile(request)
                        await send(.saveResponse(.success(user)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.saveResponse(.failure(appError)))
                    }
                }

            case .saveResponse(.success(let user)):
                state.isSubmitting = false
                return .send(.profileUpdated(user))

            case .saveResponse(.failure(let error)):
                state.isSubmitting = false
                if error == .business(.nameAlreadyTaken) {
                    state.alert = AlertState {
                        TextState("이름 중복")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("확인")
                        }
                    } message: {
                        TextState(BusinessError.nameAlreadyTaken.userMessage)
                    }
                } else {
                    state.error = error
                }
                return .none

            case .profileUpdated:
                let dismiss = dismiss
                return .run { _ in await dismiss() }

            case .cancelTapped:
                let dismiss = dismiss
                return .run { _ in await dismiss() }

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
