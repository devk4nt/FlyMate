import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct VideoDetailFeature {
    @ObservableState
    public struct State: Equatable {
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
        @Presents public var feedbackCommentList: FeedbackCommentListFeature.State?

        public init(video: Video, focusedFeedbackID: UUID? = nil, currentUserID: UUID? = nil) {
            self.video = video
            self.focusedFeedbackID = focusedFeedbackID
            self.currentUserID = currentUserID
            self.commentInput = CommentInputFeature.State(videoID: video.id)
        }
    }

    public struct VideoPlayerState: Equatable {
        public var isPlaying = false
        public var currentTime: TimeInterval = 0
        public var duration: TimeInterval = 0
        public var isSeeking = false
        public var isMuted = false
        public var isFullscreen = false
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
        case fullscreenTapped
        case dismissFullscreen
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
    }

    private enum CancelID { case realtimeFeedback }

    @Dependency(\.feedbackClient) private var feedbackClient
    @Dependency(\.feedbackCommentClient) private var feedbackCommentClient
    @Dependency(\.studyClient) private var studyClient

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
                state.feedbacks = .loading
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
                    .cancellable(id: CancelID.realtimeFeedback),
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
                return .cancel(id: CancelID.realtimeFeedback)

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

            case .fullscreenTapped:
                state.player.isFullscreen = true
                return .none

            case .dismissFullscreen:
                state.player.isFullscreen = false
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
                    // 미로딩 시 fetch
                    if state.repliesByFeedback[feedbackID] == nil {
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
            }
        }
        .ifLet(\.$feedbackCommentList, action: \.feedbackCommentList) {
            FeedbackCommentListFeature()
        }
    }
}
