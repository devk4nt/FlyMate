import SwiftUI

public struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimated = false

    public init() {}

    public var body: some View {
        ZStack {
            FMColors.launchBackground
                .ignoresSafeArea()

            Circle()
                .fill(.white.opacity(colorScheme == .dark ? 0.16 : 0.1))
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

            Image("FlyMateAppIcon", bundle: .module)
                .resizable()
                .scaledToFill()
                .frame(width: 176, height: 176)
                .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.appIcon, style: .continuous))
                .shadow(color: FMShadow.heroColor, radius: FMShadow.heroRadius, y: FMShadow.heroY)
                .scaleEffect(isAnimated ? 1 : 0.86)
                .opacity(isAnimated ? 1 : 0)
                .offset(y: isAnimated ? -50 : 0)

            VStack(spacing: FMSpacing.xs) {
                Text("FlyMate")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(contentColor)

                Text("함께 연습하고, 더 자신 있게")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(contentColor.opacity(0.72))
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

    private var contentColor: Color {
        colorScheme == .dark ? FMColors.mediaBadgeForeground : .white
    }
}

#Preview {
    SplashView()
}
