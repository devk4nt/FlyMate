import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct StudyListView: View {
    @Bindable var store: StoreOf<StudyListFeature>

    public init(store: StoreOf<StudyListFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.studies {
            case .idle, .loading:
                ScrollView {
                    LazyVStack(spacing: FMSpacing.md) {
                        ForEach(0..<3, id: \.self) { _ in
                            FMSkeletonView()
                                .frame(height: 120)
                        }
                    }
                    .padding(FMSpacing.md)
                }

            case .loaded(let studies):
                if studies.isEmpty {
                    FMEmptyState(
                        systemImage: "person.3.fill",
                        title: "참여 중인 스터디가 없습니다",
                        description: "스터디를 만들거나 초대 코드로 참여해보세요."
                    ) {
                        store.send(.createStudyTapped)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: FMSpacing.md) {
                            ForEach(studies) { study in
                                FMCard {
                                    StudyCardContent(study: study)
                                }
                                .onTapGesture {
                                    store.send(.studyTapped(study))
                                }
                            }
                        }
                        .padding(FMSpacing.md)
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
        .navigationTitle("스터디")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                FMNotificationBell(unreadCount: store.unreadNotificationCount) {
                    store.send(.notificationBellTapped)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("스터디 만들기", systemImage: "plus") {
                        store.send(.createStudyTapped)
                    }
                    Button("초대 코드 입력", systemImage: "ticket") {
                        store.send(.joinStudyTapped)
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .sheet(item: $store.scope(state: \.createStudy, action: \.createStudy)) { createStore in
            NavigationStack {
                StudyCreateView(store: createStore)
            }
        }
        .sheet(item: $store.scope(state: \.joinStudy, action: \.joinStudy)) { joinStore in
            NavigationStack {
                JoinStudyView(store: joinStore)
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Study Card Content

private struct StudyCardContent: View {
    let study: Domain.Study

    var body: some View {
        VStack(alignment: .leading, spacing: FMSpacing.xs) {
            HStack {
                Text(study.name)
                    .font(FMTypography.headline)

                Spacer()

                Text("\(study.memberCount)/\(study.maxMembers)명")
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.secondaryLabel)
            }

            Text(study.description)
                .font(FMTypography.callout)
                .foregroundStyle(FMColors.secondaryLabel)
                .lineLimit(2)

            HStack {
                Text(study.createdAt.relativeString)
                    .font(FMTypography.caption2)
                    .foregroundStyle(FMColors.secondaryLabel)
            }
        }
    }
}
