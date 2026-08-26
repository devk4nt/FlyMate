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
            .frame(maxWidth: FMSizing.ContentWidth.form)
            .frame(maxWidth: .infinity)
            .background(FMColors.canvas)
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
            ScrollView {
                LazyVStack(spacing: FMSpacing.md) {
                    ForEach(0..<4, id: \.self) { _ in
                        FMSkeletonView.listRow
                    }
                }
                .padding(FMSpacing.md)
            }

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

                Text(request.createdAt.koreanAbbreviated)
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
                    .tint(FMColors.actionForeground)
                    .controlSize(.small)

                    Button {
                        store.send(.approveTapped(request))
                    } label: {
                        Text("승인")
                            .font(FMTypography.caption1)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FMColors.accentFill)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, FMSpacing.xxs)
    }

    private func profileImage(_ request: JoinRequest) -> some View {
        FMProfileImage(url: request.profileImageURL, name: request.userName, size: .lg)
    }
}

#Preview("참여 요청 없음") {
    var state = JoinRequestManagementFeature.State(studyID: UUID())
    state.requests = .loaded([])
    return NavigationStack {
        JoinRequestManagementView(store: Store(initialState: state) { JoinRequestManagementFeature() })
    }
}
