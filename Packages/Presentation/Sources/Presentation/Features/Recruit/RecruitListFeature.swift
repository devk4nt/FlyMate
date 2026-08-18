import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct RecruitListFeature {
    @ObservableState
    public struct State: Equatable {
        public let currentUserID: UUID
        public var posts = PaginatedState<RecruitPost>()
        public var loadingState: LoadingState<[RecruitPost]> = .idle
        public var filter = RecruitPostFilter()
        @Presents public var detail: RecruitDetailFeature.State?
        @Presents public var create: RecruitCreateFeature.State?
        @Presents public var createStudy: StudyCreateFeature.State?
        @Presents public var userActivity: MyActivityFeature.State?
        public var showToast = false
        public var toastMessage = ""

        public init(currentUserID: UUID) {
            self.currentUserID = currentUserID
        }
    }

    public enum Action {
        case onAppear
        case refresh
        case postsResponse(Result<[RecruitPost], AppError>)
        case loadMore
        case loadMoreResponse(Result<[RecruitPost], AppError>)
        case postTapped(RecruitPost)
        case authorProfileTapped(RecruitPost)
        case createTapped
        case recruitingOnlyToggled
        case fieldFilterSelected(RecruitField?)
        case meetingTypeFilterSelected(RecruitMeetingType?)
        case detail(PresentationAction<RecruitDetailFeature.Action>)
        case create(PresentationAction<RecruitCreateFeature.Action>)
        case createStudy(PresentationAction<StudyCreateFeature.Action>)
        case userActivity(PresentationAction<MyActivityFeature.Action>)
        case linkStudyResponse(Result<RecruitPost, AppError>)
        case toastDismissed
    }

    @Dependency(\.recruitClient) private var recruitClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard case .idle = state.loadingState else { return .none }
                state.loadingState = .loading
                return fetchPosts(filter: state.filter, cursor: nil)

            case .refresh:
                // 로드된 콘텐츠는 유지 — pull-to-refresh 시 스켈레톤 대신 .refreshable 스피너가 로딩 표시
                if state.loadingState.value == nil { state.loadingState = .loading }
                return fetchPosts(filter: state.filter, cursor: nil)

            case .postsResponse(.success(let posts)):
                state.posts.items = posts
                state.posts.cursor = posts.last?.createdAt
                state.posts.hasMore = posts.count >= AppConstants.defaultPageSize
                state.loadingState = .loaded(posts)
                return .none

            case .postsResponse(.failure(let error)):
                state.loadingState = .failed(error)
                return .none

            case .loadMore:
                guard !state.posts.isLoadingMore, state.posts.hasMore else { return .none }
                state.posts.isLoadingMore = true
                return fetchPosts(filter: state.filter, cursor: state.posts.cursor, isLoadMore: true)

            case .loadMoreResponse(.success(let newPosts)):
                state.posts.isLoadingMore = false
                state.posts.items.append(contentsOf: newPosts)
                state.posts.cursor = newPosts.last?.createdAt
                state.posts.hasMore = newPosts.count >= AppConstants.defaultPageSize
                state.loadingState = .loaded(state.posts.items)
                return .none

            case .loadMoreResponse(.failure):
                state.posts.isLoadingMore = false
                return .none

            case .postTapped(let post):
                state.detail = RecruitDetailFeature.State(
                    post: post,
                    currentUserID: state.currentUserID
                )
                return .none

            case .authorProfileTapped(let post):
                state.userActivity = MyActivityFeature.State(
                    userID: post.authorID,
                    userName: post.authorName,
                    profileImageURL: post.authorProfileURL
                )
                return .none

            case .createTapped:
                state.create = RecruitCreateFeature.State(mode: .create)
                return .none

            case .recruitingOnlyToggled:
                state.filter.recruitingOnly.toggle()
                return .send(.refresh)

            case .fieldFilterSelected(let field):
                state.filter.field = field
                return .send(.refresh)

            case .meetingTypeFilterSelected(let meetingType):
                state.filter.meetingType = meetingType
                return .send(.refresh)

            case .create(.presented(.delegate(.saved(let post)))):
                state.posts.items.insert(post, at: 0)
                state.loadingState = .loaded(state.posts.items)
                state.create = nil
                state.createStudy = StudyCreateFeature.State(recruitPost: post)
                return .none

            case .createStudy(.presented(.studyCreated(let study))):
                guard let postID = state.createStudy?.recruitPostID else { return .none }
                let client = recruitClient
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
                if let index = state.posts.items.firstIndex(where: { $0.id == post.id }) {
                    state.posts.items[index] = post
                    state.loadingState = .loaded(state.posts.items)
                }
                state.toastMessage = "모집 글과 스터디방이 준비되었습니다"
                state.showToast = true
                return .none

            case .linkStudyResponse(.failure):
                state.toastMessage = "스터디방은 만들어졌지만 모집 글 연결에 실패했습니다"
                state.showToast = true
                return .none

            case .detail(.presented(.delegate(.postUpdated(let post)))):
                if let index = state.posts.items.firstIndex(where: { $0.id == post.id }) {
                    state.posts.items[index] = post
                    state.loadingState = .loaded(state.posts.items)
                }
                return .none

            case .detail(.presented(.delegate(.userBlocked(let userID)))):
                // 차단한 사용자의 모집 글을 목록에서 즉시 제거하고, 그 사용자의 글이면 상세를 닫는다
                if state.detail?.post.authorID == userID {
                    state.detail = nil
                }
                state.posts.items.removeAll { $0.authorID == userID }
                state.loadingState = .loaded(state.posts.items)
                state.toastMessage = "사용자를 차단했습니다"
                state.showToast = true
                return .none

            case .detail(.presented(.delegate(.postDeleted(let postID)))):
                state.posts.items.removeAll { $0.id == postID }
                state.loadingState = .loaded(state.posts.items)
                state.detail = nil
                state.toastMessage = "모집 글이 삭제되었습니다"
                state.showToast = true
                return .none

            case .toastDismissed:
                state.showToast = false
                return .none

            case .detail, .create, .createStudy, .userActivity:
                return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) {
            RecruitDetailFeature()
        }
        .ifLet(\.$create, action: \.create) {
            RecruitCreateFeature()
        }
        .ifLet(\.$createStudy, action: \.createStudy) {
            StudyCreateFeature()
        }
        .ifLet(\.$userActivity, action: \.userActivity) {
            MyActivityFeature()
        }
    }

    private func fetchPosts(
        filter: RecruitPostFilter,
        cursor: Date?,
        isLoadMore: Bool = false
    ) -> Effect<Action> {
        let client = recruitClient
        return .run { send in
            do {
                let posts = try await client.fetchPosts(filter, cursor)
                if isLoadMore {
                    await send(.loadMoreResponse(.success(posts)))
                } else {
                    await send(.postsResponse(.success(posts)))
                }
            } catch {
                let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                if isLoadMore {
                    await send(.loadMoreResponse(.failure(appError)))
                } else {
                    await send(.postsResponse(.failure(appError)))
                }
            }
        }
    }
}
