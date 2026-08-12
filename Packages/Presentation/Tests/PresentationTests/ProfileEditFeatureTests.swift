import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct ProfileEditFeatureTests {
    @Test
    func 중복_이름_저장_실패시_얼럿_표시() async {
        let store = TestStore(initialState: ProfileEditFeature.State(currentUser: .profileEditMock)) {
            ProfileEditFeature()
        } withDependencies: {
            $0.userClient.updateProfile = { _ in throw AppError.business(.nameAlreadyTaken) }
        }

        await store.send(.nameChanged("중복이름")) {
            $0.name = "중복이름"
        }

        await store.send(.saveTapped) {
            $0.isSubmitting = true
        }

        await store.receive(\.saveResponse.failure) {
            $0.isSubmitting = false
            $0.alert = AlertState {
                TextState("이름 중복")
            } actions: {
                ButtonState(role: .cancel) {
                    TextState("확인")
                }
            } message: {
                TextState(BusinessError.nameAlreadyTaken.userMessage)
            }
        }
    }

    @Test
    func 일반_에러는_얼럿이_아닌_에러_상태로_표시() async {
        let store = TestStore(initialState: ProfileEditFeature.State(currentUser: .profileEditMock)) {
            ProfileEditFeature()
        } withDependencies: {
            $0.userClient.updateProfile = { _ in throw AppError.network(.timeout) }
        }

        await store.send(.nameChanged("새이름")) {
            $0.name = "새이름"
        }

        await store.send(.saveTapped) {
            $0.isSubmitting = true
        }

        await store.receive(\.saveResponse.failure) {
            $0.isSubmitting = false
            $0.error = .network(.timeout)
        }
    }
}

// MARK: - Mock Data

private extension User {
    static let profileEditMock = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000200")!,
        email: "profile@example.com",
        name: "프로필 테스트 유저",
        provider: .apple,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
