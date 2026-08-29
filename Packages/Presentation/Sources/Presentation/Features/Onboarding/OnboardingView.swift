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
                .fill(FMColors.supportSurface.opacity(0.8))
                .frame(width: 280, height: 280)
                .blur(radius: 8)
                .offset(x: 170, y: -360)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var header: some View {
        HStack(spacing: FMSpacing.sm) {
            FMAppIcon(size: 40)

            Text("FlyMate")
                .font(FMTypography.font(size: 21, relativeTo: .title3, weight: .bold))
                .foregroundStyle(FMColors.brandTitle)

            Spacer()

            Text("함께 연습하고, 더 자신 있게")
                .font(FMTypography.caption1)
                .foregroundStyle(FMColors.secondaryLabel)
        }
        .frame(minHeight: 44)
    }

    private var footer: some View {
        VStack(spacing: FMSpacing.md) {
            HStack(spacing: FMSpacing.xs) {
                ForEach(store.pages) { page in
                    Capsule()
                        .fill(page.id == store.currentPage ? FMColors.primaryAction : FMColors.border.opacity(0.45))
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

            FMButton(title: primaryButtonTitle) {
                primaryButtonTapped()
            }
            .accessibilityHint(primaryButtonHint)

            Button(secondaryButtonTitle) {
                secondaryButtonTapped()
            }
            .font(FMTypography.font(size: 16, relativeTo: .callout, weight: .semibold))
            .foregroundStyle(FMColors.secondaryLabel)
            .frame(minHeight: 44)
            .accessibilityHint(secondaryButtonHint)
        }
        .padding(.top, FMSpacing.sm)
    }

    private var primaryButtonTitle: String {
        if store.isLastPage { return "첫 영상 올리고 피드백 받기" }
        if store.isNotificationPage { return "알림 켜기" }
        return "다음"
    }

    private var primaryButtonHint: String {
        if store.isLastPage { return "온보딩을 완료하고 첫 영상 업로드 화면으로 이동합니다" }
        if store.isNotificationPage { return "알림 권한 요청 팝업을 표시합니다" }
        return "다음 소개 페이지로 이동합니다"
    }

    private var secondaryButtonTitle: String {
        if store.isLastPage || store.isNotificationPage { return "나중에 할게요" }
        return "건너뛰기"
    }

    private var secondaryButtonHint: String {
        if store.isLastPage { return "온보딩을 완료하고 앱을 시작합니다" }
        if store.isNotificationPage { return "알림 설정 없이 다음 페이지로 이동합니다" }
        return "남은 소개를 건너뛰고 앱을 시작합니다"
    }

    private func primaryButtonTapped() {
        if store.isLastPage {
            store.send(.uploadFirstVideoTapped)
        } else if store.isNotificationPage {
            store.send(.enableNotificationsTapped, animation: reduceMotion ? nil : .easeInOut(duration: 0.3))
        } else {
            advanceToNextPage()
        }
    }

    private func secondaryButtonTapped() {
        if store.isLastPage {
            store.send(.startTapped)
        } else if store.isNotificationPage {
            // 알림은 나중에 — 온보딩은 계속 진행
            advanceToNextPage()
        } else {
            store.send(.skipTapped)
        }
    }

    private func advanceToNextPage() {
        let nextPage = min(store.currentPage + 1, store.pages.count - 1)
        store.send(
            .pageChanged(nextPage),
            animation: reduceMotion ? nil : .easeInOut(duration: 0.3)
        )
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: FMSpacing.lg) {
            Spacer(minLength: FMSpacing.sm)

            OnboardingArtwork(pageID: page.id)
                .frame(maxWidth: 300)
                .frame(maxHeight: 238)

            VStack(spacing: FMSpacing.sm) {
                Text(page.title)
                    .font(FMTypography.heroTitle)
                    .foregroundStyle(FMColors.brandTitle)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(page.description)
                    .font(FMTypography.body)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 360)

            Spacer(minLength: FMSpacing.sm)
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
                detailSymbol: "clock.fill",
                caption: "00:42 피드백"
            )
        case 2:
            ArtworkConfiguration(
                detailSymbol: "sparkles",
                caption: "함께 만드는 성장"
            )
        case 3:
            ArtworkConfiguration(
                detailSymbol: "bell.badge.fill",
                caption: "가입 신청 · 피드백 · 멘션"
            )
        case 4:
            ArtworkConfiguration(
                detailSymbol: "video.badge.plus",
                caption: "첫 영상 올리기"
            )
        default:
            ArtworkConfiguration(
                detailSymbol: "record.circle",
                caption: "나의 모의 면접"
            )
        }
    }

    var body: some View {
        VStack(spacing: FMSpacing.md) {
            artworkContent

            Label(configuration.caption, systemImage: configuration.detailSymbol)
                .font(FMTypography.feedMetaEmphasis)
                .foregroundStyle(FMColors.brandTitle)
                .padding(.horizontal, FMSpacing.sm)
                .padding(.vertical, FMSpacing.xs)
                .background(FMColors.supportSurface)
                .clipShape(Capsule())
        }
        .frame(width: 244, height: 204)
        .background(FMColors.elevatedBackground)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous)
                .stroke(FMColors.supportAccent.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: FMShadow.cardColor, radius: 12, y: 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artworkContent: some View {
        switch pageID {
        case 1:
            ZStack {
                FMPracticeSymbol(size: 86, showsEncouragement: false)

                Text("00:42")
                    .font(FMTypography.font(size: 12, relativeTo: .caption, weight: .bold))
                    .foregroundStyle(FMColors.brandTitle)
                    .padding(.horizontal, FMSpacing.xs)
                    .padding(.vertical, FMSpacing.xxs)
                    .background(FMColors.background, in: Capsule())
                    .offset(x: 66, y: 38)
            }
        case 2:
            HStack(spacing: -10) {
                memberAvatar(initial: "서", color: FMColors.supportAccent)
                memberAvatar(initial: "민", color: FMColors.primaryAction)
                memberAvatar(initial: "나", color: FMColors.coral)
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(FMColors.coral, in: Circle())
                    .offset(x: 8, y: 8)
            }
        case 3:
            ZStack {
                Image(systemName: "bell.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(FMColors.brandTitle)

                Circle()
                    .fill(FMColors.coral)
                    .frame(width: 18, height: 18)
                    .overlay {
                        Circle()
                            .stroke(FMColors.elevatedBackground, lineWidth: 3)
                    }
                    .offset(x: 24, y: -28)
            }
        case 4:
            HStack(spacing: FMSpacing.sm) {
                cycleStep(symbol: "video.fill", tint: FMColors.brandTitle)
                Image(systemName: "arrow.right")
                    .foregroundStyle(FMColors.secondaryLabel)
                cycleStep(symbol: "bubble.left.fill", tint: FMColors.supportAccent)
                Image(systemName: "arrow.right")
                    .foregroundStyle(FMColors.secondaryLabel)
                cycleStep(symbol: "star.fill", tint: FMColors.coral)
            }
        default:
            FMPracticeSymbol(size: 92)
        }
    }

    private func memberAvatar(initial: String, color: Color) -> some View {
        Text(initial)
            .font(FMTypography.headline)
            .foregroundStyle(.white)
            .frame(width: 58, height: 58)
            .background(color, in: Circle())
            .overlay {
                Circle()
                    .stroke(FMColors.elevatedBackground, lineWidth: 3)
            }
    }

    private func cycleStep(symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 44, height: 44)
            .background(FMColors.supportSurface, in: Circle())
    }
}

private struct ArtworkConfiguration {
    let detailSymbol: String
    let caption: String
}
