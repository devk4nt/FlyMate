import SwiftUI
import ComposableArchitecture
import Core

public struct StudyCreateView: View {
    @Bindable var store: StoreOf<StudyCreateFeature>

    public init(store: StoreOf<StudyCreateFeature>) {
        self.store = store
    }

    public var body: some View {
        Form {
            Section("스터디 정보") {
                FMTextField(
                    title: "스터디 이름",
                    placeholder: "스터디 이름을 입력하세요",
                    text: $store.name.sending(\.nameChanged),
                    characterLimit: AppConstants.maxStudyNameLength
                )

                VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                    Text("설명")
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)

                    TextEditor(text: $store.description.sending(\.descriptionChanged))
                        .frame(minHeight: 80)
                        .font(FMTypography.body)
                }
            }

            Section("인원 설정") {
                Stepper(
                    "최대 인원: \(store.maxMembers)명",
                    value: $store.maxMembers.sending(\.maxMembersChanged),
                    in: 2...AppConstants.maxStudyMembers
                )
            }
        }
        .navigationTitle("스터디 만들기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") {
                    store.send(.cancelTapped)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if store.isSubmitting {
                    ProgressView()
                } else {
                    Button("만들기") {
                        store.send(.submitTapped)
                    }
                    .disabled(!store.isValid)
                }
            }
        }
        .alert(
            "오류",
            isPresented: Binding(
                get: { store.error != nil },
                set: { if !$0 { store.send(.errorDismissed) } }
            )
        ) {
            Button("확인") {
                store.send(.errorDismissed)
            }
        } message: {
            if let error = store.error {
                Text(error.localizedDescription)
            }
        }
    }
}
