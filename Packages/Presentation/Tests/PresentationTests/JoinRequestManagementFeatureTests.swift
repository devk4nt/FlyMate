import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct JoinRequestManagementFeatureTests {
    private nonisolated static let studyID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private nonisolated static let pendingRequests: [JoinRequest] = [
        JoinRequest(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000051")!,
            studyID: studyID,
            studyName: "iOS 면접 스터디",
            userID: UUID(uuidString: "00000000-0000-0000-0000-000000000030")!,
            userName: "김지원",
            status: .pending,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        ),
        JoinRequest(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000052")!,
            studyID: studyID,
            studyName: "iOS 면접 스터디",
            userID: UUID(uuidString: "00000000-0000-0000-0000-000000000031")!,
            userName: "이수현",
            status: .pending,
            createdAt: Date(timeIntervalSince1970: 1_700_001_000)
        ),
    ]

    @Test
    func 요청_목록_조회_성공() async {
        let store = TestStore(
            initialState: JoinRequestManagementFeature.State(studyID: Self.studyID)
        ) {
            JoinRequestManagementFeature()
        } withDependencies: {
            $0.studyClient.fetchPendingRequests = { _ in Self.pendingRequests }
        }

        await store.send(.onAppear) {
            $0.requests = .loading
        }

        await store.receive(\.requestsResponse.success) {
            $0.requests = .loaded(Self.pendingRequests)
        }
    }

    @Test
    func 요청_목록_조회_실패() async {
        let error = AppError.business(.unauthorized)

        let store = TestStore(
            initialState: JoinRequestManagementFeature.State(studyID: Self.studyID)
        ) {
            JoinRequestManagementFeature()
        } withDependencies: {
            $0.studyClient.fetchPendingRequests = { _ in throw error }
        }

        await store.send(.onAppear) {
            $0.requests = .loading
        }

        await store.receive(\.requestsResponse.failure) {
            $0.requests = .failed(error)
        }
    }

    @Test
    func 승인_성공() async {
        let request = Self.pendingRequests[0]

        var state = JoinRequestManagementFeature.State(studyID: Self.studyID)
        state.requests = .loaded(Self.pendingRequests)

        let store = TestStore(initialState: state) {
            JoinRequestManagementFeature()
        } withDependencies: {
            $0.studyClient.approveJoinRequest = { _ in }
        }

        await store.send(.approveTapped(request)) {
            $0.actionInProgress.insert(request.id)
        }

        await store.receive(\.approveResponse) {
            $0.actionInProgress.remove(request.id)
            $0.requests = .loaded([Self.pendingRequests[1]])
        }

        await store.receive(\.delegate.memberApproved)
    }

    @Test
    func 승인_실패_인원_초과() async {
        let request = Self.pendingRequests[0]
        let error = AppError.business(.studyFull)

        var state = JoinRequestManagementFeature.State(studyID: Self.studyID)
        state.requests = .loaded(Self.pendingRequests)

        let store = TestStore(initialState: state) {
            JoinRequestManagementFeature()
        } withDependencies: {
            $0.studyClient.approveJoinRequest = { _ in throw error }
        }

        await store.send(.approveTapped(request)) {
            $0.actionInProgress.insert(request.id)
        }

        await store.receive(\.approveResponse) {
            $0.actionInProgress.remove(request.id)
        }
    }

    @Test
    func 거절_확인후_성공() async {
        let request = Self.pendingRequests[0]

        var state = JoinRequestManagementFeature.State(studyID: Self.studyID)
        state.requests = .loaded(Self.pendingRequests)

        let store = TestStore(initialState: state) {
            JoinRequestManagementFeature()
        } withDependencies: {
            $0.studyClient.rejectJoinRequest = { _ in }
        }

        await store.send(.rejectTapped(request)) {
            $0.selectedRequest = request
            $0.confirmAlert = AlertState {
                TextState("참여 요청 거절")
            } actions: {
                ButtonState(role: .destructive, action: .confirmReject) {
                    TextState("거절")
                }
                ButtonState(role: .cancel) {
                    TextState("취소")
                }
            } message: {
                TextState("\(request.userName)님의 참여 요청을 거절하시겠습니까?\n거절 후 다시 요청할 수 있습니다.")
            }
        }

        await store.send(.confirmAlert(.presented(.confirmReject))) {
            $0.selectedRequest = nil
            $0.confirmAlert = nil
            $0.actionInProgress.insert(request.id)
        }

        await store.receive(\.rejectResponse) {
            $0.actionInProgress.remove(request.id)
            $0.requests = .loaded([Self.pendingRequests[1]])
        }
    }
}
