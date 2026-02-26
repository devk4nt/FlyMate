import SwiftUI
import ComposableArchitecture
import Core

public struct JoinStudyView: View {
    @Bindable var store: StoreOf<JoinStudyFeature>

    public init(store: StoreOf<JoinStudyFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: FMSpacing.lg) {
            if store.isRequestSent {
                requestSentView
            } else {
                inputView
            }
        }
        .padding(FMSpacing.md)
        .navigationTitle("스터디 참여")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") {
                    store.send(.cancelTapped)
                }
            }
        }
    }

    private var inputView: some View {
        VStack(spacing: FMSpacing.lg) {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                Text("스터디에 참여하려면 초대 코드를 입력하세요.")
                    .font(FMTypography.body)
                    .foregroundStyle(FMColors.secondaryLabel)

                FMTextField(
                    title: "초대 코드",
                    placeholder: "6자리 코드 입력",
                    text: $store.inviteCode.sending(\.inviteCodeChanged),
                    errorMessage: store.errorMessage,
                    characterLimit: AppConstants.inviteCodeLength
                )
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            }

            Spacer()

            FMButton(
                title: "참여 요청",
                style: .primary,
                isLoading: store.isJoining,
                isEnabled: store.isCodeValid
            ) {
                store.send(.joinTapped)
            }
        }
    }

    private var requestSentView: some View {
        VStack(spacing: FMSpacing.lg) {
            Spacer()

            VStack(spacing: FMSpacing.md) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(FMColors.primary)

                Text("참여 요청이 전송되었습니다")
                    .font(FMTypography.title3)

                Text("스터디장이 승인하면 참여할 수 있습니다.")
                    .font(FMTypography.body)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            FMButton(
                title: "확인",
                style: .primary
            ) {
                store.send(.confirmTapped)
            }
        }
    }
}
