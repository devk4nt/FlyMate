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
                        await store.send(.refresh).finish()
                    }
                }

            case .failed(let error):
                FMErrorView(error: error) {
                    store.send(.refresh)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColors.canvas)
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
        .fmSheetStyle()
        .sheet(item: $store.scope(state: \.announcement, action: \.announcement)) { announcementStore in
            AnnouncementDetailView(store: announcementStore)
        }
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: FMSpacing.sm) {
            // Notification type icon
            Image(systemName: iconName)
                .font(.system(size: FMSizing.IconSize.md))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                Text(notification.title)
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.brandTitle)
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
                    .fill(FMColors.notificationBadgeFill)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("읽지 않음")
            }
        }
        .padding(.horizontal, FMSpacing.md)
        .padding(.vertical, FMSpacing.sm)
        .background(notification.isRead ? Color.clear : FMColors.supportSurface.opacity(0.72))
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
        case .announcement:
            return "bell.badge.fill"
        case .quickFeedbackReceived:
            return "heart.text.square.fill"
        case .recruitPost:
            return "person.2.badge.plus.fill"
        case .joinRequest:
            return "person.badge.clock"
        case .joinRequestApproved:
            return "person.crop.circle.badge.checkmark"
        case .joinRequestRejected:
            return "person.crop.circle.badge.xmark"
        case .newVideoInStudy:
            return "video.badge.plus"
        case .feedbackReminder:
            return "clock.badge.exclamationmark"
        }
    }

    private var iconColor: Color {
        FMColors.supportAccent
    }
}

#Preview("알림 없음") {
    var state = NotificationListFeature.State(userID: UUID())
    state.loadingState = .loaded([])
    return NavigationStack {
        NotificationListView(store: Store(initialState: state) { NotificationListFeature() })
    }
}
