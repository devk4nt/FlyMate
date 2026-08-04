import SwiftUI
import Kingfisher

/// 인스타그램형 영상 피드 셀 — 작성자 헤더 + 풀블리드 썸네일 + 정보 푸터 + 하단 구분선.
/// 카드가 아니라 경계선과 여백으로 구분되는 피드형 레이아웃의 기본 단위.
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
        VStack(alignment: .leading, spacing: 0) {
            header
            media
            footer
            Divider()
        }
        .background(FMColors.background)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(authorName)의 영상, \(title), 피드백 \(feedbackCount)개, \(timeText)")
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: FMSpacing.xs) {
            FMProfileImage(url: authorProfileURL, name: authorName, size: .md)

            Text(authorName)
                .font(FMTypography.authorName)
                .foregroundStyle(FMColors.label)

            Spacer()

            Text(timeText)
                .font(FMTypography.feedMeta)
                .foregroundStyle(FMColors.secondaryLabel)
        }
        .padding(.horizontal, FMSpacing.md)
        .padding(.vertical, FMSpacing.xs)
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
                    .fill(FMColors.secondaryBackground)
            }

            Image(systemName: "play.circle.fill")
                .font(.system(size: FMSizing.IconSize.xl))
                .foregroundStyle(.white.opacity(0.8))
                .shadow(radius: 4)
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipped()
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
        VStack(alignment: .leading, spacing: FMSpacing.xxs) {
            Text(title)
                .font(FMTypography.feedBody)
                .fontWeight(.semibold)
                .foregroundStyle(FMColors.label)
                .lineLimit(2)

            if feedbackCount > 0 {
                Text("피드백 \(feedbackCount)개")
                    .font(FMTypography.feedMeta)
                    .foregroundStyle(FMColors.secondaryLabel)
            } else {
                Text("첫 피드백을 남겨보세요")
                    .font(FMTypography.feedMeta)
                    .foregroundStyle(FMColors.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, FMSpacing.md)
        .padding(.vertical, FMSpacing.xs)
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
