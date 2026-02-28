import SwiftUI
import StoreKit
import ComposableArchitecture
import Core

public struct SubscriptionView: View {
    @Bindable var store: StoreOf<SubscriptionFeature>

    public init(store: StoreOf<SubscriptionFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: FMSpacing.lg) {
                currentPlanSection
                comparisonSection
                purchaseSection
                restoreSection
            }
            .padding(FMSpacing.md)
        }
        .navigationTitle("구독 관리")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Current Plan

    private var currentPlanSection: some View {
        VStack(spacing: FMSpacing.sm) {
            Image(systemName: store.isPremium ? "crown.fill" : "person.fill")
                .font(.system(size: 40))
                .foregroundStyle(store.isPremium ? FMColors.accent : FMColors.secondaryLabel)

            Text(store.isPremium ? "프리미엄" : "무료 플랜")
                .font(FMTypography.title2)
                .fontWeight(.bold)
                .foregroundStyle(FMColors.label)

            if let entitlement = store.entitlement {
                Text("스터디 \(entitlement.currentOwnedStudies)/\(entitlement.maxOwnedStudies)개 생성 · \(entitlement.currentJoinedStudies)/\(entitlement.maxJoinedStudies)개 참여")
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(FMSpacing.xl)
        .background(FMColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Comparison

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: FMSpacing.md) {
            Text("플랜 비교")
                .font(FMTypography.headline)
                .foregroundStyle(FMColors.label)

            VStack(spacing: 0) {
                comparisonRow(feature: "스터디 생성", free: "1개", premium: "5개")
                Divider()
                comparisonRow(feature: "스터디 참여", free: "1개", premium: "5개")
                Divider()
                comparisonRow(feature: "영상 길이", free: "1분", premium: "10분")
                Divider()
                comparisonRow(feature: "스터디 멤버", free: "3명", premium: "8명")
            }
            .background(FMColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))
        }
    }

    private func comparisonRow(feature: String, free: String, premium: String) -> some View {
        HStack {
            Text(feature)
                .font(FMTypography.callout)
                .foregroundStyle(FMColors.label)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(free)
                .font(FMTypography.callout)
                .foregroundStyle(FMColors.secondaryLabel)
                .frame(width: 60)

            Text(premium)
                .font(FMTypography.callout)
                .fontWeight(.semibold)
                .foregroundStyle(FMColors.accent)
                .frame(width: 60)
        }
        .padding(.horizontal, FMSpacing.md)
        .padding(.vertical, FMSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(feature): 무료 \(free), 프리미엄 \(premium)")
    }

    // MARK: - Purchase

    @ViewBuilder
    private var purchaseSection: some View {
        if !store.isPremium {
            VStack(spacing: FMSpacing.sm) {
                if let yearly = store.yearlyProduct {
                    productButton(product: yearly, badge: "연간 (최대 할인)")
                }

                if let monthly = store.monthlyProduct {
                    productButton(product: monthly, badge: nil)
                }
            }
        }
    }

    private func productButton(product: Product, badge: String?) -> some View {
        Button {
            store.send(.purchaseTapped(product))
        } label: {
            VStack(spacing: FMSpacing.xxs) {
                if let badge {
                    Text(badge)
                        .font(FMTypography.caption2)
                        .foregroundStyle(FMColors.accent)
                }

                Text(product.displayPrice)
                    .font(FMTypography.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(product.displayName)
                    .font(FMTypography.caption1)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FMSpacing.md)
            .background(FMColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))
        }
        .disabled(store.purchaseInProgress)
        .opacity(store.purchaseInProgress ? 0.6 : 1.0)
        .overlay {
            if store.purchaseInProgress {
                ProgressView()
                    .tint(.white)
            }
        }
        .accessibilityLabel("\(product.displayName) \(product.displayPrice)로 구독하기")
    }

    // MARK: - Restore

    private var restoreSection: some View {
        Button {
            store.send(.restoreTapped)
        } label: {
            Text("이전 구매 복원")
                .font(FMTypography.callout)
                .foregroundStyle(FMColors.accent)
        }
        .disabled(store.purchaseInProgress)
        .accessibilityLabel("이전 구매 복원")
    }
}
