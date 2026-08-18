import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct RecruitDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public var post: RecruitPost
        public let currentUserID: UUID
        public var comments: LoadingState<[RecruitComment]> = .idle
        public var commentText = ""
        public var replyTarget: RecruitComment?
        public var isSubmittingComment = false
        /// 댓글 등록 직후 해당 댓글로 스크롤하기 위한 타깃
        public var scrollToCommentID: UUID?
        public var isProcessing = false
        public var showDeleteAlert = false
        public var showCloseAlert = false
        public var showReopenSheet = false
        // reopenTapped에서 항상 재설정 — 고정 기본값으로 테스트 결정성 확보
        public var reopenDeadline = Date(timeIntervalSince1970: 0)
        @Presents public var report: ReportFeature.State?
        @Presents public var edit: RecruitCreateFeature.State?
        @Presents public var createStudy: StudyCreateFeature.State?
        @Presents public var userActivity: MyActivityFeature.State?
        @Presents public var blockAlert: AlertState<Action.BlockAlert>?
        public var showToast = false
        public var toastMessage = ""

        public init(post: RecruitPost, currentUserID: UUID) {
            self.post = post
            self.currentUserID = currentUserID
        }

        public var isAuthor: Bool { post.authorID == currentUserID }

        public var isCommentValid: Bool {
            !commentText.isBlank && commentText.count <= AppConstants.maxRecruitCommentLength
        }

        public var interestedUserCount: Int {
            guard case .loaded(let comments) = comments else { return post.commentCount }
            return Set(comments.lazy.filter { $0.authorID != currentUserID }.map(\.authorID)).count
        }
    }

    public enum Action {
        case onAppear
        case refresh
        case postResponse(Result<RecruitPost, AppError>)
        case commentsResponse(Result<[RecruitComment], AppError>)
        // 댓글
        case commentTextChanged(String)
        case replyTapped(RecruitComment)
        case replyCancelled
        case submitCommentTapped
        case submitCommentResponse(Result<RecruitComment, AppError>)
        case deleteCommentTapped(RecruitComment)
        case deleteCommentResponse(Result<UUID, AppError>)
        // 작성자 액션
        case editTapped
        case createStudyTapped
        case createStudy(PresentationAction<StudyCreateFeature.Action>)
        case linkStudyResponse(Result<RecruitPost, AppError>)
        case closeTapped
        case closeConfirmed
        case closeCancelled
        case reopenTapped
        case reopenDeadlineChanged(Date)
        case reopenConfirmed
        case reopenDismissed
        case statusResponse(Result<RecruitPost, AppError>)
        case deleteTapped
        case deleteConfirmed
        case deleteCancelled
        case deleteResponse(Result<UUID, AppError>)
        // 신고 / 차단
        case reportPostTapped
        case authorProfileTapped
        case reportCommentTapped(RecruitComment)
        case report(PresentationAction<ReportFeature.Action>)
        case userActivity(PresentationAction<MyActivityFeature.Action>)
        case blockUserTapped(authorID: UUID, authorName: String)
        case blockAlert(PresentationAction<BlockAlert>)
        case blockResponse(Result<UUID, AppError>)
        case edit(PresentationAction<RecruitCreateFeature.Action>)
        case toastDismissed
        case delegate(Delegate)

        public enum BlockAlert: Equatable {
            case confirmBlock(userID: UUID, userName: String)
        }

        @CasePathable
        public enum Delegate: Equatable {
            case postUpdated(RecruitPost)
            case postDeleted(UUID)
            case userBlocked(UUID)
        }
    }

    @Dependency(\.recruitClient) private var recruitClient
    @Dependency(\.blockClient) private var blockClient
    @Dependency(\.date.now) private var now

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard case .idle = state.comments else { return .none }
                state.comments = .loading
                return .merge(fetchComments(postID: state.post.id), fetchPost(id: state.post.id))

            case .refresh:
                return .merge(fetchComments(postID: state.post.id), fetchPost(id: state.post.id))

            case .postResponse(.success(let post)):
                state.post = post
                return .send(.delegate(.postUpdated(post)))

            case .postResponse(.failure):
                // 목록에서 받은 스냅샷으로 계속 표시
                return .none

            case .commentsResponse(.success(let comments)):
                state.comments = .loaded(comments)
                return .none

            case .commentsResponse(.failure(let error)):
                state.comments = .failed(error)
                return .none

            case .commentTextChanged(let text):
                state.commentText = String(text.prefix(AppConstants.maxRecruitCommentLength))
                return .none

            case .replyTapped(let comment):
                // 대댓글은 1단계까지 — 대댓글에 답글 시 원 댓글에 달림
                state.replyTarget = comment.isReply
                    ? state.comments.value?.first { $0.id == comment.parentID } ?? comment
                    : comment
                return .none

            case .replyCancelled:
                state.replyTarget = nil
                return .none

            case .submitCommentTapped:
                guard state.isCommentValid, !state.isSubmittingComment else { return .none }
                state.isSubmittingComment = true
                let request = CreateRecruitCommentRequest(
                    postID: state.post.id,
                    parentID: state.replyTarget?.id,
                    content: state.commentText
                )
                let client = recruitClient
                return .run { send in
                    do {
                        let comment = try await client.createComment(request)
                        await send(.submitCommentResponse(.success(comment)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.submitCommentResponse(.failure(appError)))
                    }
                }

            case .submitCommentResponse(.success(let comment)):
                state.isSubmittingComment = false
                state.commentText = ""
                state.replyTarget = nil
                var comments = state.comments.value ?? []
                comments.append(comment)
                state.comments = .loaded(comments)
                state.scrollToCommentID = comment.id
                state.post = state.post.withCommentCount(state.post.commentCount + 1)
                return .send(.delegate(.postUpdated(state.post)))

            case .submitCommentResponse(.failure(let error)):
                // 실패 시 입력 내용 유지
                state.isSubmittingComment = false
                state.toastMessage = error.localizedDescription
                state.showToast = true
                return .none

            case .deleteCommentTapped(let comment):
                let client = recruitClient
                return .run { send in
                    do {
                        try await client.deleteComment(comment.id)
                        await send(.deleteCommentResponse(.success(comment.id)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.deleteCommentResponse(.failure(appError)))
                    }
                }

            case .deleteCommentResponse(.success(let commentID)):
                var comments = state.comments.value ?? []
                let removedCount = comments.count
                comments.removeAll { $0.id == commentID || $0.parentID == commentID }
                state.comments = .loaded(comments)
                state.post = state.post.withCommentCount(
                    max(0, state.post.commentCount - (removedCount - comments.count))
                )
                return .send(.delegate(.postUpdated(state.post)))

            case .deleteCommentResponse(.failure(let error)):
                state.toastMessage = error.localizedDescription
                state.showToast = true
                return .none

            case .editTapped:
                state.edit = RecruitCreateFeature.State(mode: .edit(state.post))
                return .none

            case .createStudyTapped:
                guard state.isAuthor, state.post.studyID == nil else { return .none }
                state.createStudy = StudyCreateFeature.State(recruitPost: state.post)
                return .none

            case .createStudy(.presented(.studyCreated(let study))):
                let client = recruitClient
                let postID = state.post.id
                return .run { send in
                    do {
                        let post = try await client.linkStudy(postID, study.id)
                        await send(.linkStudyResponse(.success(post)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.linkStudyResponse(.failure(appError)))
                    }
                }

            case .linkStudyResponse(.success(let post)):
                state.post = post
                state.toastMessage = "모집 글과 스터디방이 연결되었습니다"
                state.showToast = true
                return .send(.delegate(.postUpdated(post)))

            case .linkStudyResponse(.failure):
                state.toastMessage = "스터디방은 만들어졌지만 모집 글 연결에 실패했습니다"
                state.showToast = true
                return .none

            case .edit(.presented(.delegate(.saved(let post)))):
                state.post = post
                return .send(.delegate(.postUpdated(post)))

            case .closeTapped:
                state.showCloseAlert = true
                return .none

            case .closeCancelled:
                state.showCloseAlert = false
                return .none

            case .closeConfirmed:
                state.showCloseAlert = false
                state.isProcessing = true
                let client = recruitClient
                let postID = state.post.id
                return .run { send in
                    await send(.statusResponse(mapResult { try await client.closePost(postID) }))
                }

            case .reopenTapped:
                state.reopenDeadline = now.addingTimeInterval(7 * 86_400)
                state.showReopenSheet = true
                return .none

            case .reopenDeadlineChanged(let date):
                state.reopenDeadline = date
                return .none

            case .reopenDismissed:
                state.showReopenSheet = false
                return .none

            case .reopenConfirmed:
                state.showReopenSheet = false
                state.isProcessing = true
                let client = recruitClient
                let postID = state.post.id
                let deadline = state.reopenDeadline
                return .run { send in
                    await send(.statusResponse(mapResult { try await client.reopenPost(postID, deadline) }))
                }

            case .statusResponse(.success(let post)):
                state.isProcessing = false
                state.post = post
                state.toastMessage = post.status == .closed ? "모집을 마감했습니다" : "모집을 재개했습니다"
                state.showToast = true
                return .send(.delegate(.postUpdated(post)))

            case .statusResponse(.failure(let error)):
                state.isProcessing = false
                state.toastMessage = error.localizedDescription
                state.showToast = true
                return .none

            case .deleteTapped:
                state.showDeleteAlert = true
                return .none

            case .deleteCancelled:
                state.showDeleteAlert = false
                return .none

            case .deleteConfirmed:
                state.showDeleteAlert = false
                state.isProcessing = true
                let client = recruitClient
                let postID = state.post.id
                return .run { send in
                    do {
                        try await client.deletePost(postID)
                        await send(.deleteResponse(.success(postID)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.deleteResponse(.failure(appError)))
                    }
                }

            case .deleteResponse(.success(let postID)):
                state.isProcessing = false
                return .send(.delegate(.postDeleted(postID)))

            case .deleteResponse(.failure(let error)):
                state.isProcessing = false
                state.toastMessage = error.localizedDescription
                state.showToast = true
                return .none

            case .reportPostTapped:
                state.report = ReportFeature.State(targetType: .recruitPost, targetID: state.post.id)
                return .none

            case .authorProfileTapped:
                state.userActivity = MyActivityFeature.State(
                    userID: state.post.authorID,
                    userName: state.post.authorName,
                    profileImageURL: state.post.authorProfileURL
                )
                return .none

            case .reportCommentTapped(let comment):
                state.report = ReportFeature.State(targetType: .recruitComment, targetID: comment.id)
                return .none

            case .blockUserTapped(let authorID, let authorName):
                state.blockAlert = AlertState {
                    TextState("\(authorName)님을 차단할까요?")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmBlock(userID: authorID, userName: authorName)) {
                        TextState("차단하기")
                    }
                    ButtonState(role: .cancel) {
                        TextState("취소")
                    }
                } message: {
                    TextState("차단한 사용자의 모집 글과 댓글이 더 이상 보이지 않아요. 설정 > 차단한 사용자에서 해제할 수 있어요.")
                }
                return .none

            case .blockAlert(.presented(.confirmBlock(let userID, let userName))):
                let client = blockClient
                return .run { send in
                    do {
                        try await client.blockUser(userID, userName)
                        await send(.blockResponse(.success(userID)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.blockResponse(.failure(appError)))
                    }
                }

            case .blockAlert:
                return .none

            case .blockResponse(.success(let userID)):
                // 차단한 사용자의 댓글을 화면에서 즉시 제거 (이후 조회는 서버 RLS가 필터)
                if case .loaded(var comments) = state.comments {
                    comments.removeAll { $0.authorID == userID }
                    state.comments = .loaded(comments)
                }
                return .send(.delegate(.userBlocked(userID)))

            case .blockResponse(.failure(let error)):
                state.toastMessage = error.localizedDescription
                state.showToast = true
                return .none

            case .report(.presented(.delegate(.reportSubmitted))):
                state.report = nil
                state.toastMessage = "신고가 접수되었습니다"
                state.showToast = true
                return .none

            case .report(.presented(.delegate(.alreadyReported))):
                state.report = nil
                state.toastMessage = "이미 신고한 콘텐츠입니다"
                state.showToast = true
                return .none

            case .toastDismissed:
                state.showToast = false
                return .none

            case .report, .edit, .createStudy, .userActivity, .delegate:
                return .none
            }
        }
        .ifLet(\.$report, action: \.report) {
            ReportFeature()
        }
        .ifLet(\.$edit, action: \.edit) {
            RecruitCreateFeature()
        }
        .ifLet(\.$createStudy, action: \.createStudy) {
            StudyCreateFeature()
        }
        .ifLet(\.$userActivity, action: \.userActivity) {
            MyActivityFeature()
        }
        .ifLet(\.$blockAlert, action: \.blockAlert)
    }

    private func fetchComments(postID: UUID) -> Effect<Action> {
        let client = recruitClient
        return .run { send in
            do {
                let comments = try await client.fetchComments(postID)
                await send(.commentsResponse(.success(comments)))
            } catch {
                let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                await send(.commentsResponse(.failure(appError)))
            }
        }
    }

    private func fetchPost(id: UUID) -> Effect<Action> {
        let client = recruitClient
        return .run { send in
            do {
                let post = try await client.fetchPost(id)
                await send(.postResponse(.success(post)))
            } catch {
                let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                await send(.postResponse(.failure(appError)))
            }
        }
    }
}

private func mapResult(
    _ operation: @Sendable () async throws -> RecruitPost
) async -> Result<RecruitPost, AppError> {
    do {
        return .success(try await operation())
    } catch {
        return .failure(error as? AppError ?? .unexpected(error.localizedDescription))
    }
}

private extension RecruitPost {
    func withCommentCount(_ count: Int) -> RecruitPost {
        RecruitPost(
            id: id,
            title: title,
            description: description,
            field: field,
            meetingType: meetingType,
            region: region,
            schedule: schedule,
            startDate: startDate,
            endDate: endDate,
            maxMembers: maxMembers,
            deadline: deadline,
            requirement: requirement,
            contactMethod: contactMethod,
            linkURL: linkURL,
            studyID: studyID,
            authorID: authorID,
            authorName: authorName,
            authorProfileURL: authorProfileURL,
            status: status,
            commentCount: count,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
