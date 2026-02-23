import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct ReportView: View {
    @Bindable var store: StoreOf<ReportFeature>
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<ReportFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: FMSpacing.lg) {
                        // Header
                        Text(store.targetType == .feedback ? "피드백 신고" : "사용자 신고")
                            .font(FMTypography.title3)
                            .fontWeight(.bold)
                            .padding(.top, FMSpacing.sm)

                        Text("신고 사유를 선택해 주세요.")
                            .font(FMTypography.callout)
                            .foregroundStyle(FMColors.secondaryLabel)

                        // Reason list
                        VStack(spacing: FMSpacing.xs) {
                            ForEach(ReportReason.allCases, id: \.self) { reason in
                                ReportReasonRow(
                                    reason: reason,
                                    isSelected: store.selectedReason == reason
                                ) {
                                    store.send(.reasonSelected(reason))
                                }
                            }
                        }

                        // Detail input
                        VStack(alignment: .leading, spacing: FMSpacing.xs) {
                            Text("상세 내용 (선택)")
                                .font(FMTypography.caption1)
                                .foregroundStyle(FMColors.secondaryLabel)

                            TextField("추가 설명을 입력해 주세요", text: $store.detail, axis: .vertical)
                                .lineLimit(3...6)
                                .textFieldStyle(.roundedBorder)
                                .font(FMTypography.body)
                        }
                    }
                    .padding(FMSpacing.md)
                }

                // Submit button
                FMButton(
                    title: "신고하기",
                    style: .destructive,
                    isLoading: store.isSubmitting,
                    isEnabled: store.canSubmit
                ) {
                    store.send(.submitTapped)
                }
                .padding(FMSpacing.md)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear { store.send(.onAppear) }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Reason Row

private struct ReportReasonRow: View {
    let reason: ReportReason
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? FMColors.accent : FMColors.secondaryLabel)

                Text(reason.displayText)
                    .font(FMTypography.body)
                    .foregroundStyle(FMColors.label)

                Spacer()
            }
            .padding(.vertical, FMSpacing.sm)
            .padding(.horizontal, FMSpacing.md)
            .background(isSelected ? FMColors.accent.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))
        }
        .accessibilityLabel(reason.displayText)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
