import SwiftUI

/// A small badge view displaying a count number in a branded capsule,
/// typically used for notification indicators.
public struct FMBadge: View {
    private let count: Int
    private let maxCount: Int

    public init(count: Int, maxCount: Int = 99) {
        self.count = count
        self.maxCount = maxCount
    }

    public var body: some View {
        if count > 0 {
            Text(displayText)
                .font(FMTypography.caption2)
                .foregroundStyle(FMColors.attentionForeground)
                .padding(.horizontal, FMSpacing.xxs + 2)
                .padding(.vertical, FMSpacing.xxxs)
                .background(FMColors.attentionFill)
                .clipShape(Capsule())
                .accessibilityLabel("알림 \(count)개")
        }
    }

    private var displayText: String {
        if count > maxCount {
            return "\(maxCount)+"
        }
        return "\(count)"
    }
}

#Preview {
    HStack(spacing: FMSpacing.md) {
        FMBadge(count: 1)
        FMBadge(count: 9)
        FMBadge(count: 42)
        FMBadge(count: 100)
    }
}
