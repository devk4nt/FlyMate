import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct VideoUploadFeatureTests {
    private let studyID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    // MARK: - 입력값 변경

    @Test
    func 입력값_변경() async {
        let store = TestStore(initialState: VideoUploadFeature.State(studyID: studyID)) {
            VideoUploadFeature()
        }

        await store.send(.titleChanged("기내 방송 연습")) {
            $0.title = "기내 방송 연습"
        }
        await store.send(.focusPointsChanged("발음과 억양")) {
            $0.focusPoints = "발음과 억양"
        }
        await store.send(.feedbackRequestChanged("시선 처리 봐주세요")) {
            $0.feedbackRequest = "시선 처리 봐주세요"
        }
    }

    // MARK: - Duration 검증 (경계값: duration > 180 이면 거부, 정확히 180은 허용)

    @Test
    func 영상_선택_정확히_180초는_허용() async {
        let store = TestStore(initialState: VideoUploadFeature.State(studyID: studyID)) {
            VideoUploadFeature()
        }

        let videoData = Data([0x01])
        await store.send(.videoSelected(videoData, thumbnailData: nil, duration: 180)) {
            $0.selectedVideoData = videoData
            $0.videoDuration = 180
            $0.error = nil
        }
    }

    @Test
    func 영상_선택_180초_초과시_에러() async {
        let store = TestStore(initialState: VideoUploadFeature.State(studyID: studyID)) {
            VideoUploadFeature()
        }

        let videoData = Data([0x01])
        await store.send(.videoSelected(videoData, thumbnailData: nil, duration: 180.1)) {
            $0.selectedVideoData = videoData
            $0.videoDuration = 180.1
            $0.error = .business(.videoTooLong)
        }
    }

    @Test
    func 초과_영상_재선택시_에러_해제() async {
        var state = VideoUploadFeature.State(studyID: studyID)
        state.selectedVideoData = Data([0x01])
        state.videoDuration = 181
        state.error = .business(.videoTooLong)

        let store = TestStore(initialState: state) {
            VideoUploadFeature()
        }

        let shortVideoData = Data([0x02])
        await store.send(.videoSelected(shortVideoData, thumbnailData: nil, duration: 90)) {
            $0.selectedVideoData = shortVideoData
            $0.videoDuration = 90
            $0.error = nil
        }
    }

    @Test
    func 영상_처리_실패시_선택_초기화() async {
        var state = VideoUploadFeature.State(studyID: studyID)
        state.selectedVideoData = Data([0x01])
        state.selectedThumbnailData = Data([0x02])
        state.videoDuration = 90

        let store = TestStore(initialState: state) {
            VideoUploadFeature()
        }

        await store.send(.videoProcessingFailed(.unexpected("영상 처리 실패"))) {
            $0.error = .unexpected("영상 처리 실패")
            $0.selectedVideoData = nil
            $0.selectedThumbnailData = nil
            $0.videoDuration = 0
        }
    }

    // MARK: - 제출 가능 조건 (isValid)

    @Test
    func 제출_가능_조건_검증() {
        var state = VideoUploadFeature.State(studyID: studyID)

        // 초기 상태: 제출 불가
        #expect(!state.isValid)

        // 제목만 있고 영상 없음: 불가
        state.title = "기내 방송 연습"
        #expect(!state.isValid)

        // 제목 + 영상 + 180초 이하: 가능
        state.selectedVideoData = Data([0x01])
        state.videoDuration = 180
        #expect(state.isValid)

        // 180초 초과: 불가
        state.videoDuration = 180.1
        #expect(!state.isValid)

        // 공백 제목: 불가
        state.videoDuration = 90
        state.title = "   "
        #expect(!state.isValid)
    }

    @Test
    func 조건_미충족시_업로드_무시() async {
        let store = TestStore(initialState: VideoUploadFeature.State(studyID: studyID)) {
            VideoUploadFeature()
        }

        // isValid가 false이므로 상태 변경 없이 무시됨
        await store.send(.uploadTapped)
    }

    // MARK: - 업로드 플로우

    @Test
    func 업로드_성공() async {
        var state = VideoUploadFeature.State(studyID: studyID)
        state.title = "기내 방송 연습"
        state.focusPoints = "발음"
        state.selectedVideoData = Data([0x01])
        state.videoDuration = 120

        let capturedRequest = LockIsolated<UploadVideoRequest?>(nil)

        let store = TestStore(initialState: state) {
            VideoUploadFeature()
        } withDependencies: {
            $0.videoClient.uploadVideo = { request, _ in
                capturedRequest.setValue(request)
                return .mock
            }
        }

        await store.send(.uploadTapped) {
            $0.uploadState = .uploading
        }

        await store.receive(\.uploadResponse.success) {
            $0.uploadState = .completed
        }

        await store.receive(\.uploadCompleted)

        #expect(capturedRequest.value?.studyID == studyID)
        #expect(capturedRequest.value?.title == "기내 방송 연습")
        #expect(capturedRequest.value?.durationSeconds == 120)
        #expect(capturedRequest.value?.focusPoints == "발음")
        // 공백 feedbackRequest는 nil로 변환되어 전달
        #expect(capturedRequest.value?.feedbackRequest == nil)
    }

    @Test
    func 업로드_실패() async {
        var state = VideoUploadFeature.State(studyID: studyID)
        state.title = "기내 방송 연습"
        state.selectedVideoData = Data([0x01])
        state.videoDuration = 120

        let store = TestStore(initialState: state) {
            VideoUploadFeature()
        } withDependencies: {
            $0.videoClient.uploadVideo = { _, _ in
                throw AppError.network(.serverError(statusCode: 500))
            }
        }

        await store.send(.uploadTapped) {
            $0.uploadState = .uploading
        }

        await store.receive(\.uploadResponse.failure) {
            $0.uploadState = .failed(.network(.serverError(statusCode: 500)))
            $0.error = .network(.serverError(statusCode: 500))
        }
    }

    @Test
    func 업로드_진행률_업데이트() async {
        var state = VideoUploadFeature.State(studyID: studyID)
        state.uploadState = .uploading

        let store = TestStore(initialState: state) {
            VideoUploadFeature()
        }

        await store.send(.uploadProgressUpdated(0.5)) {
            $0.uploadProgress = 0.5
        }
        await store.send(.uploadProgressUpdated(1.0)) {
            $0.uploadProgress = 1.0
        }
    }

    @Test
    func 업로드_에러_해제시_상태_초기화() async {
        var state = VideoUploadFeature.State(studyID: studyID)
        state.uploadState = .failed(.network(.noConnection))
        state.uploadProgress = 0.3
        state.error = .network(.noConnection)

        let store = TestStore(initialState: state) {
            VideoUploadFeature()
        }

        await store.send(.dismissUploadError) {
            $0.uploadState = .idle
            $0.uploadProgress = 0
            $0.error = nil
        }
    }

    @Test
    func 취소시_화면_닫힘() async {
        let dismissed = LockIsolated(false)

        let store = TestStore(initialState: VideoUploadFeature.State(studyID: studyID)) {
            VideoUploadFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
        }

        await store.send(.cancelTapped)

        #expect(dismissed.value)
    }
}

// MARK: - Mock Data

private extension Video {
    static let mock = Video(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000200")!,
        studyID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        uploaderID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        uploaderName: "테스트 유저",
        title: "기내 방송 연습",
        videoURL: URL(string: "https://example.com/video.mp4")!,
        durationSeconds: 120,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
