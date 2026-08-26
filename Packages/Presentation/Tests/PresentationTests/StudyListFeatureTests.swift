import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct StudyListFeatureTests {
    @Test
    func 스터디_목록_로딩_성공() async {
        let mockStudies = [Study.mock]

        let store = TestStore(initialState: StudyListFeature.State()) {
            StudyListFeature()
        } withDependencies: {
            $0.studyClient.fetchMyStudies = { mockStudies }
            $0.quickFeedbackClient.fetchDashboard = { .mock }
        }

        await store.send(.onAppear) {
            $0.studies = .loading
            $0.quickFeedback = .loading
        }
        await store.receive(\.studiesResponse.success) {
            $0.studies = .loaded(mockStudies)
        }
        await store.receive(\.quickFeedbackResponse.success) {
            $0.quickFeedback = .loaded(.mock)
        }
    }

    @Test
    func 스터디_목록_로딩_실패() async {
        let store = TestStore(initialState: StudyListFeature.State()) {
            StudyListFeature()
        } withDependencies: {
            $0.studyClient.fetchMyStudies = { throw AppError.network(.noConnection) }
            $0.quickFeedbackClient.fetchDashboard = { .mock }
        }

        await store.send(.onAppear) {
            $0.studies = .loading
            $0.quickFeedback = .loading
        }
        await store.receive(\.studiesResponse.failure) {
            $0.studies = .failed(.network(.noConnection))
        }
        await store.receive(\.quickFeedbackResponse.success) {
            $0.quickFeedback = .loaded(.mock)
        }
    }

    @Test
    func 스터디_생성_시트_표시() async {
        let store = TestStore(initialState: StudyListFeature.State()) {
            StudyListFeature()
        }

        await store.send(.createStudyTapped) {
            $0.createStudy = StudyCreateFeature.State()
        }
    }

    @Test
    func 참여_시트_표시() async {
        let store = TestStore(initialState: StudyListFeature.State()) {
            StudyListFeature()
        }

        await store.send(.joinStudyTapped) {
            $0.joinStudy = JoinStudyFeature.State()
        }
    }

    @Test
    func 초대코드로_참여_시트_프리필() async {
        let store = TestStore(initialState: StudyListFeature.State()) {
            StudyListFeature()
        }

        await store.send(.showJoinStudy(inviteCode: "TEST01")) {
            $0.joinStudy = JoinStudyFeature.State(inviteCode: "TEST01")
        }
    }

    @Test
    func 참여_신청시_시트_닫힘() async {
        var state = StudyListFeature.State()
        state.joinStudy = JoinStudyFeature.State(inviteCode: "ABC123")

        let store = TestStore(initialState: state) {
            StudyListFeature()
        }

        // 참여 신청은 방장 승인 대기 상태이므로 목록 새로고침 없이 시트만 닫는다
        await store.send(.joinStudy(.presented(.delegate(.joinRequested)))) {
            $0.joinStudy = nil
        }
    }

    @Test
    func 첫_요청_전에만_첫_업로드_유도_모드() {
        var state = StudyListFeature.State()

        // 로딩 전에는 유도 모드 아님
        #expect(state.awaitingFirstUpload == false)

        // 요청 이력이 없으면 유도 모드
        state.quickFeedback = .loaded(.mock)
        #expect(state.awaitingFirstUpload == true)

        // 요청 이력이 생기면 유도 모드 해제
        state.quickFeedback = .loaded(QuickFeedbackDashboard(
            latestRequest: .mock,
            availableRequests: [],
            receivedReviews: []
        ))
        #expect(state.awaitingFirstUpload == false)
    }

    @Test
    func 새로고침시_목록_다시_로딩() async {
        var state = StudyListFeature.State()
        state.studies = .loaded([Study.mock])

        let store = TestStore(initialState: state) {
            StudyListFeature()
        } withDependencies: {
            $0.studyClient.fetchMyStudies = { [Study.mock] }
            $0.quickFeedbackClient.fetchDashboard = { .mock }
        }

        // 로드된 콘텐츠는 유지 — 스켈레톤으로 돌아가지 않는다
        await store.send(.refresh)
        await store.receive(\.studiesResponse.success)
        await store.receive(\.quickFeedbackResponse.success) {
            $0.quickFeedback = .loaded(.mock)
        }
    }
}

// Study.mock은 FeedbackWriteFeatureTests.swift의 공용 정의를 사용한다

private extension QuickFeedbackDashboard {
    static let mock = QuickFeedbackDashboard(
        latestRequest: nil,
        availableRequests: [],
        receivedReviews: []
    )
}

private extension QuickFeedbackRequest {
    static let mock = QuickFeedbackRequest(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000800")!,
        uploaderID: UUID(uuidString: "00000000-0000-0000-0000-000000000801")!,
        uploaderName: "김하늘",
        uploaderProfileURL: nil,
        title: "1분 자기소개 연습",
        videoURL: nil,
        durationSeconds: 50,
        focusArea: .expression,
        feedbackRequest: "시선과 미소가 자연스러운지 봐주세요.",
        status: .open,
        feedbackCount: 0,
        targetFeedbackCount: 2,
        expiresAt: Date(timeIntervalSince1970: 1_700_003_600),
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
