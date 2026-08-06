import SwiftUI
import StoreKit
import ComposableArchitecture
import Core

public struct SubscriptionView: View {
    @Bindable var store: StoreOf<SubscriptionFeature>
    @Environment(\.dismiss) private var dismiss

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
            .padding(.horizontal, FMSpacing.md)
            .padding(.top, FMSpacing.sm)
            .padding(.bottom, FMSpacing.xxxl)
        }
        .background(FMColors.canvas)
        .navigationTitle("구독 관리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("닫기") { dismiss() }
            }
        }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Current Plan

    private var currentPlanSection: some View {
        VStack(alignment: .leading, spacing: FMSpacing.lg) {
            HStack(alignment: .top, spacing: FMSpacing.md) {
                Image(systemName: store.isPremium ? "crown.fill" : "person.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                    Text("현재 이용 중인 플랜")
                        .font(FMTypography.caption1)
                        .foregroundStyle(.white.opacity(0.78))

                    Text(store.isPremium ? "FlyMate 프리미엄" : "무료 플랜")
                        .font(FMTypography.title1)
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)

                Text(store.isPremium ? "PREMIUM" : "FREE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, FMSpacing.xs)
                    .padding(.vertical, FMSpacing.xxs)
                    .background(.white.opacity(0.18))
                    .clipShape(Capsule())
            }

            if let entitlement = store.entitlement {
                HStack(spacing: FMSpacing.sm) {
                    usageMetric(
                        icon: "plus.square.fill",
                        title: "스터디 생성",
                        value: "\(entitlement.currentOwnedStudies) / \(entitlement.maxOwnedStudies)"
                    )
                    usageMetric(
                        icon: "person.2.fill",
                        title: "스터디 참여",
                        value: "\(entitlement.currentJoinedStudies) / \(entitlement.maxJoinedStudies)"
                    )
                }
            } else {
                HStack(spacing: FMSpacing.xs) {
                    ProgressView()
                        .tint(.white)
                    Text("플랜 정보를 불러오는 중이에요")
                        .font(FMTypography.callout)
                        .foregroundStyle(.white.opacity(0.84))
                }
            }
        }
        .padding(FMSpacing.lg)
        .background(FMColors.brandGradient)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous))
        .shadow(color: FMColors.primary.opacity(0.24), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
    }

    private func usageMetric(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: FMSpacing.xxs) {
            Label(title, systemImage: icon)
                .font(FMTypography.caption1)
                .foregroundStyle(.white.opacity(0.76))

            Text(value)
                .font(FMTypography.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FMSpacing.sm)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous))
    }

    // MARK: - Comparison

    private var comparisonSection: some View {
        FMCard {
            VStack(alignment: .leading, spacing: FMSpacing.md) {
                sectionHeader(
                    icon: "chart.bar.fill",
                    title: "플랜 비교",
                    description: "프리미엄으로 더 넉넉하게 이용하세요."
                )

                Divider()

                HStack {
                    Text("혜택")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("무료")
                        .frame(width: 58)
                    Text("프리미엄")
                        .foregroundStyle(FMColors.primary)
                        .frame(width: 68)
                }
                .font(FMTypography.caption1)
                .foregroundStyle(FMColors.secondaryLabel)

                VStack(spacing: 0) {
                    comparisonRow(feature: "스터디 생성", free: "1개", premium: "5개", icon: "plus.square")
                    Divider().padding(.leading, 32)
                    comparisonRow(feature: "스터디 참여", free: "1개", premium: "5개", icon: "person.2")
                    Divider().padding(.leading, 32)
                    comparisonRow(feature: "영상 길이", free: "1분", premium: "3분", icon: "video")
                    Divider().padding(.leading, 32)
                    comparisonRow(feature: "스터디 멤버", free: "3명", premium: "8명", icon: "person.3")
                }
            }
        }
    }

    private func comparisonRow(feature: String, free: String, premium: String, icon: String) -> some View {
        HStack(spacing: FMSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FMColors.secondaryLabel)
                .frame(width: 24)

            Text(feature)
                .font(FMTypography.callout)
                .foregroundStyle(FMColors.label)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(free)
                .font(FMTypography.callout)
                .foregroundStyle(FMColors.secondaryLabel)
                .frame(width: 58)

            Text(premium)
                .font(FMTypography.headline)
                .foregroundStyle(FMColors.primary)
                .frame(width: 68)
        }
        .padding(.vertical, FMSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(feature): 무료 \(free), 프리미엄 \(premium)")
    }

    // MARK: - Purchase

    @ViewBuilder
    private var purchaseSection: some View {
        if !store.isPremium, store.yearlyProduct != nil || store.monthlyProduct != nil {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                sectionTitle("프리미엄 시작하기", caption: "언제든 App Store에서 해지할 수 있어요.")

                if let yearly = store.yearlyProduct {
                    productButton(product: yearly, badge: "추천 · 가장 큰 할인", emphasized: true)
                }

                if let monthly = store.monthlyProduct {
                    productButton(product: monthly, badge: "부담 없이 월 단위", emphasized: false)
                }
            }
        }
    }

    private func productButton(product: Product, badge: String, emphasized: Bool) -> some View {
        Button {
            store.send(.purchaseTapped(product))
        } label: {
            HStack(spacing: FMSpacing.md) {
                VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                    Text(badge)
                        .font(FMTypography.caption1)
                        .foregroundStyle(emphasized ? .white.opacity(0.8) : FMColors.primary)

                    Text(product.displayName)
                        .font(FMTypography.headline)
                        .foregroundStyle(emphasized ? .white : FMColors.label)
                }

                Spacer(minLength: FMSpacing.xs)

                VStack(alignment: .trailing, spacing: FMSpacing.xxxs) {
                    Text(product.displayPrice)
                        .font(FMTypography.title3)
                        .foregroundStyle(emphasized ? .white : FMColors.label)

                    Image(systemName: "arrow.right")
                        .font(FMTypography.caption1)
                        .foregroundStyle(emphasized ? .white.opacity(0.8) : FMColors.secondaryLabel)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(FMSpacing.md)
            .background {
                if emphasized {
                    FMColors.brandGradient
                } else {
                    FMColors.elevatedBackground
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous)
                    .stroke(emphasized ? Color.clear : FMColors.border.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: emphasized ? FMColors.primary.opacity(0.2) : FMShadow.cardColor, radius: 10, y: 5)
        }
        .disabled(store.purchaseInProgress)
        .opacity(store.purchaseInProgress ? 0.6 : 1.0)
        .overlay {
            if store.purchaseInProgress {
                ProgressView()
                    .tint(emphasized ? .white : FMColors.primary)
            }
        }
        .accessibilityLabel("\(product.displayName) \(product.displayPrice)로 구독하기")
    }

    // MARK: - Restore

    private var restoreSection: some View {
        VStack(spacing: FMSpacing.xs) {
            Button {
                store.send(.restoreTapped)
            } label: {
                Label("이전 구매 복원", systemImage: "arrow.clockwise")
                    .font(FMTypography.callout)
                    .foregroundStyle(FMColors.primary)
            }
            .disabled(store.purchaseInProgress)

            Text("결제는 Apple ID를 통해 안전하게 처리됩니다.")
                .font(FMTypography.caption2)
                .foregroundStyle(FMColors.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func sectionHeader(icon: String, title: String, description: String) -> some View {
        HStack(spacing: FMSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FMColors.primary)
                .frame(width: 36, height: 36)
                .background(FMColors.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                Text(title)
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.label)

                Text(description)
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.secondaryLabel)
            }
        }
    }

    private func sectionTitle(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
            Text(title)
                .font(FMTypography.title3)
                .foregroundStyle(FMColors.label)
            Text(caption)
                .font(FMTypography.caption1)
                .foregroundStyle(FMColors.secondaryLabel)
        }
    }
}
