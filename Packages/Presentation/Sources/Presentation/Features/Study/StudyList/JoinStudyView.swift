import SwiftUI
import ComposableArchitecture
import Core

public struct JoinStudyView: View {
    @Bindable var store: StoreOf<JoinStudyFeature>

    public init(store: StoreOf<JoinStudyFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            FMColors.canvas.ignoresSafeArea()

            ScrollView {
                VStack(spacing: FMSpacing.md) {
                    if store.isRequestSent {
                        requestSentView
                    } else {
                        introHeader
                        inputView
                    }
                }
                .padding(.horizontal, FMSpacing.md)
                .padding(.top, FMSpacing.xs)
                .padding(.bottom, FMSpacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .dismissKeyboardOnTap()
        .navigationTitle("스터디 참여")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") {
                    store.send(.cancelTapped)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            FMButton(
                title: store.isRequestSent ? "확인" : "참여 요청",
                isLoading: store.isJoining,
                isEnabled: store.isRequestSent || store.isCodeValid
            ) {
                store.send(store.isRequestSent ? .confirmTapped : .joinTapped)
            }
            .fmSheetBottomBar()
        }
    }

    private var introHeader: some View {
        HStack(spacing: FMSpacing.md) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: FMSizing.IconContainer.hero, height: FMSizing.IconContainer.hero)
                .background(FMColors.brandGradient, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous))

            VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                Text("팀과 함께 시작해요")
                    .font(FMTypography.title2)
                    .foregroundStyle(FMColors.label)
                Text("스터디 팀장이 공유한 초대 코드가 필요해요.")
                    .font(FMTypography.callout)
                    .foregroundStyle(FMColors.secondaryLabel)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, FMSpacing.sm)
    }

    private var inputView: some View {
        FMCard {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                Text("초대 코드")
                    .font(FMTypography.headline)

                FMTextField(
                    title: "6자리 코드",
                    placeholder: "6자리 코드 입력",
                    text: $store.inviteCode.sending(\.inviteCodeChanged),
                    errorMessage: store.errorMessage,
                    characterLimit: AppConstants.inviteCodeLength
                )
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            }
        }
    }

    private var requestSentView: some View {
        FMCard {
            VStack(spacing: FMSpacing.md) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: FMSizing.IconSize.hero))
                    .foregroundStyle(FMColors.iconAccent)

                Text("참여 요청이 전송되었습니다")
                    .font(FMTypography.title3)

                Text("스터디 팀장이 승인하면 참여할 수 있습니다.")
                    .font(FMTypography.body)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FMSpacing.xl)
        }
    }
}
