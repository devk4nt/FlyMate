import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct FeedbackEditView: View {
    @Bindable var store: StoreOf<FeedbackEditFeature>

    public init(store: StoreOf<FeedbackEditFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: FMSpacing.md) {
            // 타임스탬프 표시 (수정 불가, 참고용)
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(FMColors.iconAccent)
                Text(store.feedback.timestampSeconds.minuteSecondFormatted)
                    .font(FMTypography.headline)
                Spacer()
            }
            .padding(.horizontal, FMSpacing.md)

            VStack(alignment: .trailing, spacing: FMSpacing.xxs) {
                TextEditor(text: $store.content.sending(\.contentChanged))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(FMSpacing.xs)
                    .fmInputSurface()
                    .accessibilityLabel("피드백 내용")
                    .accessibilityHint("수정할 피드백 내용을 입력하세요")

                Text("\(store.content.count)/\(AppConstants.maxFeedbackLength)")
                    .font(FMTypography.caption2)
                    .foregroundStyle(FMColors.secondaryLabel)
            }
            .padding(.horizontal, FMSpacing.md)

            if let error = store.error {
                Text(error.errorDescription ?? "오류가 발생했습니다.")
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.destructive)
                    .padding(.horizontal, FMSpacing.md)
            }

            Spacer()
        }
        .padding(.top, FMSpacing.md)
        .dismissKeyboardOnTap()
        .navigationTitle("피드백 수정")
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
                    isEnabled: store.isValid
                ) {
                    store.send(.saveTapped)
                }
            }
        }
    }
}
