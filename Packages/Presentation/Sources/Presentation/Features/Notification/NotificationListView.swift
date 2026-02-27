import ComposableArchitecture
import Core
import Domain
import SwiftUI

public struct NotificationListView: View {
    @Bindable var store: StoreOf<NotificationListFeature>

    public init(store: StoreOf<NotificationListFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.loadingState {
            case .idle, .loading:
                ScrollView {
                    LazyVStack(spacing: FMSpacing.sm) {
                        ForEach(0..<5, id: \.self) { _ in
                            FMSkeletonView.listRow
                                .padding(.horizontal, FMSpacing.md)
                        }
                    }
                    .padding(.vertical, FMSpacing.md)
                }

            case .loaded(let notifications):
                if notifications.isEmpty {
                    FMEmptyState(
                        systemImage: "bell.slash",
                        title: "알림이 없습니다",
                        description: "피드백을 받거나 태그되면 알림이 표시됩니다."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(notifications) { notification in
                                NotificationRow(notification: notification)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        store.send(.notificationTapped(notification))
                                    }
                                    .onAppear {
                                        if notification == notifications.last {
                                            store.send(.loadMore)
                                        }
                                    }

                                if notification != notifications.last {
                                    Divider()
                                        .padding(.leading, FMSpacing.xxl + FMSpacing.md)
                                }
                            }

                            if store.notifications.isLoadingMore {
                                ProgressView()
                                    .padding()
                            }
                        }
                    }
                    .refreshable {
                        store.send(.refresh)
                    }
                }

            case .failed(let error):
                FMErrorView(error: error) {
                    store.send(.refresh)
                }
            }
        }
        .navigationTitle("알림")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if store.hasUnread {
                    Button("모두 읽음") {
                        store.send(.markAllAsReadTapped)
                    }
                    .font(FMTypography.callout)
                    .accessibilityLabel("모든 알림을 읽음 처리")
                }
            }
        }
        .onAppear { store.send(.onAppear) }
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: FMSpacing.sm) {
            // Notification type icon
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                Text(notification.title)
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.label)
                    .lineLimit(1)

                Text(notification.body)
                    .font(FMTypography.callout)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .lineLimit(2)

                Text(notification.createdAt.relativeString)
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.secondaryLabel)
            }

            Spacer()

            // Unread indicator
            if !notification.isRead {
                Circle()
                    .fill(FMColors.accent)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("읽지 않음")
            }
        }
        .padding(.horizontal, FMSpacing.md)
        .padding(.vertical, FMSpacing.sm)
        .background(notification.isRead ? Color.clear : FMColors.secondaryBackground.opacity(0.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(notification.title), \(notification.body)")
        .accessibilityHint(notification.isRead ? "" : "읽지 않은 알림")
    }

    private var iconName: String {
        switch notification.type {
        case .feedbackOnMyVideo:
            return "bubble.left.fill"
        case .mentionedInFeedback:
            return "at"
        case .replyOnMyFeedback:
            return "arrowshape.turn.up.left.fill"
        case .mentionedInFeedbackComment:
            return "at"
        }
    }

    private var iconColor: Color {
        switch notification.type {
        case .feedbackOnMyVideo:
            return FMColors.primary
        case .mentionedInFeedback:
            return FMColors.accent
        case .replyOnMyFeedback:
            return FMColors.primary
        case .mentionedInFeedbackComment:
            return FMColors.accent
        }
    }
}
