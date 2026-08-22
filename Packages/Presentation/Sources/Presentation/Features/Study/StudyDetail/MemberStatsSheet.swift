import SwiftUI
import ComposableArchitecture
import Core
import Domain

struct MemberStatsSheet: View {
    let store: StoreOf<MemberStatsFeature>

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("활동 현황")
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

    private func loadedView(stats: MemberStats) -> some View {
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
            FMProfileImage(url: store.member.profileImageURL, name: store.member.userName, size: .xl)

            HStack(spacing: FMSpacing.xs) {
                Text(store.member.userName)
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.label)

                FMVerifiedBadge(userID: store.member.userID)

                if store.member.role == .owner {
                    Text("방장")
                        .font(FMTypography.caption2)
                        .foregroundStyle(FMColors.primary)
                        .padding(.horizontal, FMSpacing.xs)
                        .padding(.vertical, FMSpacing.xxxs)
                        .background(FMColors.primary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(store.member.userName)\(store.member.role == .owner ? ", 방장" : "")")
    }

    // MARK: - Activity Card

    private func activityCard(stats: MemberStats) -> some View {
        VStack(alignment: .leading, spacing: FMSpacing.sm) {
            Text("스터디 활동")
                .font(FMTypography.headline)
                .foregroundStyle(FMColors.label)

            FMCard(padding: 0) {
                VStack(spacing: 0) {
                    statRow(
                        icon: "calendar",
                        title: "참여 시작일",
                        value: formattedDate(stats.joinedAt)
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

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter.string(from: date)
    }
}
