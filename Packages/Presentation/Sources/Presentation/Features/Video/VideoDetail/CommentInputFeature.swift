import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct CommentInputFeature {
    @ObservableState
    public struct State: Equatable {
        public let videoID: UUID
        public var text = ""
        public var isSubmitting = false
        public var isFocused = false
        public var error: AppError?
        public var replyContext: ReplyContext?
        public var members: [StudyMember] = []
        public var mentionedUserIDs: Set<UUID> = []
        public var showMentionSuggestions = false
        public var mentionQuery = ""

        public init(videoID: UUID) {
            self.videoID = videoID
        }

        public var isReplyMode: Bool { replyContext != nil }

        public var maxLength: Int {
            replyContext != nil ? AppConstants.maxCommentLength : AppConstants.maxFeedbackLength
        }

        public var isValid: Bool {
            !text.isBlank && text.count <= maxLength
        }

        public var filteredMembers: [StudyMember] {
            guard !mentionQuery.isEmpty else { return members }
            return members.filter { $0.userName.localizedCaseInsensitiveContains(mentionQuery) }
        }
    }

    public struct ReplyContext: Equatable, Sendable {
        public let feedbackID: UUID
        public let authorName: String

        public init(feedbackID: UUID, authorName: String) {
            self.feedbackID = feedbackID
            self.authorName = authorName
        }
    }

    public enum Action: Equatable {
        case textChanged(String)
        case submitTapped(timestampSeconds: TimeInterval)
        case focusChanged(Bool)
        case enterReplyMode(feedbackID: UUID, authorName: String)
        case exitReplyMode
        case cancelTapped
        case feedbackSubmitResponse(Result<Feedback, AppError>)
        case commentSubmitResponse(Result<FeedbackComment, AppError>)
        case mentionTriggerDetected(String)
        case mentionSuggestionTapped(StudyMember)
        case mentionAllTapped
        case dismissMentionSuggestions
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case feedbackCreated(Feedback)
            case commentCreated(FeedbackComment, feedbackID: UUID)
        }
    }

    @Dependency(\.feedbackClient) private var feedbackClient
    @Dependency(\.feedbackCommentClient) private var feedbackCommentClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .textChanged(let newText):
                state.error = nil
                let maxLen = state.maxLength
                state.text = String(newText.prefix(maxLen))

                state.mentionedUserIDs = MentionUtils.syncMentionedUserIDs(
                    content: state.text,
                    members: state.members
                )

                if let atIndex = newText.lastIndex(of: "@") {
                    let afterAt = newText[newText.index(after: atIndex)...]
                    if !afterAt.contains(" ") {
                        let query = String(afterAt)
                        return .send(.mentionTriggerDetected(query))
                    }
                }
                state.showMentionSuggestions = false
                state.mentionQuery = ""
                return .none

            case .submitTapped(let timestampSeconds):
                guard state.isValid else { return .none }
                state.isSubmitting = true
                state.error = nil

                if let replyContext = state.replyContext {
                    // 답글 모드 → FeedbackComment 생성
                    let request = CreateFeedbackCommentRequest(
                        feedbackID: replyContext.feedbackID,
                        content: state.text,
                        mentionedUserIDs: Array(state.mentionedUserIDs)
                    )
                    let client = feedbackCommentClient
                    return .run { send in
                        do {
                            let comment = try await client.createComment(request)
                            await send(.commentSubmitResponse(.success(comment)))
                        } catch {
                            let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                            await send(.commentSubmitResponse(.failure(appError)))
                        }
                    }
                } else {
                    // 댓글 모드 → Feedback 생성
                    let request = CreateFeedbackRequest(
                        videoID: state.videoID,
                        content: state.text,
                        timestampSeconds: timestampSeconds,
                        mentionedUserIDs: Array(state.mentionedUserIDs)
                    )
                    let client = feedbackClient
                    return .run { send in
                        do {
                            let feedback = try await client.createFeedback(request)
                            await send(.feedbackSubmitResponse(.success(feedback)))
                        } catch {
                            let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                            await send(.feedbackSubmitResponse(.failure(appError)))
                        }
                    }
                }

            case .focusChanged(let focused):
                state.isFocused = focused
                if !focused {
                    state.showMentionSuggestions = false
                    state.mentionQuery = ""
                }
                return .none

            case .enterReplyMode(let feedbackID, let authorName):
                state.replyContext = ReplyContext(feedbackID: feedbackID, authorName: authorName)
                state.text = "@\(authorName) "
                state.isFocused = true
                state.mentionedUserIDs = MentionUtils.syncMentionedUserIDs(
                    content: state.text,
                    members: state.members
                )
                state.error = nil
                return .none

            case .exitReplyMode:
                state.replyContext = nil
                state.text = ""
                state.isFocused = false
                state.mentionedUserIDs = []
                state.showMentionSuggestions = false
                state.mentionQuery = ""
                state.error = nil
                return .none

            case .cancelTapped:
                if state.replyContext != nil {
                    return .send(.exitReplyMode)
                }
                state.text = ""
                state.isFocused = false
                state.mentionedUserIDs = []
                state.showMentionSuggestions = false
                state.mentionQuery = ""
                return .none

            case .feedbackSubmitResponse(.success(let feedback)):
                state.isSubmitting = false
                state.isFocused = false
                state.text = ""
                state.mentionedUserIDs = []
                return .send(.delegate(.feedbackCreated(feedback)))

            case .feedbackSubmitResponse(.failure(let error)):
                state.isSubmitting = false
                state.error = error
                return .none

            case .commentSubmitResponse(.success(let comment)):
                state.isSubmitting = false
                state.isFocused = false
                let feedbackID = state.replyContext?.feedbackID ?? comment.feedbackID
                state.text = ""
                state.mentionedUserIDs = []
                state.replyContext = nil
                state.showMentionSuggestions = false
                state.mentionQuery = ""
                return .send(.delegate(.commentCreated(comment, feedbackID: feedbackID)))

            case .commentSubmitResponse(.failure(let error)):
                state.isSubmitting = false
                state.error = error
                return .none

            case .mentionTriggerDetected(let query):
                state.mentionQuery = query
                state.showMentionSuggestions = true
                return .none

            case .mentionSuggestionTapped(let member):
                if let atIndex = state.text.lastIndex(of: "@") {
                    state.text = String(state.text[..<atIndex]) + "@\(member.userName) "
                }
                state.mentionedUserIDs = MentionUtils.syncMentionedUserIDs(
                    content: state.text,
                    members: state.members
                )
                state.showMentionSuggestions = false
                state.mentionQuery = ""
                return .none

            case .mentionAllTapped:
                if let atIndex = state.text.lastIndex(of: "@") {
                    state.text = String(state.text[..<atIndex]) + "@전체 "
                }
                state.mentionedUserIDs = MentionUtils.syncMentionedUserIDs(
                    content: state.text,
                    members: state.members
                )
                state.showMentionSuggestions = false
                state.mentionQuery = ""
                return .none

            case .dismissMentionSuggestions:
                state.showMentionSuggestions = false
                state.mentionQuery = ""
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
