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
            ZStack {
                FMColors.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: FMSpacing.md) {
                        HStack(spacing: FMSpacing.md) {
                            Image(systemName: "exclamationmark.bubble.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(FMColors.destructive, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous))

                            VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                                Text(reportTitle)
                                    .font(FMTypography.title2)
                                    .foregroundStyle(FMColors.label)

                                Text("신고 사유를 선택해 주세요.")
                                    .font(FMTypography.callout)
                                    .foregroundStyle(FMColors.secondaryLabel)
                            }
                        }
                        .padding(.vertical, FMSpacing.sm)

                        FMCard {
                            VStack(alignment: .leading, spacing: FMSpacing.md) {
                                Text("신고 사유")
                                    .font(FMTypography.headline)

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
                            }
                        }

                        FMCard {
                            VStack(alignment: .leading, spacing: FMSpacing.xs) {
                                Text("상세 내용 (선택)")
                                    .font(FMTypography.headline)

                                TextField("추가 설명을 입력해 주세요", text: $store.detail, axis: .vertical)
                                    .lineLimit(3...6)
                                    .font(FMTypography.body)
                                    .padding(FMSpacing.sm)
                                    .fmInputSurface()
                            }
                        }
                    }
                    .padding(.horizontal, FMSpacing.md)
                    .padding(.top, FMSpacing.xs)
                    .padding(.bottom, FMSpacing.xxl)
                }
                .scrollDismissesKeyboard(.interactively)
                .dismissKeyboardOnTap()
            }
            .navigationTitle("신고하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                FMButton(
                    title: "신고하기",
                    style: .destructive,
                    isLoading: store.isSubmitting,
                    isEnabled: store.canSubmit
                ) {
                    store.send(.submitTapped)
                }
                .fmSheetBottomBar()
            }
        }
        .fmSheetStyle()
        .onAppear { store.send(.onAppear) }
        .presentationDetents([.medium, .large])
    }

    private var reportTitle: String {
        switch store.targetType {
        case .feedback: return "피드백 신고"
        case .user: return "사용자 신고"
        case .recruitPost: return "모집 글 신고"
        case .recruitComment: return "댓글 신고"
        case .quickFeedbackRequest: return "빠른 피드백 영상 신고"
        case .quickFeedbackReview: return "빠른 피드백 신고"
        }
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
