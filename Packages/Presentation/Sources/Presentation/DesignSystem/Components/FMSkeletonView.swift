import SwiftUI

/// A skeleton loading placeholder view with shimmer animation,
/// used to indicate content is being loaded.
public struct FMSkeletonView: View {
    private let width: CGFloat?
    private let height: CGFloat
    private let cornerRadius: CGFloat
    private let isShimmering: Bool

    public init(
        width: CGFloat? = nil,
        height: CGFloat,
        cornerRadius: CGFloat = FMSpacing.CornerRadius.sm,
        isShimmering: Bool = true
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.isShimmering = isShimmering
    }

    @ViewBuilder
    public var body: some View {
        if isShimmering {
            skeletonShape
                .shimmer()
                .accessibilityLabel("로딩 중")
                .accessibilityAddTraits(.isImage)
        } else {
            skeletonShape
                .accessibilityHidden(true)
        }
    }

    private var skeletonShape: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(FMColors.label.opacity(0.08))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
    }
}

// MARK: - Preset Skeleton Layouts

extension FMSkeletonView {
    /// A skeleton row mimicking a list item with an avatar and two text lines.
    public static var listRow: some View {
        HStack(spacing: FMSpacing.sm) {
            FMSkeletonView(width: 44, height: 44, cornerRadius: 22, isShimmering: false)

            VStack(alignment: .leading, spacing: FMSpacing.xs) {
                FMSkeletonView(height: 14, isShimmering: false)
                FMSkeletonView(width: 160, height: 12, isShimmering: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shimmer()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("목록 항목 로딩 중")
    }

    /// A skeleton card mimicking a content card layout.
    public static var card: some View {
        VStack(alignment: .leading, spacing: FMSpacing.sm) {
            FMSkeletonView(height: 160, isShimmering: false)
            FMSkeletonView(height: 16, isShimmering: false)
            FMSkeletonView(width: 200, height: 14, isShimmering: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FMSpacing.md)
        .shimmer()
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
