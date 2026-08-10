import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core
@testable import Presentation

@MainActor
struct MemberManagementFeatureTests {
    private static let ownerUserID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let memberUserID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private static let studyID = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!

    private static let owner = StudyMember(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
        userID: ownerUserID,
        userName: "방장",
        role: .owner,
        joinedAt: Date(timeIntervalSince1970: 0)
    )

    private static let member = StudyMember(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
        userID: memberUserID,
        userName: "멤버",
        role: .member,
        joinedAt: Date(timeIntervalSince1970: 100)
    )

    private static let study = Study(
        id: studyID,
        name: "테스트 스터디",
        description: "설명",
        ownerID: ownerUserID,
        inviteCode: "ABC123",
        maxMembers: 8,
        members: [owner, member],
        createdAt: Date(timeIntervalSince1970: 0)
    )

    @Test
    func 방장_위임_성공시_방장과_역할이_변경된다() async {
        let store = TestStore(
            initialState: MemberManagementFeature.State(
                study: Self.study,
                currentUserID: Self.ownerUserID
            )
        ) {
            MemberManagementFeature()
        } withDependencies: {
            $0.studyClient.transferOwnership = { studyID, newOwnerID in
                #expect(studyID == Self.studyID)
                #expect(newOwnerID == Self.memberUserID)
            }
        }

        await store.send(.transferOwnerTapped(Self.member)) {
            $0.selectedMemberUserID = Self.memberUserID
            $0.confirmAlert = AlertState {
                TextState("방장 위임")
            } actions: {
                ButtonState(action: .confirmTransfer) {
                    TextState("위임하기")
                }
                ButtonState(role: .cancel) {
                    TextState("취소")
                }
            } message: {
                TextState("멤버님에게 방장을 위임하시겠습니까?")
            }
        }

        await store.send(.confirmAlert(.presented(.confirmTransfer))) {
            $0.confirmAlert = nil
            $0.removeMemberState = .loading
        }

        await store.receive(\.transferOwnerResponse.success) {
            $0.removeMemberState = .idle
            $0.selectedMemberUserID = nil
            $0.study.ownerID = Self.memberUserID
            $0.study.members[0].role = .member
            $0.study.members[1].role = .owner
        }

        await store.receive(\.ownershipTransferred)

        #expect(store.state.isOwner == false)
    }

    @Test
    func 방장_위임_실패시_에러_상태가_된다() async {
        let store = TestStore(
            initialState: MemberManagementFeature.State(
                study: Self.study,
                currentUserID: Self.ownerUserID
            )
        ) {
            MemberManagementFeature()
        } withDependencies: {
            $0.studyClient.transferOwnership = { _, _ in
                throw AppError.business(.unauthorized)
            }
        }

        await store.send(.transferOwnerTapped(Self.member)) {
            $0.selectedMemberUserID = Self.memberUserID
            $0.confirmAlert = AlertState {
                TextState("방장 위임")
            } actions: {
                ButtonState(action: .confirmTransfer) {
                    TextState("위임하기")
                }
                ButtonState(role: .cancel) {
                    TextState("취소")
                }
            } message: {
                TextState("멤버님에게 방장을 위임하시겠습니까?")
            }
        }

        await store.send(.confirmAlert(.presented(.confirmTransfer))) {
            $0.confirmAlert = nil
            $0.removeMemberState = .loading
        }

        await store.receive(\.transferOwnerResponse.failure) {
            $0.removeMemberState = .failed(.business(.unauthorized))
            $0.selectedMemberUserID = nil
        }

        #expect(store.state.study.ownerID == Self.ownerUserID)
    }
}
