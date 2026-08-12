import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public enum FMColors {
    // Asset catalog colors (requires "Primary" / "Secondary" color sets in Resources)
    public static let primary = Color("Primary", bundle: .module)
    public static let secondary = Color("Secondary", bundle: .module)

    // MARK: - Air Blue palette

    public static let koreanAirDarkBlue = Color(red: 0.019608, green: 0.090196, blue: 0.400000)
    public static let airBlue = Color(red: 0.290196, green: 0.662745, blue: 0.847059)
    public static let iceBlue = Color(red: 0.552941, green: 0.843137, blue: 0.933333)
    public static let blushCoral = Color(red: 1.000000, green: 0.498039, blue: 0.623529)
    public static let deepIndigo = koreanAirDarkBlue
    public static let brandRed = blushCoral

    // Semantic brand colors.
    public static let accent = primary
    public static let accentFill = Color(red: 0.188235, green: 0.427451, blue: 0.650980)
    public static let onAccent = Color.white
    public static let highlight = blushCoral
    public static let subtleAccentSurface = iceBlue
    public static let launchBackground = primary
    public static let mediaBadgeForeground = deepIndigo
    public static let success = Color(red: 0.12, green: 0.67, blue: 0.42)
    public static let warning = Color(red: 0.96, green: 0.58, blue: 0.12)

    // Destructive colors have separate roles so text remains legible while
    // filled buttons can continue to use white labels in both appearances.
    public static let destructiveFill = Color(red: 0.780392, green: 0.207843, blue: 0.270588)

    #if canImport(UIKit)
    public static let actionForeground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.55, green: 0.84, blue: 0.93, alpha: 1)
            : UIColor(red: 0.188235, green: 0.427451, blue: 0.650980, alpha: 1)
    })
    public static let attentionFill = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.61, blue: 0.71, alpha: 1)
            : UIColor(red: 0.71, green: 0.25, blue: 0.44, alpha: 1)
    })
    public static let attentionForeground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.14, blue: 0.21, alpha: 1)
            : .white
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
    #else
    public static let actionForeground = accentFill
    public static let attentionFill = Color(red: 0.71, green: 0.25, blue: 0.44)
    public static let attentionForeground = Color.white
    public static let destructive = Color(red: 0.78, green: 0.21, blue: 0.27)
    public static let destructiveSurface = Color(red: 0.99, green: 0.93, blue: 0.94)
    public static let destructiveBorder = Color(red: 0.95, green: 0.72, blue: 0.75)
    #endif

    // Semantic roles for non-button interactive and decorative content.
    public static let iconAccent = actionForeground
    public static let selection = actionForeground
    public static let badgeForeground = actionForeground
    public static let decorativeBrand = brandInk

    // Adaptive brand surfaces keep highlighted content readable in both modes.
    #if canImport(UIKit)
    public static let brandInk = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.45, green: 0.76, blue: 0.92, alpha: 1)
            : UIColor(red: 0.290196, green: 0.662745, blue: 0.847059, alpha: 1)
    })
    public static let softCanvas = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.05, green: 0.07, blue: 0.10, alpha: 1)
            : UIColor(red: 0.95, green: 0.98, blue: 1.00, alpha: 1)
    })
    #else
    public static let brandInk = airBlue
    public static let softCanvas = Color(red: 0.95, green: 0.98, blue: 1.00)
    #endif

    /// High-contrast brand surface intended for white foreground content.
    /// Both stops keep normal white text above WCAG AA 4.5:1.
    public static let brandGradient = LinearGradient(
        colors: [
            Color(red: 0.188235, green: 0.427451, blue: 0.650980),
            koreanAirDarkBlue
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Foreground token for content placed on `brandGradient`.
    public static let onBrand = Color.white

    public static let featureGradient = LinearGradient(
        colors: [
            Color(red: 0.188235, green: 0.427451, blue: 0.650980),
            koreanAirDarkBlue
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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
