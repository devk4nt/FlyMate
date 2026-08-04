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
                        LazyVStack(spacing: 0) {
                            ForEach(studies) { study in
                                StudyRow(study: study)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        store.send(.studyTapped(study))
                                    }
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

// MARK: - Study Row

private struct StudyRow: View {
    let study: Domain.Study

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                HStack {
                    Text(study.name)
                        .font(FMTypography.authorName)
                        .foregroundStyle(FMColors.label)

                    Spacer()

                    Text("\(study.memberCount)/\(study.maxMembers)명")
                        .font(FMTypography.feedMeta)
                        .foregroundStyle(FMColors.secondaryLabel)
                }

                Text(study.description)
                    .font(FMTypography.feedBody)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .lineLimit(2)

                Text(study.createdAt.relativeString)
                    .font(FMTypography.feedMeta)
                    .foregroundStyle(FMColors.secondaryLabel)
            }
            .padding(.horizontal, FMSpacing.md)
            .padding(.vertical, FMSpacing.sm)

            Divider()
        }
        .background(FMColors.background)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(study.name), 멤버 \(study.memberCount)명")
    }
}
