import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct ReportFeature : Sendable {
    @ObservableState
    public struct State: Equatable {
        public let targetType: ReportTargetType
        public let targetID: UUID
        public var selectedReason: ReportReason?
        public var detail: String = ""
        public var isSubmitting = false
        public var alreadyReported = false

        public init(targetType: ReportTargetType, targetID: UUID) {
            self.targetType = targetType
            self.targetID = targetID
        }

        var canSubmit: Bool {
            selectedReason != nil && !isSubmitting && !alreadyReported
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case checkAlreadyReportedResponse(Bool)
        case reasonSelected(ReportReason)
        case submitTapped
        case submitResponse(Result<Report, AppError>)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case reportSubmitted
            case alreadyReported
        }
    }

    @Dependency(\.reportClient) private var reportClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                let targetType = state.targetType
                let targetID = state.targetID
                return .run { send in
                    let reported = try await reportClient.checkAlreadyReported(targetType, targetID)
                    await send(.checkAlreadyReportedResponse(reported))
                }

            case .checkAlreadyReportedResponse(let reported):
                state.alreadyReported = reported
                if reported {
                    return .send(.delegate(.alreadyReported))
                }
                return .none

            case .reasonSelected(let reason):
                state.selectedReason = reason
                return .none

            case .submitTapped:
                guard let reason = state.selectedReason, !state.isSubmitting else { return .none }
                state.isSubmitting = true
                let trimmedDetail = state.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                let request = CreateReportRequest(
                    targetType: state.targetType,
                    targetID: state.targetID,
                    reason: reason,
                    detail: trimmedDetail.isEmpty ? nil : String(trimmedDetail.prefix(AppConstants.maxReportDetailLength))
                )
                return .run { send in
                    do {
                        let report = try await reportClient.createReport(request)
                        await send(.submitResponse(.success(report)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.submitResponse(.failure(appError)))
                    }
                }

            case .submitResponse(.success):
                state.isSubmitting = false
                return .send(.delegate(.reportSubmitted))

            case .submitResponse(.failure):
                state.isSubmitting = false
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
