import SwiftUI

/// A reusable button component supporting multiple visual styles,
/// loading state, and disabled state.
public struct FMButton: View {
    public enum Style {
        case primary
        case secondary
        case destructive
        case text
    }

    private let title: String
    private let style: Style
    private let isLoading: Bool
    private let isEnabled: Bool
    private let action: () -> Void

    public init(
        title: String,
        style: Style = .primary,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button {
            guard !isLoading else { return }
            action()
        } label: {
            HStack(spacing: FMSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                }

                Text(title)
                    .font(FMTypography.headline)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, FMSpacing.md)
            .background {
                if style == .primary {
                    FMColors.brandGradient
                } else {
                    backgroundColor
                }
            }
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous))
            .overlay {
                if style == .secondary {
                    RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous)
                        .stroke(FMColors.border.opacity(0.55), lineWidth: 1)
                }
            }
            .shadow(
                color: style == .primary ? FMColors.primary.opacity(0.22) : .clear,
                radius: 10,
                y: 5
            )
        }
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1.0 : 0.5)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isLoading ? "로딩 중입니다" : "")
    }

    // MARK: - Styling Helpers

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return FMColors.accent
        case .secondary:
            return FMColors.background
        case .destructive:
            return FMColors.destructive
        case .text:
            return .clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return FMColors.label
        case .destructive:
            return .white
        case .text:
            return FMColors.accent
        }
    }
}

#Preview {
    VStack(spacing: FMSpacing.md) {
        FMButton(title: "Primary", style: .primary) {}
        FMButton(title: "Secondary", style: .secondary) {}
        FMButton(title: "Destructive", style: .destructive) {}
        FMButton(title: "Text", style: .text) {}
        FMButton(title: "Loading", style: .primary, isLoading: true) {}
        FMButton(title: "Disabled", style: .primary, isEnabled: false) {}
    }
    .padding()
}
