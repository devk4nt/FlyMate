import SwiftUI

/// A card container view providing consistent padding,
/// corner radius, background, and shadow styling.
public struct FMCard<Content: View>: View {
    private let padding: CGFloat
    private let cornerRadius: CGFloat
    private let shadowRadius: CGFloat
    private let content: Content

    public init(
        padding: CGFloat = FMSpacing.md,
        cornerRadius: CGFloat = FMSpacing.CornerRadius.md,
        shadowRadius: CGFloat = 4,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(FMColors.background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: Color.black.opacity(0.08),
                radius: shadowRadius,
                x: 0,
                y: 2
            )
    }
}

#Preview {
    FMCard {
        VStack(alignment: .leading, spacing: FMSpacing.xs) {
            Text("Card Title")
                .font(FMTypography.headline)
            Text("Card description goes here.")
                .font(FMTypography.body)
                .foregroundStyle(FMColors.secondaryLabel)
        }
    }
    .padding()
}
