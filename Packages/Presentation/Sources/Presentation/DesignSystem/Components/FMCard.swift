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
        paddingOverride ?? FMSpacing.md
    }

    private var cornerRadius: CGFloat {
        switch style {
        case .standard: FMSpacing.CornerRadius.lg
        case .feed: FMSpacing.CornerRadius.lg
        case .hero: FMSpacing.CornerRadius.hero
        }
    }

    private var backgroundColor: Color {
        if let backgroundOverride { return backgroundOverride }
        switch style {
        case .standard: return FMColors.elevatedBackground
        case .feed, .hero: return FMColors.background
        }
    }

    private var borderColor: Color {
        if let borderOverride { return borderOverride }
        switch style {
        case .standard: return FMColors.border.opacity(0.28)
        case .feed: return FMColors.supportAccent.opacity(0.2)
        case .hero: return FMColors.border.opacity(0.18)
        }
    }

    private var borderWidth: CGFloat {
        0.5
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

/// 카메라 프레임, 피드백 말풍선, 완료 체크를 결합한 FlyMate 전용 심벌입니다.
public struct FMPracticeSymbol: View {
    private let size: CGFloat
    private let showsEncouragement: Bool

    public init(size: CGFloat = 52, showsEncouragement: Bool = true) {
        self.size = size
        self.showsEncouragement = showsEncouragement
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .stroke(FMColors.brandTitle, lineWidth: 2)
                .frame(width: size * 0.72, height: size * 0.56)
                .overlay {
                    Circle()
                        .stroke(FMColors.supportAccent, lineWidth: 2)
                        .frame(width: size * 0.2, height: size * 0.2)
                }
                .offset(x: -size * 0.05, y: -size * 0.04)

            Image(systemName: "bubble.left.fill")
                .font(.system(size: size * 0.31, weight: .semibold))
                .foregroundStyle(FMColors.supportAccent)
                .symbolRenderingMode(.hierarchical)
                .offset(x: size * 0.28, y: size * 0.25)

            if showsEncouragement {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: size * 0.3, height: size * 0.3)
                    .background(FMColors.blushCoral, in: Circle())
                    .offset(x: size * 0.31, y: -size * 0.28)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
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
