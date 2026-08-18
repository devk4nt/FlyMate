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
        pointBalance: 2,
        latestRequest: nil,
        availableRequests: [],
        receivedReviews: []
    )
}
