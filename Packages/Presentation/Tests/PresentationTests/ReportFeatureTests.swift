import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core
@testable import Presentation

@MainActor
struct ReportFeatureTests {

    // MARK: - 중복 신고 확인

    @Test
    func onAppear_미신고_대상이면_상태_유지() async {
        let store = TestStore(
            initialState: ReportFeature.State(targetType: .feedback, targetID: .reportTargetMock)
        ) {
            ReportFeature()
        } withDependencies: {
            $0.reportClient.checkAlreadyReported = { _, _ in false }
        }

        await store.send(.onAppear)

        // alreadyReported 기본값이 false이므로 상태 변경 없음
        await store.receive(\.checkAlreadyReportedResponse)
    }

    @Test
    func onAppear_중복신고_감지시_alreadyReported_설정_및_delegate() async {
        let store = TestStore(
            initialState: ReportFeature.State(targetType: .feedback, targetID: .reportTargetMock)
        ) {
            ReportFeature()
        } withDependencies: {
            $0.reportClient.checkAlreadyReported = { _, _ in true }
        }

        await store.send(.onAppear)

        await store.receive(\.checkAlreadyReportedResponse) {
            $0.alreadyReported = true
        }

        await store.receive(\.delegate.alreadyReported)
    }

    @Test
    func 이미_신고된_상태에서는_canSubmit_false() {
        var state = ReportFeature.State(targetType: .user, targetID: .reportTargetMock)
        state.selectedReason = .spam
        state.alreadyReported = true

        #expect(state.canSubmit == false)
    }

    // MARK: - 사유 선택

    @Test
    func 사유_선택시_selectedReason_설정() async {
        let store = TestStore(
            initialState: ReportFeature.State(targetType: .feedback, targetID: .reportTargetMock)
        ) {
            ReportFeature()
        }

        await store.send(.reasonSelected(.harassment)) {
            $0.selectedReason = .harassment
        }

        #expect(store.state.canSubmit == true)
    }

    // MARK: - 제출

    @Test
    func 사유_미선택시_제출_무시() async {
        let store = TestStore(
            initialState: ReportFeature.State(targetType: .feedback, targetID: .reportTargetMock)
        ) {
            ReportFeature()
        }

        // selectedReason == nil이므로 상태 변경 없이 무시
        await store.send(.submitTapped)
    }

    @Test
    func 제출_성공시_delegate_reportSubmitted() async {
        let capturedRequest = LockIsolated<CreateReportRequest?>(nil)

        var state = ReportFeature.State(targetType: .feedback, targetID: .reportTargetMock)
        state.selectedReason = .spam

        let store = TestStore(initialState: state) {
            ReportFeature()
        } withDependencies: {
            $0.reportClient.createReport = { request in
                capturedRequest.setValue(request)
                return .reportMock
            }
        }

        await store.send(.binding(.set(\.detail, "부적절한 광고 내용입니다."))) {
            $0.detail = "부적절한 광고 내용입니다."
        }

        await store.send(.submitTapped) {
            $0.isSubmitting = true
        }

        await store.receive(\.submitResponse.success) {
            $0.isSubmitting = false
        }

        await store.receive(\.delegate.reportSubmitted)

        #expect(capturedRequest.value?.targetType == .feedback)
        #expect(capturedRequest.value?.targetID == .reportTargetMock)
        #expect(capturedRequest.value?.reason == .spam)
        #expect(capturedRequest.value?.detail == "부적절한 광고 내용입니다.")
    }

    @Test
    func 상세_maxReportDetailLength_초과시_잘려서_제출() async {
        let capturedRequest = LockIsolated<CreateReportRequest?>(nil)
        let longDetail = String(repeating: "가", count: AppConstants.maxReportDetailLength + 100)

        var state = ReportFeature.State(targetType: .feedback, targetID: .reportTargetMock)
        state.selectedReason = .other
        state.detail = longDetail

        let store = TestStore(initialState: state) {
            ReportFeature()
        } withDependencies: {
            $0.reportClient.createReport = { request in
                capturedRequest.setValue(request)
                return .reportMock
            }
        }

        await store.send(.submitTapped) {
            $0.isSubmitting = true
        }

        await store.receive(\.submitResponse.success) {
            $0.isSubmitting = false
        }

        await store.receive(\.delegate.reportSubmitted)

        #expect(capturedRequest.value?.detail?.count == AppConstants.maxReportDetailLength)
    }

    @Test
    func 상세_공백만_입력시_nil로_제출() async {
        let capturedRequest = LockIsolated<CreateReportRequest?>(nil)

        var state = ReportFeature.State(targetType: .user, targetID: .reportTargetMock)
        state.selectedReason = .misinformation
        state.detail = "   \n  "

        let store = TestStore(initialState: state) {
            ReportFeature()
        } withDependencies: {
            $0.reportClient.createReport = { request in
                capturedRequest.setValue(request)
                return .reportMock
            }
        }

        await store.send(.submitTapped) {
            $0.isSubmitting = true
        }

        await store.receive(\.submitResponse.success) {
            $0.isSubmitting = false
        }

        await store.receive(\.delegate.reportSubmitted)

        #expect(capturedRequest.value?.detail == nil)
    }

    @Test
    func 제출_실패시_isSubmitting_해제() async {
        var state = ReportFeature.State(targetType: .feedback, targetID: .reportTargetMock)
        state.selectedReason = .spam

        let store = TestStore(initialState: state) {
            ReportFeature()
        } withDependencies: {
            $0.reportClient.createReport = { _ in
                throw AppError.network(.serverError(statusCode: 500))
            }
        }

        await store.send(.submitTapped) {
            $0.isSubmitting = true
        }

        await store.receive(\.submitResponse.failure) {
            $0.isSubmitting = false
        }
    }
}

// MARK: - Mock Data

private extension UUID {
    static let reportTargetMock = UUID(uuidString: "00000000-0000-0000-0000-000000000100")!
    static let reporterMock = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
}

private extension Report {
    static let reportMock = Report(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000500")!,
        reporterID: .reporterMock,
        targetType: .feedback,
        targetID: .reportTargetMock,
        reason: .spam,
        detail: nil,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
