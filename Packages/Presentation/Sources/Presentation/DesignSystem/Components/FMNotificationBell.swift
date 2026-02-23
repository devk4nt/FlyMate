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
            Image(systemName: unreadCount > 0 ? "bell.badge" : "bell")
                .font(.body)
                .foregroundStyle(FMColors.label)
                .overlay(alignment: .topTrailing) {
                    if unreadCount > 0 {
                        FMBadge(count: unreadCount)
                            .offset(x: 8, y: -8)
                    }
                }
                .padding(.top, 8)
                .padding(.trailing, 8)
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
