import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct StudyDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public var study: Study
        public var videos: LoadingState<[Video]> = .idle
        public var videosPagination = PaginatedState<Video>()

        public init(study: Study) {
            self.study = study
        }
    }

    public enum Action {
        case onAppear
        case refresh
        case videosResponse(Result<[Video], AppError>)
        case loadMoreVideos
        case loadMoreResponse(Result<[Video], AppError>)
        case videoTapped(Video)
        case uploadVideoTapped(studyID: UUID)
        case copyInviteCode
    }

    @Dependency(\.videoClient) private var videoClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard case .idle = state.videos else { return .none }
                state.videos = .loading
                let studyID = state.study.id
                let client = videoClient
                return .run { send in
                    do {
                        let videos = try await client.fetchVideos(studyID, nil)
                        await send(.videosResponse(.success(videos)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.videosResponse(.failure(appError)))
                    }
                }

            case .refresh:
                state.videos = .loading
                let studyID = state.study.id
                let client = videoClient
                return .run { send in
                    do {
                        let videos = try await client.fetchVideos(studyID, nil)
                        await send(.videosResponse(.success(videos)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.videosResponse(.failure(appError)))
                    }
                }

            case .videosResponse(.success(let videos)):
                state.videos = .loaded(videos)
                state.videosPagination.items = videos
                state.videosPagination.cursor = videos.last?.createdAt
                state.videosPagination.hasMore = videos.count >= AppConstants.defaultPageSize
                return .none

            case .videosResponse(.failure(let error)):
                state.videos = .failed(error)
                return .none

            case .loadMoreVideos:
                guard !state.videosPagination.isLoadingMore,
                      state.videosPagination.hasMore else { return .none }
                state.videosPagination.isLoadingMore = true
                let studyID = state.study.id
                let cursor = state.videosPagination.cursor
                let client = videoClient
                return .run { send in
                    do {
                        let videos = try await client.fetchVideos(studyID, cursor)
                        await send(.loadMoreResponse(.success(videos)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.loadMoreResponse(.failure(appError)))
                    }
                }

            case .loadMoreResponse(.success(let newVideos)):
                state.videosPagination.isLoadingMore = false
                state.videosPagination.items.append(contentsOf: newVideos)
                state.videosPagination.cursor = newVideos.last?.createdAt
                state.videosPagination.hasMore = newVideos.count >= AppConstants.defaultPageSize
                state.videos = .loaded(state.videosPagination.items)
                return .none

            case .loadMoreResponse(.failure):
                state.videosPagination.isLoadingMore = false
                return .none

            case .videoTapped, .uploadVideoTapped, .copyInviteCode:
                return .none // Handled by parent
            }
        }
    }
}
