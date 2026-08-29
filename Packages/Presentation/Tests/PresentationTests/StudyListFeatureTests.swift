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
            $0.studyClient.fetchMyJoinRequests = { [] }
        }

        // 병렬 조회 3건의 응답 순서는 비결정적 — 최종 상태만 검증
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.studies = .loading
            $0.quickFeedback = .loading
        }
        await store.finish()
        await store.skipReceivedActions()

        #expect(store.state.studies == .loaded(mockStudies))
        #expect(store.state.quickFeedback == .loaded(.mock))
    }

    @Test
    func 스터디_목록_로딩_실패() async {
        let store = TestStore(initialState: StudyListFeature.State()) {
            StudyListFeature()
        } withDependencies: {
            $0.studyClient.fetchMyStudies = { throw AppError.network(.noConnection) }
            $0.quickFeedbackClient.fetchDashboard = { .mock }
            $0.studyClient.fetchMyJoinRequests = { [] }
        }

        // 병렬 조회 3건의 응답 순서는 비결정적 — 최종 상태만 검증
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.studies = .loading
            $0.quickFeedback = .loading
        }
        await store.finish()
        await store.skipReceivedActions()

        #expect(store.state.studies == .failed(.network(.noConnection)))
        #expect(store.state.quickFeedback == .loaded(.mock))
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
        } withDependencies: {
            $0.studyClient.fetchMyJoinRequests = { [] }
        }

        // 시트를 닫고 방금 보낸 신청이 승인 대기 섹션에 보이도록 재조회한다
        await store.send(.joinStudy(.presented(.delegate(.joinRequested)))) {
            $0.joinStudy = nil
        }
        await store.receive(\.myJoinRequestsResponse.success)
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
            $0.studyClient.fetchMyJoinRequests = { [] }
        }

        // 병렬 조회 3건의 응답 순서는 비결정적 — 최종 상태만 검증
        store.exhaustivity = .off

        // 로드된 콘텐츠는 유지 — 스켈레톤으로 돌아가지 않는다
        await store.send(.refresh)
        await store.finish()
        await store.skipReceivedActions()

        #expect(store.state.studies == .loaded([Study.mock]))
        #expect(store.state.quickFeedback == .loaded(.mock))
    }

    @Test
    func 가입신청_철회_확인시_목록에서_제거_및_서버_호출() async {
        let request = JoinRequest(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000901")!,
            studyID: UUID(uuidString: "00000000-0000-0000-0000-000000000902")!,
            studyName: "승무원 영상면접 스터디",
            userID: UUID(uuidString: "00000000-0000-0000-0000-000000000903")!,
            userName: "박지원",
            status: .pending,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let canceledID = LockIsolated<UUID?>(nil)

        var state = StudyListFeature.State()
        state.myJoinRequests = [request]

        let store = TestStore(initialState: state) {
            StudyListFeature()
        } withDependencies: {
            $0.studyClient.cancelJoinRequest = { canceledID.setValue($0) }
        }

        await store.send(.cancelRequestTapped(request)) {
            $0.requestToCancel = request
            $0.cancelConfirmAlert = AlertState {
                TextState("가입 신청을 철회할까요?")
            } actions: {
                ButtonState(role: .destructive, action: .confirmCancel) {
                    TextState("철회")
                }
                ButtonState(role: .cancel) {
                    TextState("취소")
                }
            } message: {
                TextState("'승무원 영상면접 스터디' 가입 신청이 취소됩니다. 다시 신청하려면 초대 코드가 필요해요.")
            }
        }

        await store.send(.cancelConfirmAlert(.presented(.confirmCancel))) {
            $0.cancelConfirmAlert = nil
            $0.requestToCancel = nil
            $0.myJoinRequests = []
        }

        canceledID.withValue { #expect($0 == request.id) }
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
