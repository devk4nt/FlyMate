import SwiftUI
import ComposableArchitecture
import Core
import Domain

/// 설정 > 나의 활동 — 참여 중인 모든 스터디를 합산한 활동 현황 시트 (MemberStatsSheet와 동일한 레이아웃)
struct MyActivitySheet: View {
    let store: StoreOf<MyActivityFeature>

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("나의 활동")
                .navigationBarTitleDisplayMode(.inline)
        }
        .fmSheetStyle()
        .presentationDetents([.fraction(0.68), .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            store.send(.onAppear)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch store.stats {
        case .idle, .loading:
            loadingView
        case .loaded(let stats):
            loadedView(stats: stats)
        case .failed(let error):
            FMErrorView(error: error) {
                store.send(.retry)
            }
        }
    }

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: FMSpacing.lg) {
                profileHeader
                FMSkeletonView(height: 224, cornerRadius: FMSpacing.CornerRadius.lg)
                    .padding(.horizontal, FMSpacing.md)
            }
            .padding(.top, FMSpacing.lg)
            .padding(.bottom, FMSpacing.xxl)
        }
    }

    private func loadedView(stats: MyActivityStats) -> some View {
        ScrollView {
            VStack(spacing: FMSpacing.lg) {
                profileHeader
                activityCard(stats: stats)
            }
            .padding(.top, FMSpacing.lg)
            .padding(.bottom, FMSpacing.xxl)
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: FMSpacing.xs) {
            FMProfileImage(
                url: store.currentUser.profileImageURL,
                name: store.currentUser.name,
                size: .xl
            )

            Text(store.currentUser.name)
                .font(FMTypography.headline)
                .foregroundStyle(FMColors.label)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(store.currentUser.name)
    }

    // MARK: - Activity Card

    private func activityCard(stats: MyActivityStats) -> some View {
        VStack(alignment: .leading, spacing: FMSpacing.sm) {
            Text("전체 스터디 활동")
                .font(FMTypography.headline)
                .foregroundStyle(FMColors.label)

            FMCard(padding: 0) {
                VStack(spacing: 0) {
                    statRow(
                        icon: "person.3",
                        title: "참여 중인 스터디",
                        value: "\(stats.studiesCount)개"
                    )

                    Divider()
                        .padding(.leading, FMSizing.IconContainer.md + FMSpacing.md * 2)

                    statRow(
                        icon: "video",
                        title: "올린 영상",
                        value: "\(stats.videosUploadedCount)개"
                    )

                    Divider()
                        .padding(.leading, FMSizing.IconContainer.md + FMSpacing.md * 2)

                    statRow(
                        icon: "envelope.open",
                        title: "받은 피드백",
                        value: "\(stats.feedbackReceivedCount)개"
                    )

                    Divider()
                        .padding(.leading, FMSizing.IconContainer.md + FMSpacing.md * 2)

                    statRow(
                        icon: "text.bubble",
                        title: "남긴 피드백",
                        value: "\(stats.feedbackGivenCount)개"
                    )
                }
            }
        }
        .padding(.horizontal, FMSpacing.md)
    }

    private func statRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: FMSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: FMSizing.IconSize.sm, weight: .semibold))
                .foregroundStyle(FMColors.iconAccent)
                .frame(width: FMSizing.IconContainer.md, height: FMSizing.IconContainer.md)
                .background(FMColors.primary.opacity(0.1), in: Circle())
                .accessibilityHidden(true)

            Text(title)
                .font(FMTypography.body)
                .foregroundStyle(FMColors.label)

            Spacer(minLength: FMSpacing.sm)

            Text(value)
                .font(FMTypography.headline)
                .foregroundStyle(FMColors.label)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, FMSpacing.md)
        .padding(.vertical, FMSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }
}
