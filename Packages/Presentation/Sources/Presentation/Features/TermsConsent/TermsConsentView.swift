import SwiftUI
import ComposableArchitecture
import Core

public struct TermsConsentView: View {
    let store: StoreOf<TermsConsentFeature>

    public init(store: StoreOf<TermsConsentFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: FMSpacing.xl) {
                    header

                    VStack(alignment: .leading, spacing: FMSpacing.lg) {
                        guidelineRow(
                            systemImage: "hand.raised.fill",
                            title: "부적절한 콘텐츠 무관용",
                            description: "모욕, 혐오, 음란, 불법 콘텐츠의 업로드를 금지해요. 위반 콘텐츠는 예고 없이 삭제돼요."
                        )
                        guidelineRow(
                            systemImage: "person.2.slash.fill",
                            title: "괴롭힘 금지",
                            description: "다른 사용자에 대한 비방, 위협, 괴롭힘을 금지해요. 반복 위반 시 계정 이용이 제한돼요."
                        )
                        guidelineRow(
                            systemImage: "exclamationmark.bubble.fill",
                            title: "신고와 차단",
                            description: "부적절한 콘텐츠는 신고할 수 있고, 사용자를 차단할 수 있어요. 신고된 콘텐츠는 24시간 내에 검토하고 조치해요."
                        )
                        guidelineRow(
                            systemImage: "lock.shield.fill",
                            title: "책임 있는 이용",
                            description: "업로드하는 영상과 피드백에 대한 책임은 작성자 본인에게 있어요. 타인의 영상을 무단으로 공유하지 마세요."
                        )
                    }
                }
                .padding(.horizontal, FMSpacing.lg)
                .padding(.top, FMSpacing.xxl)
                .padding(.bottom, FMSpacing.lg)
            }

            agreeButton
        }
        .background(FMColors.background)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: FMSpacing.sm) {
            Text("커뮤니티 가이드라인")
                .font(FMTypography.largeTitle)
                .foregroundStyle(FMColors.label)

            Text("FlyMate는 모두가 안전하게 피드백을 주고받는 공간을 지향해요. 서비스를 이용하려면 아래 약관에 동의해 주세요.")
                .font(FMTypography.body)
                .foregroundStyle(FMColors.secondaryLabel)
        }
    }

    // MARK: - Guideline Row

    private func guidelineRow(systemImage: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: FMSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: FMSizing.IconSize.md))
                .foregroundStyle(FMColors.accent)
                .frame(width: 36, height: 36)
                .background(FMColors.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                Text(title)
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.label)

                Text(description)
                    .font(FMTypography.callout)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Agree Button

    private var agreeButton: some View {
        VStack(spacing: FMSpacing.sm) {
            Text("동의하면 위 가이드라인을 지키기로 약속한 것으로 간주돼요.")
                .font(FMTypography.caption1)
                .foregroundStyle(FMColors.secondaryLabel)

            FMButton(title: "동의하고 시작하기") {
                store.send(.agreeTapped)
            }
            .accessibilityLabel("이용약관에 동의하고 시작하기")
        }
        .padding(.horizontal, FMSpacing.lg)
        .padding(.vertical, FMSpacing.md)
        .background(FMColors.background)
    }
}
