import SwiftUI
import StoreKit
import ComposableArchitecture
import Core

public struct PaywallView: View {
    @Bindable var store: StoreOf<PaywallFeature>

    public init(store: StoreOf<PaywallFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: FMSpacing.lg) {
            // 닫기 버튼
            HStack {
                Spacer()
                Button {
                    store.send(.dismissTapped)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: FMSizing.IconSize.lg))
                        .foregroundStyle(FMColors.secondaryLabel)
                }
                .accessibilityLabel("닫기")
            }

            Spacer()

            // 아이콘 + 제한 사유
            VStack(spacing: FMSpacing.md) {
                Image(systemName: store.reason.iconName)
                    .font(.system(size: FMSizing.IconSize.hero))
                    .foregroundStyle(FMColors.accent)

                Text(store.reason.title)
                    .font(FMTypography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(FMColors.label)
                    .multilineTextAlignment(.center)

                Text(store.reason.message)
                    .font(FMTypography.callout)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            // 프리미엄 혜택 목록
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                benefitRow(icon: "person.3.fill", text: "스터디 5개 생성 · 5개 참여")
                benefitRow(icon: "video.fill", text: "최대 3분 영상 촬영")
                benefitRow(icon: "person.badge.plus", text: "스터디당 최대 8명 참여")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FMSpacing.md)
            .background(FMColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))

            Spacer()

            // 구매 버튼
            VStack(spacing: FMSpacing.sm) {
                if let yearly = store.yearlyProduct {
                    FMButton(
                        title: "연간 구독 \(yearly.displayPrice)",
                        style: .primary,
                        isLoading: store.purchaseInProgress
                    ) {
                        store.send(.purchaseTapped(yearly))
                    }
                }

                if let monthly = store.monthlyProduct {
                    FMButton(
                        title: "월간 구독 \(monthly.displayPrice)",
                        style: .secondary,
                        isLoading: store.purchaseInProgress
                    ) {
                        store.send(.purchaseTapped(monthly))
                    }
                }

                Button {
                    store.send(.restoreTapped)
                } label: {
                    Text("이전 구매 복원")
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)
                }
                .disabled(store.purchaseInProgress)
                .accessibilityLabel("이전 구매 복원")
            }
        }
        .padding(FMSpacing.lg)
        .fmSheetStyle()
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Benefit Row

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: FMSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: FMSizing.IconSize.sm))
                .foregroundStyle(FMColors.accent)
                .frame(width: 24)

            Text(text)
                .font(FMTypography.callout)
                .foregroundStyle(FMColors.label)
        }
        .accessibilityElement(children: .combine)
    }
}
