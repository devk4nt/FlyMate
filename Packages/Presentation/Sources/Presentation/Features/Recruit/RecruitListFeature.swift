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
        case createTapped
        case recruitingOnlyToggled
        case fieldFilterSelected(RecruitField?)
        case meetingTypeFilterSelected(RecruitMeetingType?)
        case detail(PresentationAction<RecruitDetailFeature.Action>)
        case create(PresentationAction<RecruitCreateFeature.Action>)
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
                state.toastMessage = "모집 글이 등록되었습니다"
                state.showToast = true
                return .none

            case .detail(.presented(.delegate(.postUpdated(let post)))):
                if let index = state.posts.items.firstIndex(where: { $0.id == post.id }) {
                    state.posts.items[index] = post
                    state.loadingState = .loaded(state.posts.items)
                }
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

            case .detail, .create:
                return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) {
            RecruitDetailFeature()
        }
        .ifLet(\.$create, action: \.create) {
            RecruitCreateFeature()
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
