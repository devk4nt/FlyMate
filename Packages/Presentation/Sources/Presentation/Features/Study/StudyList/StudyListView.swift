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
                        LazyVStack(spacing: FMSpacing.sm) {
                            studyOverview(count: studies.count)

                            ForEach(studies) { study in
                                StudyRow(study: study)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        store.send(.studyTapped(study))
                                    }
                            }
                        }
                        .padding(.horizontal, FMSpacing.md)
                        .padding(.top, FMSpacing.xs)
                        .padding(.bottom, FMSpacing.xxl)
                    }
                    .background(FMColors.canvas)
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
        .background(FMColors.canvas)
        .navigationTitle("FlyMate")
        .toolbar {
            if #available(iOS 26.0, macOS 26.0, *) {
                ToolbarItem(placement: .primaryAction) {
                    topBarActions
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .primaryAction) {
                    topBarActions
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

    private var topBarActions: some View {
        HStack(spacing: FMSpacing.xl) {
            FMNotificationBell(unreadCount: store.unreadNotificationCount) {
                store.send(.notificationBellTapped)
            }

            Menu {
                Button("스터디 만들기", systemImage: "plus") {
                    store.send(.createStudyTapped)
                }
                Button("초대 코드 입력", systemImage: "ticket") {
                    store.send(.joinStudyTapped)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(FMColors.primary)
                    .frame(width: 32, height: 32)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, FMSpacing.sm)
        .padding(.vertical, FMSpacing.xs)
        .background(FMColors.background, in: Capsule())
        .shadow(color: FMShadow.cardColor, radius: FMShadow.cardRadius, y: FMShadow.cardY)
    }

    private func studyOverview(count: Int) -> some View {
        HStack(spacing: FMSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous)
                    .fill(FMColors.brandGradient)

                Image(systemName: "person.3.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            .shadow(color: FMColors.primary.opacity(0.2), radius: 9, y: 5)

            VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                Text("함께 성장하는 공간")
                    .font(FMTypography.title3)
                    .foregroundStyle(FMColors.label)

                Text("참여 중인 스터디 \(count)개")
                    .font(FMTypography.callout)
                    .foregroundStyle(FMColors.secondaryLabel)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, FMSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Study Row

private struct StudyRow: View {
    let study: Domain.Study

    var body: some View {
        HStack(spacing: FMSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous)
                    .fill(FMColors.primary.opacity(0.1))

                Text(String(study.name.prefix(1)))
                    .font(FMTypography.title2)
                    .foregroundStyle(FMColors.primary)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                HStack(spacing: FMSpacing.xs) {
                    Text(study.name)
                        .font(FMTypography.headline)
                        .foregroundStyle(FMColors.label)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(FMTypography.caption2)
                        .foregroundStyle(FMColors.secondaryLabel)
                }

                Text(study.description)
                    .font(FMTypography.callout)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .lineLimit(1)

                HStack(spacing: FMSpacing.sm) {
                    Label("\(study.memberCount)/\(study.maxMembers)", systemImage: "person.2.fill")
                    Label(study.createdAt.relativeString, systemImage: "clock")
                }
                .font(FMTypography.feedMeta)
                .foregroundStyle(FMColors.secondaryLabel)
            }
        }
        .padding(FMSpacing.md)
        .background(FMColors.elevatedBackground)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous)
                .stroke(FMColors.border.opacity(0.2), lineWidth: 0.5)
        }
        .shadow(color: FMShadow.cardColor, radius: 10, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(study.name), 멤버 \(study.memberCount)명")
    }
}
