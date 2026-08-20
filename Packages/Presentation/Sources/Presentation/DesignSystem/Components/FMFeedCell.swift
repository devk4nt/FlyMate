import SwiftUI
import Kingfisher

/// 작성자 헤더 + 영상 + 반응 푸터로 구성된 소셜 피드 셀.
public struct FMFeedCell: View {
    private let authorName: String
    private let authorProfileURL: URL?
    private let timeText: String
    private let thumbnailURL: URL?
    private let durationText: String
    private let title: String
    private let feedbackCount: Int

    public init(
        authorName: String,
        authorProfileURL: URL? = nil,
        timeText: String,
        thumbnailURL: URL?,
        durationText: String,
        title: String,
        feedbackCount: Int
    ) {
        self.authorName = authorName
        self.authorProfileURL = authorProfileURL
        self.timeText = timeText
        self.thumbnailURL = thumbnailURL
        self.durationText = durationText
        self.title = title
        self.feedbackCount = feedbackCount
    }

    public var body: some View {
        FMCard(style: .feed, padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                header
                media

                VStack(alignment: .leading, spacing: FMSpacing.xs) {
                    Text(title)
                        .font(FMTypography.cardTitle)
                        .foregroundStyle(FMColors.brandTitle)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    footer
                }
                .padding(FMSpacing.sm)
            }
        }
        .padding(.horizontal, FMSpacing.md)
        .padding(.vertical, FMSpacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(authorName)의 영상, \(title), 피드백 \(feedbackCount)개, \(timeText)")
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: FMSpacing.xs) {
            FMProfileImage(url: authorProfileURL, name: authorName, size: .sm)

            VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                Text(authorName)
                    .font(FMTypography.authorName)
                    .foregroundStyle(FMColors.brandTitle)

                Text("최근 활동 · \(timeText)")
                    .font(FMTypography.feedMeta)
                    .foregroundStyle(FMColors.secondaryLabel)
            }

            Spacer(minLength: 0)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: FMSizing.IconSize.sm, weight: .semibold))
                .foregroundStyle(FMColors.supportAccent)
        }
        .padding(FMSpacing.sm)
    }

    // MARK: - Media

    private var media: some View {
        ZStack {
            if let thumbnailURL {
                KFImage(thumbnailURL)
                    .resizable()
                    .placeholder {
                        Rectangle()
                            .fill(FMColors.secondaryBackground)
                            .overlay { ProgressView() }
                    }
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(FMColors.brandGradient.opacity(0.18))
                    .overlay {
                        Image(systemName: "video.fill")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(FMColors.primary.opacity(0.5))
                    }
            }

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 58, height: 58)
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: 2)
                }
                .shadow(color: .black.opacity(0.2), radius: 12, y: 5)
        }
        .aspectRatio(1.85, contentMode: .fit)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Text(durationText)
                .font(FMTypography.feedMetaEmphasis)
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, FMSpacing.xs)
                .padding(.vertical, FMSpacing.xxxs)
                .background(.black.opacity(0.6))
                .clipShape(Capsule())
                .padding(FMSpacing.xs)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: FMSpacing.md) {
            Label(
                feedbackCount > 0 ? "피드백 \(feedbackCount)" : "첫 피드백 남기기",
                systemImage: feedbackCount > 0 ? "heart.fill" : "bubble.left"
            )
            .foregroundStyle(feedbackCount > 0 ? FMColors.blushCoral : FMColors.supportAccent)

            Label("함께 보기", systemImage: "person.2")
                .foregroundStyle(FMColors.supportAccent)

            Spacer(minLength: 0)
        }
        .font(FMTypography.feedMetaEmphasis)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        LazyVStack(spacing: 0) {
            FMFeedCell(
                authorName: "김승무",
                timeText: "2시간 전",
                thumbnailURL: nil,
                durationText: "2:30",
                title: "기내 안내 방송 연습",
                feedbackCount: 3
            )
            FMFeedCell(
                authorName: "박아나",
                timeText: "어제",
                thumbnailURL: nil,
                durationText: "1:45",
                title: "뉴스 리딩 — 발음 위주로 봐주세요",
                feedbackCount: 0
            )
        }
    }
}
