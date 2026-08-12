import SwiftUI

/// A card container view providing consistent padding,
/// corner radius, background, and shadow styling.
public struct FMCard<Content: View>: View {
    public enum Style {
        case standard
        case feed
        case hero
    }

    private let style: Style
    private let paddingOverride: CGFloat?
    private let backgroundOverride: Color?
    private let borderOverride: Color?
    private let content: Content

    public init(
        style: Style = .standard,
        padding: CGFloat? = nil,
        background: Color? = nil,
        border: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.paddingOverride = padding
        self.backgroundOverride = background
        self.borderOverride = border
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            }
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
    }

    private var padding: CGFloat {
        paddingOverride ?? (style == .feed ? FMSpacing.lg : FMSpacing.md)
    }

    private var cornerRadius: CGFloat {
        switch style {
        case .standard: FMSpacing.CornerRadius.lg
        case .feed: FMSpacing.CornerRadius.xl
        case .hero: FMSpacing.CornerRadius.hero
        }
    }

    private var backgroundColor: Color {
        backgroundOverride ?? (style == .standard ? FMColors.elevatedBackground : FMColors.background)
    }

    private var borderColor: Color {
        borderOverride ?? (style == .standard ? FMColors.border.opacity(0.22) : FMColors.accent.opacity(0.2))
    }

    private var borderWidth: CGFloat {
        style == .standard ? 0.5 : 1
    }

    private var shadowColor: Color {
        style == .hero ? FMShadow.heroColor : FMShadow.cardColor
    }

    private var shadowRadius: CGFloat {
        style == .hero ? FMShadow.heroRadius : FMShadow.cardRadius
    }

    private var shadowY: CGFloat {
        style == .hero ? FMShadow.heroY : FMShadow.cardY
    }
}

private struct FMSheetStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(FMColors.canvas.ignoresSafeArea())
            .tint(FMColors.actionForeground)
    }
}

public extension View {
    func fmSheetStyle() -> some View {
        modifier(FMSheetStyleModifier())
    }

    func fmSheetBottomBar() -> some View {
        padding(.horizontal, FMSpacing.md)
            .padding(.top, FMSpacing.sm)
            .padding(.bottom, FMSpacing.xs)
            .background(.ultraThinMaterial)
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
