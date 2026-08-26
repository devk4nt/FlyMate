import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct VideoUploadFeature {
    @ObservableState
    public struct State: Equatable {
        public let destination: Destination
        public var title = ""
        public var focusPoints = ""
        public var feedbackRequest = ""
        public var quickFeedbackFocusArea: QuickFeedbackFocusArea = .overall
        public var selectedVideoData: Data?
        public var selectedThumbnailData: Data?
        public var videoDuration: TimeInterval = 0
        public var uploadProgress: Double = 0
        public var uploadState: UploadState = .idle
        public var error: AppError?

        public init(studyID: UUID) {
            self.destination = .study(studyID)
        }

        public init(destination: Destination) {
            self.destination = destination
        }

        public var isValid: Bool {
            !title.isBlank
                && selectedVideoData != nil
                && videoDuration <= maximumDuration
        }

        public var isQuickFeedback: Bool {
            destination == .quickFeedback
        }

        public var maximumDuration: TimeInterval {
            isQuickFeedback
                ? AppConstants.maxQuickFeedbackVideoDurationSeconds
                : AppConstants.maxVideoDurationSeconds
        }

        public enum Destination: Equatable {
            case study(UUID)
            case quickFeedback
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
        case quickFeedbackFocusAreaSelected(QuickFeedbackFocusArea)
        case videoSelected(Data, thumbnailData: Data?, duration: TimeInterval)
        case videoProcessingFailed(AppError)
        case uploadTapped
        case uploadProgressUpdated(Double)
        case uploadResponse(Result<Video, AppError>)
        case quickFeedbackUploadResponse(Result<QuickFeedbackRequest, AppError>)
        case uploadCompleted
        case cancelTapped
        case dismissUploadError
    }

    @Dependency(\.videoClient) private var videoClient
    @Dependency(\.quickFeedbackClient) private var quickFeedbackClient
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

            case .quickFeedbackFocusAreaSelected(let focusArea):
                state.quickFeedbackFocusArea = focusArea
                return .none

            case .videoSelected(let data, let thumbnailData, let duration):
                state.selectedVideoData = data
                state.selectedThumbnailData = thumbnailData
                state.videoDuration = duration
                if duration > state.maximumDuration {
                    state.error = .business(
                        state.destination == .quickFeedback
                            ? .quickFeedbackVideoTooLong
                            : .videoTooLong
                    )
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
                if state.isQuickFeedback {
                    let request = UploadQuickFeedbackRequest(
                        title: state.title,
                        videoData: videoData,
                        thumbnailData: state.selectedThumbnailData,
                        durationSeconds: state.videoDuration,
                        focusArea: state.quickFeedbackFocusArea,
                        feedbackRequest: state.feedbackRequest.isBlank ? nil : state.feedbackRequest
                    )
                    let client = quickFeedbackClient
                    return .run { send in
                        do {
                            let result = try await client.upload(request) { progress in
                                Task { @MainActor in
                                    send(.uploadProgressUpdated(progress))
                                }
                            }
                            await send(.quickFeedbackUploadResponse(.success(result)))
                        } catch {
                            let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                            await send(.quickFeedbackUploadResponse(.failure(appError)))
                        }
                    }
                }
                guard case .study(let studyID) = state.destination else { return .none }
                let request = UploadVideoRequest(
                    studyID: studyID,
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

            case .quickFeedbackUploadResponse(.success):
                state.uploadState = .completed
                return .send(.uploadCompleted)

            case .uploadResponse(.failure(let error)),
                 .quickFeedbackUploadResponse(.failure(let error)):
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
