import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct FeedbackCommentListFeature {
    @ObservableState
    public struct State: Equatable {
        public let feedback: Feedback
        public let studyID: UUID
        public var comments: LoadingState<[FeedbackComment]> = .idle
        public var commentText = ""
        public var isSubmitting = false
        public var error: AppError?
        public var members: [StudyMember] = []
        public var mentionedUserIDs: Set<UUID> = []
        public var showMentionSuggestions = false
        public var mentionQuery = ""
        public var currentUserID: UUID?

        public init(feedback: Feedback, studyID: UUID, currentUserID: UUID? = nil) {
            self.feedback = feedback
            self.studyID = studyID
            self.currentUserID = currentUserID
        }

        public var isValid: Bool {
            !commentText.isBlank && commentText.count <= AppConstants.maxCommentLength
        }

        public var filteredMembers: [StudyMember] {
            guard !mentionQuery.isEmpty else { return members }
            return members.filter { $0.userName.localizedCaseInsensitiveContains(mentionQuery) }
        }
    }

    public enum Action: Equatable {
        case onAppear
        case commentsResponse(Result<[FeedbackComment], AppError>)
        case membersResponse(Result<Study, AppError>)
        case commentTextChanged(String)
        case submitTapped
        case submitResponse(Result<FeedbackComment, AppError>)
        case deleteCommentTapped(FeedbackComment)
        case deleteResponse(Result<UUID, AppError>)
        // 멘션
        case mentionTriggerDetected(String)
        case mentionSuggestionTapped(StudyMember)
        case mentionAllTapped
        case dismissMentionSuggestions
    }

    @Dependency(\.feedbackCommentClient) private var commentClient
    @Dependency(\.studyClient) private var studyClient

    public init() {}

    private static func syncMentionedUserIDs(
        content: String,
        members: [StudyMember]
    ) -> Set<UUID> {
        guard let regex = try? NSRegularExpression(pattern: "@(\\S+)") else { return [] }
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

        var ids = Set<UUID>()
        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let nameRange = match.range(at: 1)
            let name = nsContent.substring(with: nameRange)

            if name == "전체" {
                for member in members {
                    ids.insert(member.userID)
                }
            } else if let member = members.first(where: { $0.userName == name }) {
                ids.insert(member.userID)
            }
        }
        return ids
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.comments = .loading
                let feedbackID = state.feedback.id
                let studyID = state.studyID
                let client = commentClient
                let study = studyClient
                return .merge(
                    .run { send in
                        do {
                            let comments = try await client.fetchComments(feedbackID)
                            await send(.commentsResponse(.success(comments)))
                        } catch {
                            let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                            await send(.commentsResponse(.failure(appError)))
                        }
                    },
                    .run { send in
                        do {
                            let studyData = try await study.fetchStudy(studyID)
                            await send(.membersResponse(.success(studyData)))
                        } catch {
                            let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                            await send(.membersResponse(.failure(appError)))
                        }
                    }
                )

            case .commentsResponse(.success(let comments)):
                state.comments = .loaded(comments)
                return .none

            case .commentsResponse(.failure(let error)):
                state.comments = .failed(error)
                return .none

            case .membersResponse(.success(let study)):
                state.members = study.members
                return .none

            case .membersResponse(.failure):
                return .none

            case .commentTextChanged(let text):
                state.commentText = String(text.prefix(AppConstants.maxCommentLength))
                state.mentionedUserIDs = Self.syncMentionedUserIDs(
                    content: state.commentText,
                    members: state.members
                )

                if let atIndex = text.lastIndex(of: "@") {
                    let afterAt = text[text.index(after: atIndex)...]
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
                if let atIndex = state.commentText.lastIndex(of: "@") {
                    state.commentText = String(state.commentText[..<atIndex]) + "@\(member.userName) "
                }
                state.mentionedUserIDs = Self.syncMentionedUserIDs(
                    content: state.commentText,
                    members: state.members
                )
                state.showMentionSuggestions = false
                state.mentionQuery = ""
                return .none

            case .mentionAllTapped:
                if let atIndex = state.commentText.lastIndex(of: "@") {
                    state.commentText = String(state.commentText[..<atIndex]) + "@전체 "
                }
                state.mentionedUserIDs = Self.syncMentionedUserIDs(
                    content: state.commentText,
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
                state.error = nil
                let request = CreateFeedbackCommentRequest(
                    feedbackID: state.feedback.id,
                    content: state.commentText,
                    mentionedUserIDs: Array(state.mentionedUserIDs)
                )
                let client = commentClient
                return .run { send in
                    do {
                        let comment = try await client.createComment(request)
                        await send(.submitResponse(.success(comment)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.submitResponse(.failure(appError)))
                    }
                }

            case .submitResponse(.success(let comment)):
                state.isSubmitting = false
                state.commentText = ""
                state.mentionedUserIDs = []
                if case .loaded(var comments) = state.comments {
                    comments.append(comment)
                    state.comments = .loaded(comments)
                }
                return .none

            case .submitResponse(.failure(let error)):
                state.isSubmitting = false
                state.error = error
                return .none

            case .deleteCommentTapped(let comment):
                let commentID = comment.id
                let client = commentClient
                return .run { send in
                    do {
                        try await client.deleteComment(commentID)
                        await send(.deleteResponse(.success(commentID)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.deleteResponse(.failure(appError)))
                    }
                }

            case .deleteResponse(.success(let commentID)):
                if case .loaded(var comments) = state.comments {
                    comments.removeAll { $0.id == commentID }
                    state.comments = .loaded(comments)
                }
                return .none

            case .deleteResponse(.failure(let error)):
                state.error = error
                return .none
            }
        }
    }
}
