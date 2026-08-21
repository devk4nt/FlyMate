import SwiftUI
import ComposableArchitecture

public struct AnnouncementDetailView: View {
    private let store: StoreOf<AnnouncementDetailFeature>
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<AnnouncementDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: FMSpacing.lg) {
                    header

                    Text(store.notification.body)
                        .font(FMTypography.body)
                        .lineSpacing(FMSpacing.xxs)
                        .foregroundStyle(FMColors.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .padding(FMSpacing.lg)
            }

            FMButton(title: "확인") {
                store.send(.closeTapped)
                dismiss()
            }
            .accessibilityHint("공지사항을 닫습니다")
            .padding(.horizontal, FMSpacing.lg)
            .padding(.vertical, FMSpacing.md)
            .background(.ultraThinMaterial)
        }
        .background(FMColors.canvas)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: FMSpacing.sm) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(FMColors.actionForeground)
                .accessibilityHidden(true)

            Text(store.notification.title)
                .font(FMTypography.title2)
                .foregroundStyle(FMColors.label)

            Text(store.notification.createdAt.relativeString)
                .font(FMTypography.caption1)
                .foregroundStyle(FMColors.secondaryLabel)
        }
    }
}
