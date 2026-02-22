import SwiftUI
import ComposableArchitecture

public struct ProfileEditView: View {
    @Bindable var store: StoreOf<ProfileEditFeature>

    public init(store: StoreOf<ProfileEditFeature>) {
        self.store = store
    }

    public var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    Circle()
                        .fill(FMColors.secondaryBackground)
                        .frame(width: 80, height: 80)
                        .overlay {
                            Text(String(store.name.prefix(1)))
                                .font(FMTypography.largeTitle)
                                .foregroundStyle(FMColors.accent)
                        }
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)

            Section("프로필 정보") {
                FMTextField(
                    title: "이름",
                    placeholder: "이름을 입력하세요",
                    text: $store.name.sending(\.nameChanged)
                )
            }

            if let error = store.error {
                Section {
                    Text(error.errorDescription ?? "오류가 발생했습니다.")
                        .foregroundStyle(FMColors.destructive)
                        .font(FMTypography.caption1)
                }
            }
        }
        .navigationTitle("프로필 수정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") { store.send(.cancelTapped) }
            }
            ToolbarItem(placement: .confirmationAction) {
                FMButton(
                    title: "저장",
                    style: .text,
                    isLoading: store.isSubmitting,
                    isEnabled: store.isValid && store.hasChanges
                ) {
                    store.send(.saveTapped)
                }
            }
        }
    }
}
