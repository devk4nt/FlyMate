import SwiftUI

/// A ViewModifier that adds a shimmer/loading animation effect
/// using a moving gradient overlay.
public struct ShimmerModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    private let duration: Double
    private let bounce: Bool

    public init(duration: Double = 1.5, bounce: Bool = false) {
        self.duration = duration
        self.bounce = bounce
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay {
                    GeometryReader { geometry in
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                Color.white.opacity(colorScheme == .dark ? 0.16 : 0.4),
                                .clear,
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 2)
                        .offset(x: phase * geometry.size.width)
                    }
                    .clipped()
                    .mask { content }
                }
                .onAppear {
                    withAnimation(
                        .linear(duration: duration)
                        .repeatForever(autoreverses: bounce)
                    ) {
                        phase = 1
                    }
                }
        }
    }
}

extension View {
    /// Applies a shimmer animation effect over the view.
    /// - Parameters:
    ///   - active: Whether the shimmer effect is active.
    ///   - duration: The duration of one shimmer cycle.
    /// - Returns: The view with or without the shimmer effect.
    public func shimmer(active: Bool = true, duration: Double = 1.5) -> some View {
        modifier(ShimmerModifier(duration: duration))
            .opacity(active ? 1 : 0)
    }
}
