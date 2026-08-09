import SwiftUI

public enum FMTypography {
    public static var heroTitle: Font {
        .system(.largeTitle, design: .rounded, weight: .bold)
    }

    public static var sectionTitle: Font {
        .system(.title2, design: .rounded, weight: .bold)
    }

    public static var largeTitle: Font {
        .system(size: 28, weight: .bold)
    }

    public static var title1: Font {
        .system(size: 22, weight: .bold)
    }

    public static var title2: Font {
        .system(size: 20, weight: .semibold)
    }

    public static var title3: Font {
        .system(size: 18, weight: .semibold)
    }

    public static var headline: Font {
        .system(size: 16, weight: .semibold)
    }

    public static var body: Font {
        .system(size: 16, weight: .regular)
    }

    public static var callout: Font {
        .system(size: 14, weight: .regular)
    }

    public static var caption1: Font {
        .system(size: 12, weight: .regular)
    }

    public static var caption2: Font {
        .system(size: 11, weight: .regular)
    }

    // MARK: - Feed (인스타그램형 피드 전용)

    /// 피드 작성자명 — 14pt semibold
    public static var authorName: Font {
        .system(size: 14, weight: .semibold)
    }

    /// 피드 본문 — 14pt regular
    public static var feedBody: Font {
        .system(size: 14, weight: .regular)
    }

    /// 피드 보조 정보 (타임스탬프, 카운트) — 12pt regular
    public static var feedMeta: Font {
        .system(size: 12, weight: .regular)
    }

    /// 피드 보조 정보 강조 (재생 시간, 액션 라벨) — 12pt semibold
    public static var feedMetaEmphasis: Font {
        .system(size: 12, weight: .semibold)
    }
}
