import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct RecruitCreateFeature {
    public enum Mode: Equatable, Sendable {
        case create
        case edit(RecruitPost)
    }

    @ObservableState
    public struct State: Equatable {
        public let mode: Mode
        public var title = ""
        public var description = ""
        public var field: RecruitField?
        public var meetingType: RecruitMeetingType = .online
        public var region = ""
        public var schedule = ""
        public var startDate: Date
        public var hasEndDate = false
        public var endDate: Date
        public var maxMembers = 4
        public var deadline: Date
        public var requirement = ""
        public var contactMethod = ""
        public var linkText = ""
        public var isSubmitting = false
        public var hasChanges = false
        public var showDiscardAlert = false
        public var error: AppError?

        public init(mode: Mode, now: Date = Date()) {
            self.mode = mode
            let week: TimeInterval = 7 * 86_400
            self.startDate = now.addingTimeInterval(week)
            self.endDate = now.addingTimeInterval(5 * week)
            self.deadline = now.addingTimeInterval(week)

            if case .edit(let post) = mode {
                title = post.title
                description = post.description
                field = post.field
                meetingType = post.meetingType
                region = post.region ?? ""
                schedule = post.schedule
                startDate = post.startDate
                hasEndDate = post.endDate != nil
                endDate = post.endDate ?? post.startDate.addingTimeInterval(4 * week)
                maxMembers = post.maxMembers
                deadline = post.deadline
                requirement = post.requirement
                contactMethod = post.contactMethod
                linkText = post.linkURL?.absoluteString ?? ""
            }
        }

        public var isEditMode: Bool {
            if case .edit = mode { return true }
            return false
        }

        public var needsRegion: Bool { meetingType.requiresRegion }

        public var linkURL: URL? {
            guard !linkText.isBlank else { return nil }
            return URL(string: linkText)
        }

        public var isLinkValid: Bool {
            linkText.isBlank || (linkURL != nil && linkText.lowercased().hasPrefix("http"))
        }

        public var isDateOrderValid: Bool {
            deadline <= startDate && (!hasEndDate || endDate >= startDate)
        }

        public var isValid: Bool {
            !title.isBlank
                && !description.isBlank
                && field != nil
                && !schedule.isBlank
                && !requirement.isBlank
                && !contactMethod.isBlank
                && (!needsRegion || !region.isBlank)
                && (1...AppConstants.maxRecruitMembers).contains(maxMembers)
                && isDateOrderValid
                && isLinkValid
        }
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case submitTapped
        case submitResponse(Result<RecruitPost, AppError>)
        case cancelTapped
        case discardConfirmed
        case discardCancelled
        case errorDismissed
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case saved(RecruitPost)
        }
    }

    @Dependency(\.recruitClient) private var recruitClient
    @Dependency(\.dismiss) private var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                state.hasChanges = true
                return .none

            case .submitTapped:
                guard state.isValid, !state.isSubmitting, let field = state.field else { return .none }
                state.isSubmitting = true
                state.error = nil
                let draft = RecruitPostDraft(
                    title: state.title,
                    description: state.description,
                    field: field,
                    meetingType: state.meetingType,
                    region: state.needsRegion ? state.region : nil,
                    schedule: state.schedule,
                    startDate: state.startDate,
                    endDate: state.hasEndDate ? state.endDate : nil,
                    maxMembers: state.maxMembers,
                    deadline: state.deadline,
                    requirement: state.requirement,
                    contactMethod: state.contactMethod,
                    linkURL: state.linkURL
                )
                let client = recruitClient
                let mode = state.mode
                return .run { send in
                    do {
                        let post: RecruitPost
                        switch mode {
                        case .create:
                            post = try await client.createPost(draft)
                        case .edit(let original):
                            post = try await client.updatePost(original.id, draft)
                        }
                        await send(.submitResponse(.success(post)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.submitResponse(.failure(appError)))
                    }
                }

            case .submitResponse(.success(let post)):
                state.isSubmitting = false
                let dismiss = dismiss
                return .concatenate(
                    .send(.delegate(.saved(post))),
                    .run { _ in await dismiss() }
                )

            case .submitResponse(.failure(let error)):
                // 실패 시 입력 내용은 그대로 유지되어 재시도 가능
                state.isSubmitting = false
                state.error = error
                return .none

            case .cancelTapped:
                guard state.hasChanges else {
                    let dismiss = dismiss
                    return .run { _ in await dismiss() }
                }
                state.showDiscardAlert = true
                return .none

            case .discardConfirmed:
                state.showDiscardAlert = false
                let dismiss = dismiss
                return .run { _ in await dismiss() }

            case .discardCancelled:
                state.showDiscardAlert = false
                return .none

            case .errorDismissed:
                state.error = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
