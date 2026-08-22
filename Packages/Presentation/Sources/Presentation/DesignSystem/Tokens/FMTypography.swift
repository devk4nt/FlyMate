import SwiftUI
import UIKit

public enum FMTypography {
    public enum Weight {
        case regular
        case medium
        case semibold
        case bold

        fileprivate var fontName: String {
            switch self {
            case .regular:
                "Pretendard-Regular"
            case .medium:
                "Pretendard-Medium"
            case .semibold:
                "Pretendard-SemiBold"
            case .bold:
                "Pretendard-Bold"
            }
        }
    }

    /// Pretendard를 Dynamic Type 텍스트 스타일에 맞춰 확장한다.
    public static func font(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        weight: Weight = .regular
    ) -> Font {
        .custom(weight.fontName, size: size, relativeTo: textStyle)
    }

    /// UIKit 기반 내비게이션과 탭 구성요소에서도 동일한 글꼴을 사용한다.
    public static func uiFont(
        size: CGFloat,
        relativeTo textStyle: UIFont.TextStyle,
        weight: Weight = .regular
    ) -> UIFont? {
        guard let font = UIFont(name: weight.fontName, size: size) else { return nil }
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
    }

    public static var heroTitle: Font {
        font(size: 28, relativeTo: .title, weight: .bold)
    }

    public static var sectionTitle: Font {
        font(size: 17, relativeTo: .headline, weight: .semibold)
    }

    public static var largeTitle: Font {
        font(size: 22, relativeTo: .title2, weight: .semibold)
    }

    public static var title1: Font {
        font(size: 20, relativeTo: .title3, weight: .semibold)
    }

    public static var title2: Font {
        font(size: 20, relativeTo: .title3, weight: .semibold)
    }

    public static var title3: Font {
        font(size: 17, relativeTo: .headline, weight: .semibold)
    }

    public static var headline: Font {
        font(size: 17, relativeTo: .headline, weight: .semibold)
    }

    public static var body: Font {
        font(size: 17, relativeTo: .body)
    }

    public static var callout: Font {
        font(size: 16, relativeTo: .callout)
    }

    public static var caption1: Font {
        font(size: 12, relativeTo: .caption)
    }

    public static var caption2: Font {
        font(size: 11, relativeTo: .caption2)
    }

    public static var eyebrow: Font {
        font(size: 11, relativeTo: .caption2, weight: .semibold)
    }

    public static var cardTitle: Font {
        font(size: 17, relativeTo: .headline, weight: .semibold)
    }

    public static var badgeStrong: Font {
        font(size: 12, relativeTo: .caption, weight: .semibold)
    }

    // MARK: - Feed (인스타그램형 피드 전용)

    /// 피드 작성자명 — Dynamic Type의 subheadline 기준
    public static var authorName: Font {
        font(size: 15, relativeTo: .subheadline, weight: .semibold)
    }

    /// 피드 본문 — Dynamic Type의 subheadline 기준
    public static var feedBody: Font {
        font(size: 15, relativeTo: .subheadline)
    }

    /// 피드 보조 정보 (타임스탬프, 카운트) — Dynamic Type의 caption 기준
    public static var feedMeta: Font {
        font(size: 12, relativeTo: .caption)
    }

    /// 피드 보조 정보 강조 (재생 시간, 액션 라벨) — Dynamic Type의 caption 기준
    public static var feedMetaEmphasis: Font {
        font(size: 12, relativeTo: .caption, weight: .semibold)
    }
}
