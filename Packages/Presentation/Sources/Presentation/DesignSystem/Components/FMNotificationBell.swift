import SwiftUI

public struct FMNotificationBell: View {
    private let unreadCount: Int
    private let action: () -> Void

    public init(unreadCount: Int, action: @escaping () -> Void) {
        self.unreadCount = unreadCount
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(FMColors.label)
                    .frame(width: 32, height: 32)

                if unreadCount > 0 {
                    FMBadge(count: unreadCount)
                        .scaleEffect(0.88)
                        .padding(.top, 1)
                }
            }
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("알림")
        .accessibilityValue(unreadCount > 0 ? "읽지 않은 알림 \(unreadCount)개" : "새 알림 없음")
        .accessibilityHint("알림 목록을 열려면 이중 탭하세요")
    }
}

#Preview {
    HStack(spacing: FMSpacing.xl) {
        FMNotificationBell(unreadCount: 0) {}
        FMNotificationBell(unreadCount: 3) {}
        FMNotificationBell(unreadCount: 100) {}
    }
}
