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
                title: "참여하기",
                style: .primary,
                isLoading: store.isJoining,
                isEnabled: store.isCodeValid
            ) {
                store.send(.joinTapped)
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
}
