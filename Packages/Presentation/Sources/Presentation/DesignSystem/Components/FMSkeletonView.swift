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

    /// `FMCard(style: .feed)` 텍스트 카드 스켈레톤 — 아바타 헤더 + 제목 + 본문 2줄.
    /// StudyRow, FeedbackManagementRow, RecruitPostRow 등 피드 카드 목록의 로딩용.
    public static var card: some View {
        FMCard(style: .feed) {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                HStack(spacing: FMSpacing.sm) {
                    FMSkeletonView(width: 32, height: 32, cornerRadius: 16, isShimmering: false)
                    FMSkeletonView(width: 96, height: 12, isShimmering: false)
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: FMSpacing.xs) {
                    FMSkeletonView(width: 200, height: 18, isShimmering: false)
                    FMSkeletonView(height: 14, isShimmering: false)
                    FMSkeletonView(width: 240, height: 14, isShimmering: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .shimmer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("카드 로딩 중")
    }

    /// `FMFeedCell` 스켈레톤 — 작성자 헤더 + 1.85:1 영상 영역 + 제목/푸터. 바깥 패딩까지 FMFeedCell과 동일.
    public static var feedCell: some View {
        FMCard(style: .feed, padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: FMSpacing.xs) {
                    FMSkeletonView(width: 28, height: 28, cornerRadius: 14, isShimmering: false)
                    VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                        FMSkeletonView(width: 88, height: 12, isShimmering: false)
                        FMSkeletonView(width: 120, height: 10, isShimmering: false)
                    }
                    Spacer(minLength: 0)
                }
                .padding(FMSpacing.sm)

                Color.clear
                    .aspectRatio(1.85, contentMode: .fit)
                    .overlay {
                        RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous)
                            .fill(FMColors.label.opacity(0.08))
                    }

                VStack(alignment: .leading, spacing: FMSpacing.xs) {
                    FMSkeletonView(width: 220, height: 16, isShimmering: false)
                    FMSkeletonView(width: 140, height: 12, isShimmering: false)
                }
                .padding(FMSpacing.sm)
            }
            .shimmer()
        }
        .padding(.horizontal, FMSpacing.md)
        .padding(.vertical, FMSpacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("영상 로딩 중")
    }
}

#Preview {
    VStack(spacing: FMSpacing.lg) {
        FMSkeletonView(height: 20)
        FMSkeletonView(width: 200, height: 14)
        FMSkeletonView.listRow
        FMSkeletonView.card
        FMSkeletonView.feedCell
    }
    .padding()
}
