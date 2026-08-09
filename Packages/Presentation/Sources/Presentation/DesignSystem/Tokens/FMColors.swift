import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public enum FMColors {
    // Asset catalog colors (requires "Primary" / "Secondary" color sets in Resources)
    public static let primary = Color("Primary", bundle: .module)
    public static let secondary = Color("Secondary", bundle: .module)

    // Brand palette. Dark blue is sampled from Korean Air's official new-CI image;
    // the supporting colors are FlyMate adaptations for digital UI.
    public static let koreanAirDarkBlue = Color(red: 0.019608, green: 0.090196, blue: 0.400000)
    public static let airBlue = Color(red: 0.290196, green: 0.662745, blue: 0.847059)
    public static let brandRed = Color(red: 0.850980, green: 0.211765, blue: 0.243137)

    // Semantic brand colors. Air blue is the primary interaction color across
    // icons, controls, buttons, and selected states.
    public static let accent = primary
    public static let destructive = brandRed
    public static let success = Color(red: 0.12, green: 0.67, blue: 0.42)
    public static let warning = Color(red: 0.96, green: 0.58, blue: 0.12)

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

    public static let brandGradient = LinearGradient(
        colors: [airBlue, secondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let warmGradient = LinearGradient(
        colors: [secondary, brandRed],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    #if canImport(UIKit)
    public static let background = Color(UIColor.systemBackground)
    public static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    public static let label = Color(UIColor.label)
    public static let secondaryLabel = Color(UIColor.secondaryLabel)
    public static let border = Color(UIColor.separator)
    public static let canvas = Color(UIColor.systemGroupedBackground)
    public static let elevatedBackground = Color(UIColor.secondarySystemGroupedBackground)
    #else
    public static let background = Color(nsColor: .windowBackgroundColor)
    public static let secondaryBackground = Color(nsColor: .controlBackgroundColor)
    public static let label = Color(nsColor: .labelColor)
    public static let secondaryLabel = Color(nsColor: .secondaryLabelColor)
    public static let border = Color(nsColor: .separatorColor)
    public static let canvas = Color(nsColor: .underPageBackgroundColor)
    public static let elevatedBackground = Color(nsColor: .controlBackgroundColor)
    #endif
}
