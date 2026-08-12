import SwiftUI
import ComposableArchitecture

public struct OnboardingView: View {
    let store: StoreOf<OnboardingFeature>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(store: StoreOf<OnboardingFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header

                TabView(selection: pageSelection) {
                    ForEach(store.pages) { page in
                        OnboardingPageView(page: page)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
            }
            .safeAreaPadding(.horizontal, FMSpacing.xl)
            .safeAreaPadding(.vertical, FMSpacing.md)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("FlyMate 앱 소개")
    }

    private var pageSelection: Binding<Int> {
        Binding(
            get: { store.currentPage },
            set: { store.send(.pageChanged($0)) }
        )
    }

    private var background: some View {
        ZStack {
            FMColors.canvas

            Circle()
                .fill(FMColors.primary.opacity(0.14))
                .frame(width: 330, height: 330)
                .blur(radius: 5)
                .offset(x: 165, y: -350)

            Circle()
                .fill(FMColors.secondary.opacity(0.12))
                .frame(width: 270, height: 270)
                .blur(radius: 8)
                .offset(x: -175, y: 350)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var header: some View {
        HStack(spacing: FMSpacing.sm) {
            Image("FlyMateAppIcon", bundle: .module)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm, style: .continuous))
                .accessibilityHidden(true)

            Text("FlyMate")
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(FMColors.label)

            Spacer()

            if !store.isLastPage {
                Button("건너뛰기") {
                    store.send(.skipTapped)
                }
                .font(FMTypography.callout.weight(.semibold))
                .foregroundStyle(FMColors.secondaryLabel)
                .padding(.horizontal, FMSpacing.sm)
                .frame(minHeight: 40)
                .background(.thinMaterial)
                .clipShape(Capsule())
                .accessibilityHint("온보딩을 건너뛰고 앱을 시작합니다")
            }
        }
        .frame(minHeight: 44)
    }

    private var footer: some View {
        VStack(spacing: FMSpacing.lg) {
            HStack(spacing: FMSpacing.xs) {
                ForEach(store.pages) { page in
                    Capsule()
                        .fill(page.id == store.currentPage ? FMColors.accent : FMColors.border.opacity(0.55))
                        .frame(
                            width: page.id == store.currentPage ? 28 : FMSizing.dot,
                            height: FMSizing.dot
                        )
                        .animation(
                            reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8),
                            value: store.currentPage
                        )
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("총 \(store.pages.count)페이지 중 \(store.currentPage + 1)페이지")

            FMButton(
                title: store.isLastPage ? "FlyMate 시작하기" : "다음"
            ) {
                primaryButtonTapped()
            }
            .accessibilityHint(
                store.isLastPage
                    ? "온보딩을 완료하고 앱을 시작합니다"
                    : "다음 소개 페이지로 이동합니다"
            )
        }
        .padding(.top, FMSpacing.sm)
    }

    private func primaryButtonTapped() {
        if store.isLastPage {
            store.send(.startTapped)
        } else {
            let nextPage = min(store.currentPage + 1, store.pages.count - 1)
            store.send(
                .pageChanged(nextPage),
                animation: reduceMotion ? nil : .easeInOut(duration: 0.3)
            )
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: FMSpacing.xxl) {
            Spacer(minLength: FMSpacing.md)

            OnboardingArtwork(pageID: page.id)
                .frame(maxWidth: 340)
                .frame(maxHeight: 290)

            VStack(spacing: FMSpacing.sm) {
                Text(page.title)
                    .font(FMTypography.heroTitle)
                    .foregroundStyle(FMColors.label)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(page.description)
                    .font(FMTypography.body)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 360)

            Spacer(minLength: FMSpacing.md)
        }
        .padding(.horizontal, FMSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(page.title). \(page.description)")
    }
}

private struct OnboardingArtwork: View {
    let pageID: Int

    private var configuration: ArtworkConfiguration {
        switch pageID {
        case 1:
            ArtworkConfiguration(
                symbol: "quote.bubble.fill",
                badgeSymbol: "waveform",
                detailSymbol: "clock.fill",
                caption: "00:42 피드백",
                usesFeatureGradient: true
            )
        case 2:
            ArtworkConfiguration(
                symbol: "person.3.fill",
                badgeSymbol: "arrow.up.right",
                detailSymbol: "sparkles",
                caption: "함께 만드는 성장",
                usesFeatureGradient: false
            )
        default:
            ArtworkConfiguration(
                symbol: "video.fill",
                badgeSymbol: "arrow.up",
                detailSymbol: "record.circle",
                caption: "나의 모의 면접",
                usesFeatureGradient: false
            )
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(FMColors.primary.opacity(0.12))
                .frame(width: 230, height: 230)

            RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.artwork, style: .continuous)
                .fill(FMColors.elevatedBackground.opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.artwork, style: .continuous)
                        .stroke(.white.opacity(0.55), lineWidth: 1)
                }
                .shadow(color: FMShadow.cardColor, radius: 24, y: 12)
                .frame(width: 238, height: 218)

            VStack(spacing: FMSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous)
                        .fill(configuration.gradient)

                    Image(systemName: configuration.symbol)
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 112, height: 112)
                .shadow(color: FMColors.primary.opacity(0.24), radius: 14, y: 8)

                Label(configuration.caption, systemImage: configuration.detailSymbol)
                    .font(FMTypography.feedMetaEmphasis)
                    .foregroundStyle(FMColors.brandInk)
                    .padding(.horizontal, FMSpacing.sm)
                    .padding(.vertical, FMSpacing.xs)
                    .background(FMColors.primary.opacity(0.1))
                    .clipShape(Capsule())
            }

            ZStack {
                Circle()
                    .fill(FMColors.elevatedBackground)

                Image(systemName: configuration.badgeSymbol)
                    .font(.system(size: FMSizing.IconSize.md, weight: .bold))
                    .foregroundStyle(FMColors.accent)
            }
            .frame(width: 54, height: 54)
            .overlay {
                Circle()
                    .stroke(FMColors.primary.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: FMShadow.cardColor, radius: 10, y: 5)
            .offset(x: 112, y: -72)

            Image(systemName: "sparkle")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(FMColors.secondary)
                .offset(x: -122, y: -92)

            Image(systemName: "circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(FMColors.secondary.opacity(0.8))
                .offset(x: -124, y: 86)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }
}

private struct ArtworkConfiguration {
    let symbol: String
    let badgeSymbol: String
    let detailSymbol: String
    let caption: String
    let usesFeatureGradient: Bool

    var gradient: LinearGradient {
        usesFeatureGradient ? FMColors.featureGradient : FMColors.brandGradient
    }
}
