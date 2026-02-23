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
        public var currentUserID: UUID?
        public var isEditingNotice: Bool = false
        public var editingNoticeText: String = ""
        public var noticeUpdateState: LoadingState<Bool> = .idle

        public var isOwner: Bool {
            guard let currentUserID else { return false }
            return study.ownerID == currentUserID
        }

        public init(study: Study, currentUserID: UUID? = nil) {
            self.study = study
            self.currentUserID = currentUserID
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
        case memberManagementTapped
        // Notice
        case noticeTapped
        case editNoticeTapped
        case editingNoticeTextChanged(String)
        case saveNoticeTapped
        case deleteNoticeTapped
        case dismissNoticeEditor
        case noticeUpdateResponse(Result<Bool, AppError>)
    }

    @Dependency(\.videoClient) private var videoClient
    @Dependency(\.studyClient) private var studyClient

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

            case .videoTapped, .uploadVideoTapped, .copyInviteCode, .memberManagementTapped:
                return .none // Handled by parent

            // MARK: - Notice

            case .noticeTapped:
                guard state.isOwner else { return .none }
                state.editingNoticeText = state.study.notice ?? ""
                state.isEditingNotice = true
                return .none

            case .editNoticeTapped:
                state.editingNoticeText = state.study.notice ?? ""
                state.isEditingNotice = true
                return .none

            case .editingNoticeTextChanged(let text):
                state.editingNoticeText = text
                return .none

            case .saveNoticeTapped:
                let text = state.editingNoticeText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return .none }
                state.noticeUpdateState = .loading
                let studyID = state.study.id
                let client = studyClient
                return .run { send in
                    do {
                        try await client.updateNotice(studyID, text)
                        await send(.noticeUpdateResponse(.success(true)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.noticeUpdateResponse(.failure(appError)))
                    }
                }

            case .deleteNoticeTapped:
                state.noticeUpdateState = .loading
                let studyID = state.study.id
                let client = studyClient
                return .run { send in
                    do {
                        try await client.updateNotice(studyID, nil)
                        await send(.noticeUpdateResponse(.success(false)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.noticeUpdateResponse(.failure(appError)))
                    }
                }

            case .dismissNoticeEditor:
                state.isEditingNotice = false
                state.editingNoticeText = ""
                state.noticeUpdateState = .idle
                return .none

            case .noticeUpdateResponse(.success(let isSave)):
                if isSave {
                    state.study.notice = state.editingNoticeText.trimmingCharacters(in: .whitespacesAndNewlines)
                    state.study.noticeUpdatedAt = Date()
                } else {
                    state.study.notice = nil
                    state.study.noticeUpdatedAt = nil
                }
                state.noticeUpdateState = .idle
                state.isEditingNotice = false
                state.editingNoticeText = ""
                return .none

            case .noticeUpdateResponse(.failure(let error)):
                state.noticeUpdateState = .failed(error)
                return .none
            }
        }
    }
}
