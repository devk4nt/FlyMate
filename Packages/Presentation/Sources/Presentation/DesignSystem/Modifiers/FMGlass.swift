import SwiftUI

/// iOS 26+에서 `GlassEffectContainer`로 감싸고, 미지원 버전에서는 콘텐츠를 그대로 노출한다.
public struct FMGlassContainer<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    public init(
        spacing: CGFloat = FMSpacing.sm,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

private struct FMGlassModifier: ViewModifier {
    let tint: Color
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(
                .regular.tint(tint).interactive(),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            content
        }
    }
}

extension View {
    /// iOS 26+에서 인터랙티브 Liquid Glass를 적용한다.
    /// 미지원 버전에서는 no-op — 폴백 배경은 호출부에서 `background`로 함께 지정한다.
    public func fmGlass(
        tint: Color,
        cornerRadius: CGFloat = FMSpacing.CornerRadius.md
    ) -> some View {
        modifier(FMGlassModifier(tint: tint, cornerRadius: cornerRadius))
    }
}
