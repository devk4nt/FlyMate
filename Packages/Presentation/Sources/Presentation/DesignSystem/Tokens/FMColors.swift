import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// FlyMate 색상 시스템.
///
/// 팔레트는 딱 3색으로 결정한다:
/// - **navy**  — 제목, 주요 액션(CTA), 선택 상태
/// - **sky**   — 보조 액센트, 아이콘, 배지
/// - **coral** — 강조·주목 포인트(완료, 하이라이트)
///
/// 이 아래는 위 3색 + 시스템 중립색을 "역할(semantic role)"에 매핑한 것이다.
/// 뷰에서는 raw 팔레트가 아니라 역할 토큰(accent, brandTitle, iconAccent...)을 쓴다.
public enum FMColors {
    // MARK: - Raw palette (원색 — 직접 쓰지 말고 아래 역할 토큰 사용)

    /// 딥 네이비. 제목·주요 액션.
    static let navy = Color(red: 0.019608, green: 0.090196, blue: 0.400000)
    /// 스카이블루. 보조 액센트·아이콘.
    static let sky = Color(red: 0.290196, green: 0.662745, blue: 0.847059)
    /// 밝은 코랄. 성취·완료 등 소량 포인트 전용(흰 글자 올리지 말 것).
    static let coral = Color(red: 1.000000, green: 0.498039, blue: 0.623529)
    /// 네이비와 스카이 사이 중간 블루. 그라디언트/채움 버튼 상단 스톱 전용.
    static let ocean = Color(red: 0.188235, green: 0.427451, blue: 0.650980)

    // MARK: - Brand roles (에셋 카탈로그 기반)

    /// 에셋 "Primary" 컬러셋. 라이트/다크 자동 대응.
    public static let primary = Color("Primary", bundle: .module)
    /// 에셋 "Secondary" 컬러셋.
    public static let secondary = Color("Secondary", bundle: .module)

    public static let accent = primary
    public static let accentFill = ocean
    public static let onAccent = Color.white

    // MARK: - Status roles

    public static let success = Color(red: 0.12, green: 0.67, blue: 0.42)
    public static let warning = Color(red: 0.96, green: 0.58, blue: 0.12)
    /// 채움형 파괴적 버튼 배경(흰 글자 유지).
    public static let destructiveFill = Color(red: 0.780392, green: 0.207843, blue: 0.270588)

    // MARK: - Adaptive brand roles (라이트/다크 명시 대응)

    #if canImport(UIKit)
    /// 주요 제목과 핵심 행동에 쓰는 딥 네이비. 다크에서는 밝은 스카이로.
    public static let brandTitle = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.67, green: 0.86, blue: 0.96, alpha: 1)   // light navy
            : UIColor(red: 0.019608, green: 0.090196, blue: 0.400000, alpha: 1)  // navy
    })
    /// 주요 액션(CTA) 색. 라이트=navy, 다크=sky. (대한항공 브랜드 네이비 유지)
    public static let primaryAction = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.29, green: 0.66, blue: 0.85, alpha: 1)   // sky
            : UIColor(red: 0.019608, green: 0.090196, blue: 0.400000, alpha: 1)  // navy
    })
    /// 아이콘·상태·선택 배경의 스카이 계열.
    public static let supportAccent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.55, green: 0.84, blue: 0.93, alpha: 1)
            : UIColor(red: 0.29, green: 0.66, blue: 0.85, alpha: 1)   // sky
    })
    /// 선택/강조 요소의 옅은 표면.
    public static let supportSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.16, blue: 0.23, alpha: 1)
            : UIColor(red: 0.92, green: 0.97, blue: 1.00, alpha: 1)
    })
    /// 주목 포인트(코랄 계열). 라이트는 짙게, 다크는 밝게.
    public static let attentionFill = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.61, blue: 0.71, alpha: 1)
            : UIColor(red: 0.71, green: 0.25, blue: 0.44, alpha: 1)
    })
    public static let destructive = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.42, blue: 0.47, alpha: 1)
            : UIColor(red: 0.78, green: 0.21, blue: 0.27, alpha: 1)
    })
    public static let destructiveSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.21, green: 0.09, blue: 0.11, alpha: 1)
            : UIColor(red: 0.99, green: 0.93, blue: 0.94, alpha: 1)
    })
    public static let destructiveBorder = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.42, green: 0.17, blue: 0.20, alpha: 1)
            : UIColor(red: 0.95, green: 0.72, blue: 0.75, alpha: 1)
    })
    /// 브랜드 강조 표면(스카이). 다크에서 가독성 유지.
    public static let brandInk = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.45, green: 0.76, blue: 0.92, alpha: 1)
            : UIColor(red: 0.290196, green: 0.662745, blue: 0.847059, alpha: 1)  // sky
    })
    /// 콘텐츠 중심 화면의 기본 바탕.
    public static let softCanvas = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.045, green: 0.045, blue: 0.05, alpha: 1)
            : UIColor(red: 0.985, green: 0.988, blue: 0.992, alpha: 1)
    })
    #else
    public static let brandTitle = navy
    public static let primaryAction = navy
    public static let supportAccent = sky
    public static let supportSurface = Color(red: 0.92, green: 0.97, blue: 1.00)
    public static let attentionFill = Color(red: 0.71, green: 0.25, blue: 0.44)
    public static let destructive = Color(red: 0.78, green: 0.21, blue: 0.27)
    public static let destructiveSurface = Color(red: 0.99, green: 0.93, blue: 0.94)
    public static let destructiveBorder = Color(red: 0.95, green: 0.72, blue: 0.75)
    public static let brandInk = sky
    public static let softCanvas = Color(red: 0.95, green: 0.98, blue: 1.00)
    #endif

    // MARK: - Derived roles (위 역할의 별칭 — 의도를 이름으로 드러냄)

    public static let iconAccent = supportAccent
    public static let selection = primaryAction
    public static let badgeForeground = supportAccent
    public static let mediaBadgeForeground = navy
    public static let notificationBadgeFill = primaryAction
    public static let actionForeground = primaryAction

    #if canImport(UIKit)
    public static let notificationBadgeForeground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.019608, green: 0.090196, blue: 0.400000, alpha: 1)
            : .white
    })
    #else
    public static let notificationBadgeForeground = Color.white
    #endif

    // MARK: - Gradients

    /// 흰 글자용 고대비 브랜드 표면. 두 스톱 모두 WCAG AA(4.5:1) 이상.
    public static let brandGradient = LinearGradient(
        colors: [ocean, navy],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    public static let featureGradient = brandGradient
    /// `brandGradient` 위 콘텐츠용 전경색.
    public static let onBrand = Color.white

    // MARK: - System bridges (중립색 — 시스템 시맨틱 컬러 위임)

    #if canImport(UIKit)
    public static let background = Color(UIColor.systemBackground)
    public static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    public static let label = Color(UIColor.label)
    public static let secondaryLabel = Color(UIColor.secondaryLabel)
    public static let border = Color(UIColor.separator)
    public static let canvas = softCanvas
    public static let elevatedBackground = Color(UIColor.secondarySystemGroupedBackground)
    #else
    public static let background = Color(nsColor: .windowBackgroundColor)
    public static let secondaryBackground = Color(nsColor: .controlBackgroundColor)
    public static let label = Color(nsColor: .labelColor)
    public static let secondaryLabel = Color(nsColor: .secondaryLabelColor)
    public static let border = Color(nsColor: .separatorColor)
    public static let canvas = softCanvas
    public static let elevatedBackground = Color(nsColor: .controlBackgroundColor)
    #endif
}
