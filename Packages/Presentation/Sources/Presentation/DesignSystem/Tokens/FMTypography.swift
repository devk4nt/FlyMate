import SwiftUI

public enum FMTypography {
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
}
