import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct StudyCreateFeature {
    @ObservableState
    public struct State: Equatable {
        public var name = ""
        public var description = ""
        public var maxMembers = AppConstants.maxStudyMembers
        public var isSubmitting = false
        public var error: AppError?

        public init() {}

        public var isValid: Bool {
            !name.isBlank && !description.isBlank && maxMembers >= 2
        }
    }

    public enum Action: Equatable {
        case nameChanged(String)
        case descriptionChanged(String)
        case maxMembersChanged(Int)
        case submitTapped
        case createResponse(Result<Study, AppError>)
        case studyCreated
        case cancelTapped
        case errorDismissed
    }

    @Dependency(\.studyClient) private var studyClient
    @Dependency(\.dismiss) private var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .nameChanged(let name):
                state.name = String(name.prefix(AppConstants.maxStudyNameLength))
                return .none

            case .descriptionChanged(let description):
                state.description = description
                return .none

            case .maxMembersChanged(let count):
                state.maxMembers = max(2, min(count, AppConstants.maxStudyMembers))
                return .none

            case .submitTapped:
                print("🟡 [StudyCreate] submitTapped - isValid: \(state.isValid), name: '\(state.name)', desc: '\(state.description)'")
                guard state.isValid else {
                    print("🔴 [StudyCreate] isValid = false, returning")
                    return .none
                }
                state.isSubmitting = true
                let request = CreateStudyRequest(
                    name: state.name,
                    description: state.description,
                    maxMembers: state.maxMembers
                )
                let client = studyClient
                return .run { send in
                    do {
                        print("🟡 [StudyCreate] Calling createStudy API...")
                        let study = try await client.createStudy(request)
                        print("🟢 [StudyCreate] Success: \(study.name)")
                        await send(.createResponse(.success(study)))
                    } catch {
                        print("🔴 [StudyCreate] Error: \(error)")
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.createResponse(.failure(appError)))
                    }
                }

            case .createResponse(.success):
                print("🟢 [StudyCreate] createResponse success")
                state.isSubmitting = false
                return .send(.studyCreated)

            case .createResponse(.failure(let error)):
                print("🔴 [StudyCreate] createResponse failure: \(error)")
                state.isSubmitting = false
                state.error = error
                return .none

            case .studyCreated:
                let dismiss = dismiss
                return .run { _ in await dismiss() }

            case .cancelTapped:
                let dismiss = dismiss
                return .run { _ in await dismiss() }

            case .errorDismissed:
                state.error = nil
                return .none
            }
        }
    }
}
