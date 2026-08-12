import SwiftUI

public enum FMTypography {
    public static var heroTitle: Font {
        .system(.largeTitle, design: .rounded, weight: .bold)
    }

    public static var sectionTitle: Font {
        .system(.title2, design: .rounded, weight: .bold)
    }

    public static var largeTitle: Font {
        .system(.title, weight: .bold)
    }

    public static var title1: Font {
        .system(.title2, weight: .bold)
    }

    public static var title2: Font {
        .system(.title3, weight: .semibold)
    }

    public static var title3: Font {
        .system(.headline, weight: .semibold)
    }

    public static var headline: Font {
        .system(.headline, weight: .semibold)
    }

    public static var body: Font {
        .system(.body)
    }

    public static var callout: Font {
        .system(.callout)
    }

    public static var caption1: Font {
        .system(.caption)
    }

    public static var caption2: Font {
        .system(.caption2)
    }

    public static var eyebrow: Font {
        .system(.caption2, weight: .bold)
    }

    public static var cardTitle: Font {
        .system(.title3, weight: .bold)
    }

    public static var metric: Font {
        .system(.headline, weight: .bold)
    }

    public static var badgeStrong: Font {
        .system(.caption, weight: .bold)
    }

    // MARK: - Feed (인스타그램형 피드 전용)

    /// 피드 작성자명 — Dynamic Type의 subheadline 기준
    public static var authorName: Font {
        .system(.subheadline, weight: .semibold)
    }

    /// 피드 본문 — Dynamic Type의 subheadline 기준
    public static var feedBody: Font {
        .system(.subheadline)
    }

    /// 피드 보조 정보 (타임스탬프, 카운트) — Dynamic Type의 caption 기준
    public static var feedMeta: Font {
        .system(.caption)
    }

    /// 피드 보조 정보 강조 (재생 시간, 액션 라벨) — Dynamic Type의 caption 기준
    public static var feedMetaEmphasis: Font {
        .system(.caption, weight: .semibold)
    }
}
