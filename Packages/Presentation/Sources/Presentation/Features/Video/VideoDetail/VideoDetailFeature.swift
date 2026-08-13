import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct VideoDetailFeature {
    @ObservableState
    public struct State: Equatable, Identifiable {
        public var id: UUID { video.id }
        public var video: Video
        public var feedbacks: LoadingState<[Feedback]> = .idle
        public var player = VideoPlayerState()
        public var focusedFeedbackID: UUID?
        public var latestComments: [UUID: FeedbackComment] = [:]
        public var currentUserID: UUID?
        public var commentInput: CommentInputFeature.State
        public var expandedFeedbackIDs: Set<UUID> = []
        public var repliesByFeedback: [UUID: LoadingState<[FeedbackComment]>] = [:]
        public var showToast = false
        public var toastMessage = ""
        public var toastType: FMToast.ToastType = .success
        public var showFeedbackSheet = false
        @Presents public var feedbackCommentList: FeedbackCommentListFeature.State?
        @Presents public var report: ReportFeature.State?
        @Presents public var blockAlert: AlertState<Action.BlockAlert>?

        public init(video: Video, focusedFeedbackID: UUID? = nil, currentUserID: UUID? = nil) {
            self.video = video
            self.focusedFeedbackID = focusedFeedbackID
            self.currentUserID = currentUserID
            self.commentInput = CommentInputFeature.State(videoID: video.id)
            // 딥링크로 특정 피드백에 진입한 경우 시트를 바로 연다
            self.showFeedbackSheet = focusedFeedbackID != nil
        }

        /// 내가 이 영상에 피드백을 남겼는가 — 저장 없이 로드된 피드백에서 유도
        public var hasMyFeedback: Bool {
            guard let currentUserID, case .loaded(let feedbacks) = feedbacks else { return false }
            return feedbacks.contains { $0.authorID == currentUserID }
        }
    }

    public struct VideoPlayerState: Equatable {
        public var isPlaying = false
        public var currentTime: TimeInterval = 0
        public var duration: TimeInterval = 0
        public var isSeeking = false
        public var isMuted = false
    }

    public enum Action {
        case onAppear
        case onDisappear
        case feedbacksResponse(Result<[Feedback], AppError>)
        case feedbacksUpdated([Feedback])
        case clearFocusedFeedback
        case membersResponse(Result<Study, AppError>)
        case toastDismissed
        // Player actions
        case playPauseTapped
        case play
        case pause
        case seek(to: TimeInterval)
        case seekCompleted
        case currentTimeUpdated(TimeInterval)
        case durationUpdated(TimeInterval)
        case playerReachedEnd
        case muteTapped
        // Feedback sheet
        case feedbackSheetTapped
        case feedbackSheetDismissed
        // Feedback actions
        case feedbackTapped(Feedback)
        // Comment input
        case commentInput(CommentInputFeature.Action)
        case replyTapped(Feedback)
        case toggleRepliesTapped(Feedback)
        case repliesResponse(feedbackID: UUID, Result<[FeedbackComment], AppError>)
        case deleteReplyTapped(FeedbackComment)
        case deleteReplyResponse(feedbackID: UUID, Result<UUID, AppError>)
        // Comment list sheet (fallback)
        case latestCommentsResponse(Result<[UUID: FeedbackComment], AppError>)
        case commentListTapped(Feedback)
        case feedbackCommentList(PresentationAction<FeedbackCommentListFeature.Action>)
        // 신고 / 차단
        case reportUserTapped(authorID: UUID)
        case report(PresentationAction<ReportFeature.Action>)
        case blockUserTapped(authorID: UUID, authorName: String)
        case blockAlert(PresentationAction<BlockAlert>)
        case blockResponse(Result<UUID, AppError>)

        public enum BlockAlert: Equatable {
            case confirmBlock(userID: UUID)
        }
    }

    /// 피드에서 페이지별 인스턴스가 공존하므로 영상 단위로 스트림 구독을 취소한다
    private struct RealtimeCancelID: Hashable {
        let videoID: UUID
    }

    @Dependency(\.feedbackClient) private var feedbackClient
    @Dependency(\.feedbackCommentClient) private var feedbackCommentClient
    @Dependency(\.studyClient) private var studyClient
    @Dependency(\.blockClient) private var blockClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.commentInput, action: \.commentInput) {
            CommentInputFeature()
        }

        Reduce { state, action in
            switch action {
            case .onAppear:
                let videoID = state.video.id
                let studyID = state.video.studyID
                // 재진입(하위 화면 pop, 시트 닫힘) 시 기존 목록을 유지한 채 조용히 갱신
                if case .loaded = state.feedbacks {} else {
                    state.feedbacks = .loading
                }
                state.player.duration = state.video.durationSeconds
                let client = feedbackClient
                let study = studyClient
                return .merge(
                    .run { send in
                        do {
                            let feedbacks = try await client.fetchFeedbacks(videoID)
                            await send(.feedbacksResponse(.success(feedbacks)))
                        } catch {
                            let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                            await send(.feedbacksResponse(.failure(appError)))
                        }
                    },
                    .run { send in
                        for await feedbacks in client.observeFeedbacks(videoID) {
                            await send(.feedbacksUpdated(feedbacks))
                        }
                    }
                    .cancellable(id: RealtimeCancelID(videoID: videoID)),
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

            case .onDisappear:
                state.player.isPlaying = false
                state.showFeedbackSheet = false
                return .cancel(id: RealtimeCancelID(videoID: state.video.id))

            case .membersResponse(.success(let study)):
                state.commentInput.members = study.members
                return .none

            case .membersResponse(.failure):
                return .none

            case .toastDismissed:
                state.showToast = false
                return .none

            case .feedbacksResponse(.success(let feedbacks)):
                state.feedbacks = .loaded(feedbacks)
                let commentClient = feedbackCommentClient
                let feedbackIDs = feedbacks.map(\.id)
                let seekEffect: Effect<Action>
                if let focusedID = state.focusedFeedbackID,
                   let feedback = feedbacks.first(where: { $0.id == focusedID }) {
                    seekEffect = .merge(
                        .send(.seek(to: feedback.timestampSeconds)),
                        .run { send in
                            try await Task.sleep(for: .seconds(2))
                            await send(.clearFocusedFeedback)
                        }
                    )
                } else {
                    seekEffect = .none
                }
                return .merge(
                    seekEffect,
                    .run { send in
                        do {
                            let latest = try await commentClient.fetchLatestComments(feedbackIDs)
                            await send(.latestCommentsResponse(.success(latest)))
                        } catch {
                            let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                            await send(.latestCommentsResponse(.failure(appError)))
                        }
                    }
                )

            case .feedbacksResponse(.failure(let error)):
                state.feedbacks = .failed(error)
                return .none

            case .feedbacksUpdated(let feedbacks):
                state.feedbacks = .loaded(feedbacks)
                let commentClient = feedbackCommentClient
                let feedbackIDs = feedbacks.map(\.id)
                return .run { send in
                    do {
                        let latest = try await commentClient.fetchLatestComments(feedbackIDs)
                        await send(.latestCommentsResponse(.success(latest)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.latestCommentsResponse(.failure(appError)))
                    }
                }

            case .latestCommentsResponse(.success(let comments)):
                state.latestComments = comments
                return .none

            case .latestCommentsResponse(.failure):
                return .none

            case .clearFocusedFeedback:
                state.focusedFeedbackID = nil
                return .none

            // MARK: - Player

            case .playPauseTapped:
                if state.player.isPlaying {
                    return .send(.pause)
                } else {
                    return .send(.play)
                }

            case .play:
                state.player.isPlaying = true
                return .none

            case .pause:
                state.player.isPlaying = false
                return .none

            case .seek(let time):
                state.player.isSeeking = true
                state.player.currentTime = time
                return .none

            case .seekCompleted:
                state.player.isSeeking = false
                return .none

            case .currentTimeUpdated(let time):
                guard !state.player.isSeeking else { return .none }
                state.player.currentTime = time
                return .none

            case .durationUpdated(let duration):
                state.player.duration = duration
                return .none

            case .playerReachedEnd:
                state.player.isPlaying = false
                state.player.currentTime = 0
                return .none

            case .muteTapped:
                state.player.isMuted.toggle()
                return .none

            case .feedbackSheetTapped:
                state.showFeedbackSheet = true
                // 시트를 연 순간의 초수에서 정지 — currentTime이 고정되어
                // 피드백이 해당 시점에 달린다
                state.player.isPlaying = false
                return .none

            case .feedbackSheetDismissed:
                state.showFeedbackSheet = false
                return .none

            // MARK: - Feedback

            case .feedbackTapped(let feedback):
                return .send(.seek(to: feedback.timestampSeconds))

            // MARK: - Comment Input Delegate

            case .commentInput(.delegate(.feedbackCreated(let feedback))):
                if case .loaded(var feedbacks) = state.feedbacks {
                    feedbacks.insert(feedback, at: 0)
                    state.feedbacks = .loaded(feedbacks)
                }
                // 토스트
                state.showToast = true
                state.toastMessage = "댓글이 등록되었습니다"
                state.toastType = .success
                // 스크롤 포커스 + 하이라이트
                state.focusedFeedbackID = feedback.id
                return .run { send in
                    try await Task.sleep(for: .seconds(2))
                    await send(.clearFocusedFeedback)
                }

            case .commentInput(.delegate(.commentCreated(let comment, let feedbackID))):
                // 낙관적 삽입: repliesByFeedback에 추가
                if case .loaded(var comments) = state.repliesByFeedback[feedbackID] {
                    comments.append(comment)
                    state.repliesByFeedback[feedbackID] = .loaded(comments)
                } else {
                    // 답글을 아직 펼친 적 없으면 새로 생성
                    state.repliesByFeedback[feedbackID] = .loaded([comment])
                }
                // latestComments 갱신
                state.latestComments[feedbackID] = comment
                // commentCount 갱신 (feedbacks 내 해당 항목)
                if case .loaded(var feedbacks) = state.feedbacks,
                   let index = feedbacks.firstIndex(where: { $0.id == feedbackID }) {
                    let old = feedbacks[index]
                    feedbacks[index] = Feedback(
                        id: old.id,
                        videoID: old.videoID,
                        studyID: old.studyID,
                        authorID: old.authorID,
                        authorName: old.authorName,
                        authorProfileURL: old.authorProfileURL,
                        content: old.content,
                        timestampSeconds: old.timestampSeconds,
                        createdAt: old.createdAt,
                        mentionedUserIDs: old.mentionedUserIDs,
                        commentCount: old.commentCount + 1
                    )
                    state.feedbacks = .loaded(feedbacks)
                }
                // 토스트
                state.showToast = true
                state.toastMessage = "답글이 등록되었습니다"
                state.toastType = .success
                // 자동으로 답글 확장
                state.expandedFeedbackIDs.insert(feedbackID)
                // 스크롤 포커스
                state.focusedFeedbackID = feedbackID
                return .run { send in
                    try await Task.sleep(for: .seconds(2))
                    await send(.clearFocusedFeedback)
                }

            case .commentInput(.feedbackSubmitResponse(.failure(let error))):
                state.showToast = true
                state.toastMessage = error.localizedDescription
                state.toastType = .error
                return .none

            case .commentInput(.commentSubmitResponse(.failure(let error))):
                state.showToast = true
                state.toastMessage = error.localizedDescription
                state.toastType = .error
                return .none

            case .commentInput:
                return .none

            // MARK: - Reply

            case .replyTapped(let feedback):
                return .send(.commentInput(.enterReplyMode(
                    feedbackID: feedback.id,
                    authorName: feedback.authorName
                )))

            case .toggleRepliesTapped(let feedback):
                let feedbackID = feedback.id
                if state.expandedFeedbackIDs.contains(feedbackID) {
                    state.expandedFeedbackIDs.remove(feedbackID)
                } else {
                    state.expandedFeedbackIDs.insert(feedbackID)
                    // 로드 완료 상태가 아니면 fetch — 실패했거나 요청이 중단된 채 남은 상태도 재시도한다
                    if case .loaded = state.repliesByFeedback[feedbackID] {} else {
                        state.repliesByFeedback[feedbackID] = .loading
                        let client = feedbackCommentClient
                        return .run { send in
                            do {
                                let comments = try await client.fetchComments(feedbackID)
                                await send(.repliesResponse(feedbackID: feedbackID, .success(comments)))
                            } catch {
                                let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                                await send(.repliesResponse(feedbackID: feedbackID, .failure(appError)))
                            }
                        }
                    }
                }
                return .none

            case .repliesResponse(let feedbackID, .success(let comments)):
                state.repliesByFeedback[feedbackID] = .loaded(comments)
                return .none

            case .repliesResponse(let feedbackID, .failure(let error)):
                state.repliesByFeedback[feedbackID] = .failed(error)
                return .none

            case .deleteReplyTapped(let comment):
                let commentID = comment.id
                let feedbackID = comment.feedbackID
                let client = feedbackCommentClient
                return .run { send in
                    do {
                        try await client.deleteComment(commentID)
                        await send(.deleteReplyResponse(feedbackID: feedbackID, .success(commentID)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.deleteReplyResponse(feedbackID: feedbackID, .failure(appError)))
                    }
                }

            case .deleteReplyResponse(let feedbackID, .success(let commentID)):
                if case .loaded(var comments) = state.repliesByFeedback[feedbackID] {
                    comments.removeAll { $0.id == commentID }
                    state.repliesByFeedback[feedbackID] = .loaded(comments)
                }
                // commentCount 감소
                if case .loaded(var feedbacks) = state.feedbacks,
                   let index = feedbacks.firstIndex(where: { $0.id == feedbackID }) {
                    let old = feedbacks[index]
                    feedbacks[index] = Feedback(
                        id: old.id,
                        videoID: old.videoID,
                        studyID: old.studyID,
                        authorID: old.authorID,
                        authorName: old.authorName,
                        authorProfileURL: old.authorProfileURL,
                        content: old.content,
                        timestampSeconds: old.timestampSeconds,
                        createdAt: old.createdAt,
                        mentionedUserIDs: old.mentionedUserIDs,
                        commentCount: max(0, old.commentCount - 1)
                    )
                    state.feedbacks = .loaded(feedbacks)
                }
                return .none

            case .deleteReplyResponse(_, .failure):
                return .none

            // MARK: - Comment List Sheet (fallback)

            case .commentListTapped(let feedback):
                state.feedbackCommentList = FeedbackCommentListFeature.State(
                    feedback: feedback,
                    studyID: state.video.studyID,
                    currentUserID: state.currentUserID
                )
                return .none

            case .feedbackCommentList:
                return .none

            // MARK: - Report / Block

            case .reportUserTapped(let authorID):
                state.report = ReportFeature.State(targetType: .user, targetID: authorID)
                return .none

            case .report(.presented(.delegate(.reportSubmitted))):
                state.report = nil
                state.showToast = true
                state.toastMessage = "신고가 접수되었습니다"
                state.toastType = .success
                return .none

            case .report(.presented(.delegate(.alreadyReported))):
                state.report = nil
                state.showToast = true
                state.toastMessage = "이미 신고한 항목입니다"
                state.toastType = .info
                return .none

            case .report:
                return .none

            case .blockUserTapped(let authorID, let authorName):
                state.blockAlert = AlertState {
                    TextState("\(authorName)님을 차단할까요?")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmBlock(userID: authorID)) {
                        TextState("차단하기")
                    }
                    ButtonState(role: .cancel) {
                        TextState("취소")
                    }
                } message: {
                    TextState("차단한 사용자의 영상과 피드백이 더 이상 보이지 않아요. 설정 > 차단한 사용자에서 해제할 수 있어요.")
                }
                return .none

            case .blockAlert(.presented(.confirmBlock(let userID))):
                let client = blockClient
                return .run { send in
                    do {
                        try await client.blockUser(userID)
                        await send(.blockResponse(.success(userID)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.blockResponse(.failure(appError)))
                    }
                }

            case .blockAlert:
                return .none

            case .blockResponse(.success(let userID)):
                // 차단한 사용자의 콘텐츠를 화면에서 즉시 제거 (이후 조회는 서버 RLS가 필터)
                if case .loaded(var feedbacks) = state.feedbacks {
                    feedbacks.removeAll { $0.authorID == userID }
                    state.feedbacks = .loaded(feedbacks)
                }
                for (feedbackID, replies) in state.repliesByFeedback {
                    if case .loaded(var comments) = replies {
                        comments.removeAll { $0.authorID == userID }
                        state.repliesByFeedback[feedbackID] = .loaded(comments)
                    }
                }
                state.latestComments = state.latestComments.filter { $0.value.authorID != userID }
                state.showToast = true
                state.toastMessage = "사용자를 차단했습니다"
                state.toastType = .success
                return .none

            case .blockResponse(.failure(let error)):
                state.showToast = true
                state.toastMessage = error.localizedDescription
                state.toastType = .error
                return .none
            }
        }
        .ifLet(\.$feedbackCommentList, action: \.feedbackCommentList) {
            FeedbackCommentListFeature()
        }
        .ifLet(\.$report, action: \.report) {
            ReportFeature()
        }
        .ifLet(\.$blockAlert, action: \.blockAlert)
    }
}
