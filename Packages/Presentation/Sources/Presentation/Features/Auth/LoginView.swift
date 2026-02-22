import SwiftUI
import ComposableArchitecture

public struct LoginView: View {
    let store: StoreOf<LoginFeature>

    public init(store: StoreOf<LoginFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: FMSpacing.xxl) {
            Spacer()

            // 앱 로고 & 타이틀
            VStack(spacing: FMSpacing.md) {
                Image(systemName: "airplane")
                    .font(.system(size: 60))
                    .foregroundStyle(FMColors.accent)

                Text("FlyMate")
                    .font(FMTypography.largeTitle)

                Text("면접 스터디 피드백을 영상으로")
                    .font(FMTypography.body)
                    .foregroundStyle(FMColors.secondaryLabel)
            }

            Spacer()

            // 로그인 버튼
            VStack(spacing: FMSpacing.sm) {
                FMButton(
                    title: "Apple로 계속하기",
                    style: .primary,
                    isLoading: store.isLoading
                ) {
                    store.send(.appleLoginTapped)
                }

                FMButton(
                    title: "카카오로 계속하기",
                    style: .secondary,
                    isLoading: store.isLoading
                ) {
                    store.send(.kakaoLoginTapped)
                }
            }
            .padding(.horizontal, FMSpacing.lg)
            .padding(.bottom, FMSpacing.xxxl)
        }
        .alert(
            "로그인 실패",
            isPresented: .init(
                get: { store.error != nil },
                set: { if !$0 { store.send(.errorDismissed) } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            if let error = store.error {
                Text(error.errorDescription ?? "알 수 없는 오류가 발생했습니다.")
            }
        }
    }
}
