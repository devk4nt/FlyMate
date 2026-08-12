import SwiftUI
import ComposableArchitecture

public struct LoginView: View {
    let store: StoreOf<LoginFeature>

    public init(store: StoreOf<LoginFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            FMColors.canvas
                .ignoresSafeArea()

            Circle()
                .fill(FMColors.primary.opacity(0.14))
                .frame(width: 330, height: 330)
                .blur(radius: 4)
                .offset(x: 160, y: -330)

            Circle()
                .fill(FMColors.secondary.opacity(0.13))
                .frame(width: 260, height: 260)
                .blur(radius: 8)
                .offset(x: -170, y: 340)

            VStack(spacing: FMSpacing.xxl) {
                Spacer()

                VStack(spacing: FMSpacing.lg) {
                    ZStack {
                        RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.hero, style: .continuous)
                            .fill(FMColors.brandGradient)

                        Image(systemName: "airplane")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(-12))
                    }
                    .frame(width: 92, height: 92)
                    .shadow(color: FMColors.primary.opacity(0.3), radius: 22, y: 12)

                    VStack(spacing: FMSpacing.xs) {
                        Text("FlyMate")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(FMColors.label)

                        Text("함께 연습하고, 더 나은 나를 발견하세요")
                            .font(FMTypography.body)
                            .foregroundStyle(FMColors.secondaryLabel)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()

                VStack(spacing: FMSpacing.md) {
                    Text("간편하게 시작하기")
                        .font(FMTypography.feedMetaEmphasis)
                        .foregroundStyle(FMColors.secondaryLabel)
                        .textCase(.uppercase)
                        .tracking(0.7)

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
                .padding(FMSpacing.lg)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous)
                        .stroke(.white.opacity(0.5), lineWidth: 0.5)
                }
                .shadow(color: FMShadow.cardColor, radius: FMShadow.cardRadius, y: FMShadow.cardY)
                .padding(.horizontal, FMSpacing.md)
                .padding(.bottom, FMSpacing.xl)
            }
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
