import SwiftUI

/// A skeleton loading placeholder view with shimmer animation,
/// used to indicate content is being loaded.
public struct FMSkeletonView: View {
    private let width: CGFloat?
    private let height: CGFloat
    private let cornerRadius: CGFloat

    public init(
        width: CGFloat? = nil,
        height: CGFloat = 16,
        cornerRadius: CGFloat = FMSpacing.CornerRadius.sm
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(FMColors.secondaryBackground)
            .frame(width: width, height: height)
            .shimmer()
            .accessibilityLabel("로딩 중")
            .accessibilityAddTraits(.isImage)
    }
}

// MARK: - Preset Skeleton Layouts

extension FMSkeletonView {
    /// A skeleton row mimicking a list item with an avatar and two text lines.
    public static var listRow: some View {
        HStack(spacing: FMSpacing.sm) {
            FMSkeletonView(width: 44, height: 44, cornerRadius: 22)

            VStack(alignment: .leading, spacing: FMSpacing.xs) {
                FMSkeletonView(height: 14)
                FMSkeletonView(width: 160, height: 12)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("목록 항목 로딩 중")
    }

    /// A skeleton card mimicking a content card layout.
    public static var card: some View {
        VStack(alignment: .leading, spacing: FMSpacing.sm) {
            FMSkeletonView(height: 160)
            FMSkeletonView(height: 16)
            FMSkeletonView(width: 200, height: 14)
        }
        .padding(FMSpacing.md)
        .background(FMColors.background)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("카드 로딩 중")
    }
}

#Preview {
    VStack(spacing: FMSpacing.lg) {
        FMSkeletonView(height: 20)
        FMSkeletonView(width: 200, height: 14)
        FMSkeletonView.listRow
        FMSkeletonView.card
    }
    .padding()
}
