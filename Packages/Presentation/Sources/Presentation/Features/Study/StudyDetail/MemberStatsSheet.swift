import SwiftUI
import ComposableArchitecture
import Core
import Domain
import Kingfisher

struct MemberStatsSheet: View {
    let store: StoreOf<MemberStatsFeature>

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("활동 현황")
                .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
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
        VStack(spacing: FMSpacing.lg) {
            profileHeader
            LazyVGrid(columns: gridColumns, spacing: FMSpacing.sm) {
                ForEach(0..<4, id: \.self) { _ in
                    FMSkeletonView(height: 80, cornerRadius: FMSpacing.CornerRadius.md)
                }
            }
            .padding(.horizontal, FMSpacing.md)
            Spacer()
        }
        .padding(.top, FMSpacing.lg)
    }

    private func loadedView(stats: MemberStats) -> some View {
        VStack(spacing: FMSpacing.lg) {
            profileHeader

            LazyVGrid(columns: gridColumns, spacing: FMSpacing.sm) {
                statCard(
                    icon: "calendar",
                    title: "참여 시작일",
                    value: formattedDate(stats.joinedAt)
                )
                statCard(
                    icon: "video",
                    title: "올린 영상",
                    value: "\(stats.videosUploadedCount)"
                )
                statCard(
                    icon: "envelope.open",
                    title: "받은 피드백",
                    value: "\(stats.feedbackReceivedCount)"
                )
                statCard(
                    icon: "text.bubble",
                    title: "남긴 피드백",
                    value: "\(stats.feedbackGivenCount)"
                )
            }
            .padding(.horizontal, FMSpacing.md)

            Spacer()
        }
        .padding(.top, FMSpacing.lg)
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: FMSpacing.xs) {
            if let url = store.member.profileImageURL {
                KFImage(url)
                    .resizable()
                    .placeholder {
                        profilePlaceholder
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
            } else {
                profilePlaceholder
            }

            HStack(spacing: FMSpacing.xs) {
                Text(store.member.userName)
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.label)

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

    private var profilePlaceholder: some View {
        Circle()
            .fill(FMColors.secondaryBackground)
            .frame(width: 64, height: 64)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(FMColors.secondaryLabel)
            }
    }

    // MARK: - Stat Card

    private func statCard(icon: String, title: String, value: String) -> some View {
        FMCard(padding: FMSpacing.sm) {
            VStack(spacing: FMSpacing.xs) {
                Image(systemName: icon)
                    .font(FMTypography.title3)
                    .foregroundStyle(FMColors.primary)
                    .accessibilityHidden(true)

                Text(value)
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.label)

                Text(title)
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.secondaryLabel)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }

    // MARK: - Helpers

    private var gridColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter.string(from: date)
    }
}
