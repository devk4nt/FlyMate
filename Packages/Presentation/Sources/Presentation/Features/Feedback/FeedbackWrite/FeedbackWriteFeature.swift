import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct FeedbackWriteFeature {
    @ObservableState
    public struct State: Equatable {
        public let videoID: UUID
        public let studyID: UUID
        public var timestampSeconds: TimeInterval
        public var content = ""
        public var isSubmitting = false
        public var error: AppError?
        public var members: [StudyMember] = []
        public var mentionedUserIDs: Set<UUID> = []
        public var showMentionSuggestions = false
        public var mentionQuery = ""

        public init(videoID: UUID, studyID: UUID, timestampSeconds: TimeInterval) {
            self.videoID = videoID
            self.studyID = studyID
            self.timestampSeconds = timestampSeconds
        }

        public var isValid: Bool {
            !content.isBlank && content.count <= AppConstants.maxFeedbackLength
        }

        public var filteredMembers: [StudyMember] {
            guard !mentionQuery.isEmpty else { return members }
            return members.filter { $0.userName.localizedCaseInsensitiveContains(mentionQuery) }
        }
    }

    public enum Action: Equatable {
        case onAppear
        case membersResponse(Result<Study, AppError>)
        case contentChanged(String)
        case mentionTriggerDetected(String)
        case mentionSuggestionTapped(StudyMember)
        case mentionAllTapped
        case dismissMentionSuggestions
        case submitTapped
        case submitResponse(Result<Feedback, AppError>)
        case feedbackSubmitted
        case cancelTapped
    }

    @Dependency(\.feedbackClient) private var feedbackClient
    @Dependency(\.studyClient) private var studyClient
    @Dependency(\.dismiss) private var dismiss

    public init() {}

    /// 텍스트 내 @멘션을 파싱하여 실제 멤버와 매칭된 userID Set을 반환
    private static func syncMentionedUserIDs(
        content: String,
        members: [StudyMember]
    ) -> Set<UUID> {
        MentionUtils.syncMentionedUserIDs(content: content, members: members)
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let studyID = state.studyID
                let client = studyClient
                return .run { send in
                    do {
                        let study = try await client.fetchStudy(studyID)
                        await send(.membersResponse(.success(study)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.membersResponse(.failure(appError)))
                    }
                }

            case .membersResponse(.success(let study)):
                state.members = study.members
                return .none

            case .membersResponse(.failure):
                return .none

            case .contentChanged(let content):
                state.content = String(content.prefix(AppConstants.maxFeedbackLength))

                // 텍스트에서 @멘션 파싱 → mentionedUserIDs 동기화
                state.mentionedUserIDs = Self.syncMentionedUserIDs(
                    content: state.content,
                    members: state.members
                )

                if let atIndex = content.lastIndex(of: "@") {
                    let afterAt = content[content.index(after: atIndex)...]
                    if !afterAt.contains(" ") {
                        let query = String(afterAt)
                        return .send(.mentionTriggerDetected(query))
                    }
                }
                state.showMentionSuggestions = false
                state.mentionQuery = ""
                return .none

            case .mentionTriggerDetected(let query):
                state.mentionQuery = query
                state.showMentionSuggestions = true
                return .none

            case .mentionSuggestionTapped(let member):
                if let atIndex = state.content.lastIndex(of: "@") {
                    state.content = String(state.content[..<atIndex]) + "@\(member.userName) "
                }
                state.mentionedUserIDs = Self.syncMentionedUserIDs(
                    content: state.content,
                    members: state.members
                )
                state.showMentionSuggestions = false
                state.mentionQuery = ""
                return .none

            case .mentionAllTapped:
                if let atIndex = state.content.lastIndex(of: "@") {
                    state.content = String(state.content[..<atIndex]) + "@전체 "
                }
                state.mentionedUserIDs = Self.syncMentionedUserIDs(
                    content: state.content,
                    members: state.members
                )
                state.showMentionSuggestions = false
                state.mentionQuery = ""
                return .none

            case .dismissMentionSuggestions:
                state.showMentionSuggestions = false
                state.mentionQuery = ""
                return .none

            case .submitTapped:
                guard state.isValid else { return .none }
                state.isSubmitting = true
                let request = CreateFeedbackRequest(
                    videoID: state.videoID,
                    content: state.content,
                    timestampSeconds: state.timestampSeconds,
                    mentionedUserIDs: Array(state.mentionedUserIDs)
                )
                let client = feedbackClient
                return .run { send in
                    do {
                        let feedback = try await client.createFeedback(request)
                        await send(.submitResponse(.success(feedback)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.submitResponse(.failure(appError)))
                    }
                }

            case .submitResponse(.success):
                state.isSubmitting = false
                return .send(.feedbackSubmitted)

            case .submitResponse(.failure(let error)):
                state.isSubmitting = false
                state.error = error
                return .none

            case .feedbackSubmitted:
                let dismiss = dismiss
                return .run { _ in await dismiss() }

            case .cancelTapped:
                let dismiss = dismiss
                return .run { _ in await dismiss() }
            }
        }
    }
}
