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

        public init(currentUser: User) {
            self.currentUser = currentUser
            self.name = currentUser.name
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
                state.error = error
                return .none

            case .profileUpdated:
                let dismiss = dismiss
                return .run { _ in await dismiss() }

            case .cancelTapped:
                let dismiss = dismiss
                return .run { _ in await dismiss() }
            }
        }
    }
}
