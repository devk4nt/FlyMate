import SwiftUI
import ComposableArchitecture
import Core

public struct LoginView: View {
    @Bindable var store: StoreOf<LoginFeature>

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
                    .onTapGesture { store.send(.logoTapped) }

                    VStack(spacing: FMSpacing.xs) {
                        Text("FlyMate")
                            .font(FMTypography.font(size: 34, relativeTo: .largeTitle, weight: .bold))
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

                    // 가입/로그인 전 EULA 동의 고지 (App Store Guideline 1.2)
                    Text(.init(
                        "계속하면 FlyMate [이용약관](\(AppConstants.ServiceURL.termsOfService)) 및 [개인정보처리방침](\(AppConstants.ServiceURL.privacyPolicy))에 동의하는 것으로 간주됩니다. 부적절한 콘텐츠와 악성 사용자에게는 무관용 원칙이 적용됩니다."
                    ))
                    .font(FMTypography.caption2)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .tint(FMColors.primary)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("이용약관 및 개인정보처리방침 동의 안내")
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
        .sheet(
            isPresented: .init(
                get: { store.showsEmailLogin },
                set: { if !$0 { store.send(.emailLoginDismissed) } }
            )
        ) {
            emailLoginSheet
        }
        .confirmationDialog(
            "테스트 계정 로그인",
            isPresented: .init(
                get: { store.showsStagingAccountPicker },
                set: { if !$0 { store.send(.stagingAccountPickerDismissed) } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(LoginFeature.StagingAccount.allCases, id: \.self) { account in
                Button(account.title) {
                    store.send(.stagingAccountSelected(account))
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("Staging 전용 — 선택한 역할의 계정으로 로그인합니다.")
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

    // MARK: - Email Login (App Store 심사용 히든 로그인)

    private var emailLoginSheet: some View {
        VStack(spacing: FMSpacing.md) {
            Text("이메일 로그인")
                .font(FMTypography.headline)
                .foregroundStyle(FMColors.label)
                .padding(.top, FMSpacing.xl)

            FMTextField(
                title: "이메일",
                placeholder: "이메일을 입력하세요",
                text: $store.email.sending(\.emailChanged)
            )
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()

            VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                Text("비밀번호")
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.secondaryLabel)

                SecureField("비밀번호를 입력하세요", text: $store.password.sending(\.passwordChanged))
                    .font(FMTypography.body)
                    .frame(minHeight: 48)
                    .padding(.horizontal, FMSpacing.sm)
                    .background(FMColors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous))
                    .accessibilityLabel("비밀번호")
            }

            FMButton(
                title: "로그인",
                style: .primary,
                isLoading: store.isLoading
            ) {
                store.send(.emailLoginTapped)
            }

            Spacer()
        }
        .padding(.horizontal, FMSpacing.lg)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
