import SwiftUI
import ComposableArchitecture
import Domain

public struct JoinRequestManagementView: View {
    @Bindable var store: StoreOf<JoinRequestManagementFeature>

    public init(store: StoreOf<JoinRequestManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        contentView
            .navigationTitle("참여 요청 관리")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                store.send(.onAppear)
            }
            .alert($store.scope(state: \.confirmAlert, action: \.confirmAlert))
    }

    @ViewBuilder
    private var contentView: some View {
        switch store.requests {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let requests):
            if requests.isEmpty {
                FMEmptyState(
                    systemImage: "person.crop.circle.badge.checkmark",
                    title: "대기 중인 참여 요청이 없습니다",
                    description: "새로운 참여 요청이 들어오면 여기에 표시됩니다."
                )
            } else {
                requestListView(requests)
            }

        case .failed(let error):
            FMErrorView(error: error) {
                store.send(.onAppear)
            }
        }
    }

    private func requestListView(_ requests: [JoinRequest]) -> some View {
        List {
            Section {
                ForEach(requests) { request in
                    requestRow(request)
                }
            } header: {
                Text("대기 중 \(requests.count)건")
                    .font(FMTypography.caption1)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func requestRow(_ request: JoinRequest) -> some View {
        let isProcessing = store.actionInProgress.contains(request.id)

        return HStack(spacing: FMSpacing.sm) {
            profileImage(request)

            VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                Text(request.userName)
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.label)

                Text(request.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.secondaryLabel)
            }

            Spacer()

            if isProcessing {
                ProgressView()
                    .controlSize(.small)
            } else {
                HStack(spacing: FMSpacing.xs) {
                    Button {
                        store.send(.rejectTapped(request))
                    } label: {
                        Text("거절")
                            .font(FMTypography.caption1)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        store.send(.approveTapped(request))
                    } label: {
                        Text("승인")
                            .font(FMTypography.caption1)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, FMSpacing.xxs)
    }

    private func profileImage(_ request: JoinRequest) -> some View {
        Group {
            if request.profileImageURL != nil {
                AsyncImage(url: request.profileImageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    profilePlaceholder(request)
                }
            } else {
                profilePlaceholder(request)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }

    private func profilePlaceholder(_ request: JoinRequest) -> some View {
        Circle()
            .fill(FMColors.primary.opacity(0.12))
            .overlay {
                Text(String(request.userName.prefix(1)))
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.primary)
            }
    }
}
