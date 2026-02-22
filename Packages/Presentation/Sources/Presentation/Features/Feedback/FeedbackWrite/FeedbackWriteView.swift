import SwiftUI
import ComposableArchitecture
import Core

public struct FeedbackWriteView: View {
    @Bindable var store: StoreOf<FeedbackWriteFeature>

    public init(store: StoreOf<FeedbackWriteFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: FMSpacing.md) {
            // 타임스탬프 표시
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(FMColors.accent)
                Text(store.timestampSeconds.minuteSecondFormatted)
                    .font(FMTypography.headline)
                Spacer()
            }
            .padding(.horizontal, FMSpacing.md)

            // 피드백 입력
            VStack(alignment: .trailing, spacing: FMSpacing.xxs) {
                TextEditor(text: $store.content.sending(\.contentChanged))
                    .font(FMTypography.body)
                    .frame(minHeight: 120)
                    .padding(FMSpacing.xs)
                    .background(FMColors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))

                Text("\(store.content.count)/\(AppConstants.maxFeedbackLength)")
                    .font(FMTypography.caption2)
                    .foregroundStyle(
                        store.content.count > AppConstants.maxFeedbackLength
                            ? FMColors.destructive
                            : FMColors.secondaryLabel
                    )
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
        .navigationTitle("피드백 작성")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") { store.send(.cancelTapped) }
            }
            ToolbarItem(placement: .confirmationAction) {
                FMButton(
                    title: "등록",
                    style: .text,
                    isLoading: store.isSubmitting,
                    isEnabled: store.isValid
                ) {
                    store.send(.submitTapped)
                }
            }
        }
    }
}
