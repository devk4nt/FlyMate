import SwiftUI
import ComposableArchitecture

public struct OnboardingView: View {
    let store: StoreOf<OnboardingFeature>

    public init(store: StoreOf<OnboardingFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            // 반투명 배경
            Color.black.opacity(FMOpacity.half)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            FMCard(
                padding: FMSpacing.lg,
                cornerRadius: FMSpacing.CornerRadius.lg
            ) {
                VStack(spacing: FMSpacing.md) {
                    // 건너뛰기 버튼 (마지막 페이지가 아닐 때)
                    HStack {
                        Spacer()
                        if !store.isLastPage {
                            Button {
                                store.send(.skipTapped)
                            } label: {
                                Text("건너뛰기")
                                    .font(FMTypography.callout)
                                    .foregroundStyle(FMColors.secondaryLabel)
                            }
                            .accessibilityLabel("건너뛰기")
                            .accessibilityHint("온보딩을 건너뛰고 앱을 시작합니다")
                        }
                    }
                    .frame(height: FMSpacing.lg)

                    // 페이지 콘텐츠
                    TabView(selection: Binding(
                        get: { store.currentPage },
                        set: { store.send(.pageChanged($0)) }
                    )) {
                        ForEach(store.pages) { page in
                            VStack(spacing: FMSpacing.sm) {
                                Text(page.title)
                                    .font(FMTypography.title2)
                                    .foregroundStyle(FMColors.label)
                                    .multilineTextAlignment(.center)
                                    .accessibilityAddTraits(.isHeader)

                                Text(page.description)
                                    .font(FMTypography.body)
                                    .foregroundStyle(FMColors.secondaryLabel)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, FMSpacing.sm)
                            .tag(page.id)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(page.title). \(page.description)")
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: FMSizing.cardStandard)

                    // 페이지 인디케이터
                    HStack(spacing: FMSpacing.xs) {
                        ForEach(store.pages) { page in
                            Circle()
                                .fill(page.id == store.currentPage ? FMColors.accent : FMColors.border)
                                .frame(width: FMSizing.dot, height: FMSizing.dot)
                                .animation(.easeInOut(duration: 0.2), value: store.currentPage)
                        }
                    }
                    .accessibilityLabel("페이지 \(store.currentPage + 1) / \(store.pages.count)")

                    // 시작하기 버튼 (마지막 페이지)
                    if store.isLastPage {
                        FMButton(title: "시작하기", style: .primary) {
                            store.send(.startTapped)
                        }
                        .accessibilityHint("온보딩을 완료하고 앱을 시작합니다")
                    }
                }
            }
            .padding(.horizontal, FMSpacing.xl)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("앱 소개")
    }
}
