import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct VideoUploadFeature {
    @ObservableState
    public struct State: Equatable {
        public let studyID: UUID
        public var title = ""
        public var focusPoints = ""
        public var feedbackRequest = ""
        public var selectedVideoData: Data?
        public var selectedThumbnailData: Data?
        public var videoDuration: TimeInterval = 0
        public var uploadProgress: Double = 0
        public var uploadState: UploadState = .idle
        public var error: AppError?

        public init(studyID: UUID) {
            self.studyID = studyID
        }

        public var isValid: Bool {
            !title.isBlank
                && selectedVideoData != nil
                && videoDuration <= AppConstants.maxVideoDurationSeconds
        }

        public enum UploadState: Equatable {
            case idle
            case uploading
            case completed
            case failed(AppError)
        }
    }

    public enum Action: Equatable {
        case titleChanged(String)
        case focusPointsChanged(String)
        case feedbackRequestChanged(String)
        case videoSelected(Data, thumbnailData: Data?, duration: TimeInterval)
        case videoProcessingFailed(AppError)
        case uploadTapped
        case uploadProgressUpdated(Double)
        case uploadResponse(Result<Video, AppError>)
        case uploadCompleted
        case cancelTapped
        case dismissUploadError
    }

    @Dependency(\.videoClient) private var videoClient
    @Dependency(\.dismiss) private var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .titleChanged(let title):
                state.title = title
                return .none

            case .focusPointsChanged(let text):
                state.focusPoints = text
                return .none

            case .feedbackRequestChanged(let text):
                state.feedbackRequest = text
                return .none

            case .videoSelected(let data, let thumbnailData, let duration):
                state.selectedVideoData = data
                state.selectedThumbnailData = thumbnailData
                state.videoDuration = duration
                if duration > AppConstants.maxVideoDurationSeconds {
                    state.error = .business(.videoTooLong)
                } else {
                    state.error = nil
                }
                return .none

            case .videoProcessingFailed(let error):
                state.error = error
                state.selectedVideoData = nil
                state.selectedThumbnailData = nil
                state.videoDuration = 0
                return .none

            case .uploadTapped:
                guard state.isValid, let videoData = state.selectedVideoData else { return .none }
                state.uploadState = .uploading
                let request = UploadVideoRequest(
                    studyID: state.studyID,
                    title: state.title,
                    videoData: videoData,
                    thumbnailData: state.selectedThumbnailData,
                    durationSeconds: state.videoDuration,
                    focusPoints: state.focusPoints.isBlank ? nil : state.focusPoints,
                    feedbackRequest: state.feedbackRequest.isBlank ? nil : state.feedbackRequest
                )
                let client = videoClient
                return .run { send in
                    do {
                        let video = try await client.uploadVideo(request) { progress in
                            Task { @MainActor in
                                send(.uploadProgressUpdated(progress))
                            }
                        }
                        await send(.uploadResponse(.success(video)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.uploadResponse(.failure(appError)))
                    }
                }

            case .uploadProgressUpdated(let progress):
                state.uploadProgress = progress
                return .none

            case .uploadResponse(.success):
                state.uploadState = .completed
                return .send(.uploadCompleted)

            case .uploadResponse(.failure(let error)):
                state.uploadState = .failed(error)
                state.error = error
                return .none

            case .uploadCompleted:
                return .none // Handled by parent

            case .cancelTapped:
                let dismiss = dismiss
                return .run { _ in await dismiss() }

            case .dismissUploadError:
                state.uploadState = .idle
                state.uploadProgress = 0
                state.error = nil
                return .none
            }
        }
    }
}
