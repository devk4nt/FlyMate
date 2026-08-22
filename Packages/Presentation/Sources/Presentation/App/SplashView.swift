import SwiftUI

public struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimated = false

    public init() {}

    public var body: some View {
        ZStack {
            FMColors.canvas
                .ignoresSafeArea()

            Circle()
                .fill(FMColors.supportSurface)
                .frame(width: 280, height: 280)
                .blur(radius: 10)
                .offset(x: 160, y: -310)
                .scaleEffect(isAnimated ? 1 : 0.72)
                .opacity(isAnimated ? 1 : 0)

            Circle()
                .fill(FMColors.secondary.opacity(0.28))
                .frame(width: 130, height: 130)
                .blur(radius: 6)
                .offset(x: -155, y: 330)
                .scaleEffect(isAnimated ? 1 : 0.7)
                .opacity(isAnimated ? 1 : 0)

            FMAppIcon(size: 176, showsShadow: true)
                .scaleEffect(isAnimated ? 1 : 0.86)
                .opacity(isAnimated ? 1 : 0)
                .offset(y: isAnimated ? -50 : 0)

            VStack(spacing: FMSpacing.xs) {
                Text("FlyMate")
                    .font(FMTypography.font(size: 42, relativeTo: .largeTitle, weight: .bold))
                    .foregroundStyle(FMColors.brandTitle)

                Text("함께 연습하고, 더 자신 있게")
                    .font(FMTypography.font(size: 15, relativeTo: .subheadline, weight: .medium))
                    .foregroundStyle(FMColors.secondaryLabel)
            }
            .offset(y: isAnimated ? 100 : 110)
            .opacity(isAnimated ? 1 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("FlyMate 시작 중")
        .task {
            await Task.yield()

            guard !reduceMotion else {
                isAnimated = true
                return
            }

            try? await Task.sleep(nanoseconds: 100_000_000)

            withAnimation(.spring(response: 0.72, dampingFraction: 0.82)) {
                isAnimated = true
            }
        }
    }

}

#Preview {
    SplashView()
}
