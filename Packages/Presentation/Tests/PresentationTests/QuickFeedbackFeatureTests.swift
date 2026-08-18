import Foundation
import Testing
import ComposableArchitecture
import Core
import Domain

@testable import Presentation

@MainActor
struct QuickFeedbackFeatureTests {
    @Test
    func 허브_진입시_포인트와_요청목록을_로드한다() async {
        let dashboard = QuickFeedbackDashboard(
            pointBalance: 2,
            latestRequest: nil,
            availableRequests: [.mock],
            receivedReviews: []
        )
        let store = TestStore(initialState: QuickFeedbackHubFeature.State()) {
            QuickFeedbackHubFeature()
        } withDependencies: {
            $0.quickFeedbackClient.fetchDashboard = { dashboard }
        }

        await store.send(.onAppear) {
            $0.dashboard = .loading
        }
        await store.receive(\.dashboardResponse.success) {
            $0.dashboard = .loaded(dashboard)
        }
    }

    @Test
    func 피드백_시작시_배정된_영상의_작성화면을_표시한다() async {
        let claimed = ClaimedQuickFeedback(assignmentID: UUID(900), request: .mock)
        var state = QuickFeedbackHubFeature.State()
        state.dashboard = .loaded(QuickFeedbackDashboard(
            pointBalance: 2,
            latestRequest: nil,
            availableRequests: [.mock],
            receivedReviews: []
        ))
        let store = TestStore(initialState: state) {
            QuickFeedbackHubFeature()
        } withDependencies: {
            $0.quickFeedbackClient.claim = { _ in claimed }
        }

        await store.send(.startFeedbackTapped) {
            $0.isClaiming = true
        }
        await store.receive(\.claimResponse.success) {
            $0.isClaiming = false
            $0.review = QuickFeedbackReviewFeature.State(claimed: claimed)
        }
    }

    @Test
    func 내_요청_기록을_누르면_영상과_해당_답변을_표시한다() async {
        let review = QuickFeedbackReview(
            id: UUID(910), requestID: QuickFeedbackRequest.mock.id,
            reviewerID: UUID(911), reviewerName: "리뷰어",
            positiveText: "표정이 자연스럽고 답변의 시작이 명확해서 집중하기 좋았어요.",
            improvementText: "마지막 문장의 속도를 조금 늦추면 핵심이 더 잘 전달될 것 같아요.",
            focusArea: .overall, createdAt: Date()
        )
        var state = QuickFeedbackHubFeature.State()
        state.dashboard = .loaded(QuickFeedbackDashboard(
            pointBalance: 2,
            myRequests: [.mock],
            availableRequests: [],
            receivedReviews: [review]
        ))
        let store = TestStore(initialState: state) {
            QuickFeedbackHubFeature()
        }

        await store.send(.requestHistoryTapped(QuickFeedbackRequest.mock.id)) {
            $0.requestDetail = QuickFeedbackRequestDetailFeature.State(
                request: .mock,
                reviews: [review]
            )
        }
    }

    @Test
    func 받은_빠른피드백의_리뷰어_프로필을_누르면_활동내역을_표시한다() async {
        let review = QuickFeedbackReview(
            id: UUID(912), requestID: QuickFeedbackRequest.mock.id,
            reviewerID: UUID(913), reviewerName: "리뷰어",
            reviewerProfileURL: URL(string: "https://example.com/reviewer.jpg"),
            positiveText: "표정이 자연스럽고 답변의 시작이 명확해서 집중하기 좋았어요.",
            improvementText: "마지막 문장의 속도를 조금 늦추면 핵심이 더 잘 전달될 것 같아요.",
            focusArea: .overall, createdAt: Date()
        )
        let store = TestStore(
            initialState: QuickFeedbackRequestDetailFeature.State(
                request: .mock,
                reviews: [review]
            )
        ) {
            QuickFeedbackRequestDetailFeature()
        }

        await store.send(.reviewerProfileTapped(review)) {
            $0.userActivity = MyActivityFeature.State(
                userID: review.reviewerID,
                userName: review.reviewerName,
                profileImageURL: review.reviewerProfileURL
            )
        }
    }

    @Test
    func 배정영상의_업로더_프로필을_누르면_활동내역을_표시한다() async {
        let claimed = ClaimedQuickFeedback(assignmentID: UUID(914), request: .mock)
        let store = TestStore(initialState: QuickFeedbackReviewFeature.State(claimed: claimed)) {
            QuickFeedbackReviewFeature()
        }

        await store.send(.uploaderProfileTapped) {
            $0.userActivity = MyActivityFeature.State(
                userID: claimed.request.uploaderID,
                userName: claimed.request.uploaderName,
                profileImageURL: claimed.request.uploaderProfileURL
            )
        }
    }

    @Test
    func 구조화된_피드백_제출시_완료를_전달한다() async {
        let claimed = ClaimedQuickFeedback(assignmentID: UUID(901), request: .mock)
        let positive = "첫 문장부터 표정과 목소리가 밝아서 답변에 자연스럽게 집중할 수 있었어요."
        let improvement = "마지막 문장에서 시선이 아래로 향하니 카메라 렌즈를 조금 더 오래 바라보면 좋아요."
        let review = QuickFeedbackReview(
            id: UUID(902), requestID: claimed.request.id, reviewerID: UUID(903),
            reviewerName: "리뷰어", positiveText: positive, improvementText: improvement,
            focusArea: .expression, createdAt: Date()
        )
        let store = TestStore(initialState: QuickFeedbackReviewFeature.State(claimed: claimed)) {
            QuickFeedbackReviewFeature()
        } withDependencies: {
            $0.quickFeedbackClient.submitReview = { request in
                #expect(request.assignmentID == claimed.assignmentID)
                return review
            }
        }

        await store.send(.positiveTextChanged(positive)) { $0.positiveText = positive }
        await store.send(.improvementTextChanged(improvement)) { $0.improvementText = improvement }
        await store.send(.submitTapped) { $0.isSubmitting = true }
        await store.receive(\.submitResponse.success) { $0.isSubmitting = false }
        await store.receive(\.delegate.submitted)
    }

    @Test
    func 빠른_피드백_영상은_60초를_초과하면_업로드할수없다() async {
        let store = TestStore(
            initialState: VideoUploadFeature.State(destination: .quickFeedback)
        ) {
            VideoUploadFeature()
        }

        await store.send(.videoSelected(Data([1]), thumbnailData: nil, duration: 61)) {
            $0.selectedVideoData = Data([1])
            $0.videoDuration = 61
            $0.error = .business(.quickFeedbackVideoTooLong)
        }
        #expect(store.state.isValid == false)
    }
}

private extension QuickFeedbackRequest {
    static let mock = QuickFeedbackRequest(
        id: UUID(800),
        uploaderID: UUID(801),
        uploaderName: "김하늘",
        uploaderProfileURL: URL(string: "https://example.com/uploader.jpg"),
        title: "1분 자기소개 연습",
        videoURL: URL(string: "https://example.com/video.mp4"),
        durationSeconds: 50,
        focusArea: .expression,
        feedbackRequest: "시선과 미소가 자연스러운지 봐주세요.",
        status: .open,
        feedbackCount: 0,
        targetFeedbackCount: 2,
        expiresAt: Date().addingTimeInterval(3_600),
        createdAt: Date()
    )
}

private extension UUID {
    init(_ suffix: Int) {
        self.init(uuid: (
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0,
            UInt8((suffix >> 8) & 0xff), UInt8(suffix & 0xff)
        ))
    }
}
