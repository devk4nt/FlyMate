import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct BlockedUsersView: View {
    @Bindable var store: StoreOf<BlockedUsersFeature>

    public init(store: StoreOf<BlockedUsersFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.blockedUsers {
            case .idle, .loading:
                ScrollView {
                    LazyVStack(spacing: FMSpacing.md) {
                        ForEach(0..<6, id: \.self) { _ in
                            FMSkeletonView.listRow
                        }
                    }
                    .padding(FMSpacing.md)
                }

            case .loaded(let users):
                if users.isEmpty {
                    FMEmptyState(
                        systemImage: "person.crop.circle.badge.checkmark",
                        title: "차단한 사용자가 없어요",
                        description: "차단한 사용자의 영상과 피드백은 보이지 않아요"
                    )
                } else {
                    List(users) { user in
                        BlockedUserRow(user: user) {
                            store.send(.unblockTapped(user))
                        }
                        .listRowBackground(FMColors.background)
                    }
                    .scrollContentBackground(.hidden)
                }

            case .failed(let error):
                FMErrorView(error: error) {
                    store.send(.retryTapped)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColors.canvas)
        .navigationTitle("차단한 사용자")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.send(.onAppear) }
        .fmToast(
            isPresented: Binding(
                get: { store.showToast },
                set: { _ in store.send(.dismissToast) }
            ),
            message: store.toastMessage,
            type: .info
        )
    }
}

// MARK: - Row

private struct BlockedUserRow: View {
    let user: BlockedUser
    let onUnblock: () -> Void

    var body: some View {
        HStack(spacing: FMSpacing.sm) {
            FMProfileImage(url: user.profileImageURL, name: user.name, size: .sm)

            VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                Text(user.name)
                    .font(FMTypography.body)
                    .foregroundStyle(FMColors.label)

                Text("\(user.blockedAt.relativeString) 차단")
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.secondaryLabel)
            }

            Spacer(minLength: 0)

            Button {
                onUnblock()
            } label: {
                Text("차단 해제")
                    .font(FMTypography.caption1)
                    .fontWeight(.semibold)
                    .foregroundStyle(FMColors.accent)
                    .padding(.horizontal, FMSpacing.sm)
                    .padding(.vertical, FMSpacing.xxs)
                    .background(FMColors.accent.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(user.name) 차단 해제")
        }
        .padding(.vertical, FMSpacing.xxs)
    }
}

#Preview("차단한 사용자 없음") {
    var state = BlockedUsersFeature.State()
    state.blockedUsers = .loaded([])
    return NavigationStack {
        BlockedUsersView(store: Store(initialState: state) { BlockedUsersFeature() })
    }
}
