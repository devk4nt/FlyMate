import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct StudyManagementFeatureTests {
    @Test
    func 재진입_시_스켈레톤_재노출_방지() async {
        let mockStudies = [Study.mock]

        let store = TestStore(initialState: StudyManagementFeature.State()) {
            StudyManagementFeature()
        } withDependencies: {
            $0.studyClient.fetchMyStudies = { mockStudies }
        }

        await store.send(.onAppear) {
            $0.studies = .loading
        }
        await store.receive(\.studiesResponse.success) {
            $0.studies = .loaded(mockStudies)
        }

        // 로드된 상태에서 onAppear 재수신 — 로딩으로 되돌리지 않고 조용히 갱신
        await store.send(.onAppear)
        await store.receive(\.studiesResponse.success)
    }

    @Test
    func 팀장이_혼자인_스터디_탈퇴시_삭제_확인_알럿() async {
        let ownerID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let study = Study.soloOwnerMock

        var initialState = StudyManagementFeature.State(currentUserID: ownerID)
        initialState.studies = .loaded([study])

        let store = TestStore(initialState: initialState) {
            StudyManagementFeature()
        }

        await store.send(.leaveStudyTapped(study.id)) {
            $0.selectedStudyID = study.id
            $0.confirmAlert = AlertState {
                TextState("스터디 삭제")
            } actions: {
                ButtonState(role: .destructive, action: .confirmLeave) {
                    TextState("삭제")
                }
                ButtonState(role: .cancel) {
                    TextState("취소")
                }
            } message: {
                TextState("팀장이 탈퇴하면 스터디가 삭제됩니다. 올라온 영상과 피드백·댓글이 모두 사라지며 되돌릴 수 없습니다. 정말 삭제하시겠습니까?")
            }
        }
    }

    @Test
    func 멤버가_있는_스터디의_팀장_탈퇴는_위임_안내로_차단() async {
        let ownerID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let study = Study.ownerWithMemberMock

        var initialState = StudyManagementFeature.State(currentUserID: ownerID)
        initialState.studies = .loaded([study])

        let store = TestStore(initialState: initialState) {
            StudyManagementFeature()
        }

        // selectedStudyID가 남지 않아 confirmLeave 경로가 열리지 않는다
        await store.send(.leaveStudyTapped(study.id)) {
            $0.confirmAlert = AlertState {
                TextState("팀장 위임 필요")
            } actions: {
                ButtonState(role: .cancel) {
                    TextState("확인")
                }
            } message: {
                TextState("팀장은 다른 멤버에게 팀장을 위임한 후 탈퇴할 수 있습니다. 스터디의 멤버 관리에서 팀장을 위임해주세요.")
            }
        }
    }

    @Test
    func 탈퇴_실패시_에러_알럿_노출() async {
        let store = TestStore(initialState: StudyManagementFeature.State()) {
            StudyManagementFeature()
        }

        await store.send(.leaveFailed(.business(.ownerMustTransferBeforeLeave))) {
            $0.confirmAlert = AlertState {
                TextState("스터디 탈퇴 실패")
            } actions: {
                ButtonState(role: .cancel) {
                    TextState("확인")
                }
            } message: {
                TextState(AppError.business(.ownerMustTransferBeforeLeave).localizedDescription)
            }
        }
    }

    @Test
    func 리프레시_시_기존_콘텐츠_유지() async {
        let mockStudies = [Study.mock]

        var initialState = StudyManagementFeature.State()
        initialState.studies = .loaded(mockStudies)

        let store = TestStore(initialState: initialState) {
            StudyManagementFeature()
        } withDependencies: {
            $0.studyClient.fetchMyStudies = { [] }
        }

        // refresh는 .loading으로 내리지 않고 조용히 재조회
        await store.send(.refresh)
        await store.receive(\.studiesResponse.success) {
            $0.studies = .loaded([])
        }
    }
}

// MARK: - Mock Data

private extension Study {
    static let soloOwnerMock = Study(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000030")!,
        name: "혼자 스터디",
        description: "팀장 혼자 남은 스터디",
        ownerID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        inviteCode: "SOLO01",
        maxMembers: 6,
        members: [
            StudyMember(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000031")!,
                userID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
                userName: "김팀장",
                role: .owner,
                joinedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        ],
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    static let ownerWithMemberMock = Study(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000040")!,
        name: "둘이 스터디",
        description: "멤버가 남아 있는 스터디",
        ownerID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        inviteCode: "DUO001",
        maxMembers: 6,
        members: [
            StudyMember(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000041")!,
                userID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
                userName: "김팀장",
                role: .owner,
                joinedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            StudyMember(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000042")!,
                userID: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
                userName: "이멤버",
                role: .member,
                joinedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
        ],
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
