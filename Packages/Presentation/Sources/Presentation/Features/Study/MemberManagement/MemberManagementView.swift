import SwiftUI
import ComposableArchitecture
import Domain

public struct MemberManagementView: View {
    @Bindable var store: StoreOf<MemberManagementFeature>

    public init(store: StoreOf<MemberManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        List {
            Section {
                ForEach(store.sortedMembers) { member in
                    memberRow(member)
                }
            } header: {
                Text("멤버 \(store.study.memberCount)명")
                    .font(FMTypography.caption1)
            }
        }
        .frame(maxWidth: FMSizing.ContentWidth.form)
        .frame(maxWidth: .infinity)
        .listStyle(.insetGrouped)
        .navigationTitle("스터디원 관리")
        .navigationBarTitleDisplayMode(.inline)
        .alert($store.scope(state: \.confirmAlert, action: \.confirmAlert))
        .sheet(
            item: $store.scope(state: \.memberStats, action: \.memberStats)
        ) { memberStatsStore in
            MemberStatsSheet(store: memberStatsStore)
        }
        .overlay {
            if store.removeMemberState.isLoading {
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                ProgressView()
            }
        }
    }

    // MARK: - Member Row

    private func memberRow(_ member: StudyMember) -> some View {
        HStack(spacing: FMSpacing.sm) {
            Button {
                store.send(.memberTapped(member))
            } label: {
                HStack(spacing: FMSpacing.sm) {
                    profileImage(member)

                    VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                        HStack(spacing: FMSpacing.xs) {
                            Text(member.userName)
                                .font(FMTypography.headline)
                                .foregroundStyle(FMColors.label)

                            if member.role == .owner {
                                Text("방장")
                                    .font(FMTypography.caption2)
                                    .foregroundStyle(FMColors.badgeForeground)
                                    .padding(.horizontal, FMSpacing.xxs)
                                    .padding(.vertical, FMSpacing.xxxs)
                                    .background(FMColors.badgeForeground.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm / 2))
                            }
                        }

                        Text(member.joinedAt.koreanAbbreviated)
                            .font(FMTypography.caption1)
                            .foregroundStyle(FMColors.secondaryLabel)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if store.isOwner && member.role != .owner {
                Button {
                    store.send(.transferOwnerTapped(member))
                } label: {
                    Text("방장 위임")
                        .font(FMTypography.caption1)
                }
                .buttonStyle(.bordered)
                .tint(FMColors.actionForeground)
                .controlSize(.small)
                .accessibilityLabel("\(member.userName)님에게 방장 위임")
                .accessibilityHint("방장 권한을 넘깁니다")

                Button(role: .destructive) {
                    store.send(.removeMemberTapped(member))
                } label: {
                    Text("내보내기")
                        .font(FMTypography.caption1)
                }
                .buttonStyle(.bordered)
                .tint(FMColors.destructive)
                .controlSize(.small)
            }
        }
        .padding(.vertical, FMSpacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(member.userName)\(member.role == .owner ? ", 방장" : "")")
        .accessibilityHint("활동 현황 보기")
    }

    // MARK: - Profile Image

    private func profileImage(_ member: StudyMember) -> some View {
        FMProfileImage(url: member.profileImageURL, name: member.userName, size: .lg)
    }
}

// MARK: - Preview

private enum PreviewData {
    static let ownerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let member1ID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let member2ID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let member3ID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    static let member4ID = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!

    static let members: [StudyMember] = [
        StudyMember(
            id: UUID(),
            userID: ownerID,
            userName: "김재준",
            role: .owner,
            joinedAt: Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        ),
        StudyMember(
            id: UUID(),
            userID: member1ID,
            userName: "이수현",
            profileImageURL: URL(string: "https://picsum.photos/80"),
            role: .member,
            joinedAt: Calendar.current.date(byAdding: .day, value: -25, to: .now)!
        ),
        StudyMember(
            id: UUID(),
            userID: member2ID,
            userName: "박민지",
            role: .member,
            joinedAt: Calendar.current.date(byAdding: .day, value: -20, to: .now)!
        ),
        StudyMember(
            id: UUID(),
            userID: member3ID,
            userName: "정하늘",
            role: .member,
            joinedAt: Calendar.current.date(byAdding: .day, value: -10, to: .now)!
        ),
        StudyMember(
            id: UUID(),
            userID: member4ID,
            userName: "최도윤",
            profileImageURL: URL(string: "https://picsum.photos/81"),
            role: .member,
            joinedAt: Calendar.current.date(byAdding: .day, value: -3, to: .now)!
        ),
    ]

    static let study = Study(
        id: UUID(),
        name: "iOS 면접 스터디",
        description: "Swift & iOS 면접 준비 스터디",
        ownerID: ownerID,
        inviteCode: "ABC123",
        maxMembers: 8,
        members: members,
        createdAt: Calendar.current.date(byAdding: .day, value: -30, to: .now)!
    )
}

#Preview("방장 시점") {
    NavigationStack {
        MemberManagementView(
            store: Store(
                initialState: MemberManagementFeature.State(
                    study: PreviewData.study,
                    currentUserID: PreviewData.ownerID
                )
            ) {
                MemberManagementFeature()
            } withDependencies: {
                $0.studyClient.removeMember = { _, _ in }
                $0.studyClient.fetchMemberStats = { studyID, userID in
                    MemberStats(
                        userID: userID,
                        studyID: studyID,
                        feedbackGivenCount: 12,
                        feedbackReceivedCount: 8,
                        videosUploadedCount: 5,
                        joinedAt: Date().addingTimeInterval(-30 * 24 * 60 * 60)
                    )
                }
            }
        )
    }
}

#Preview("팀원 시점") {
    NavigationStack {
        MemberManagementView(
            store: Store(
                initialState: MemberManagementFeature.State(
                    study: PreviewData.study,
                    currentUserID: PreviewData.member1ID
                )
            ) {
                MemberManagementFeature()
            } withDependencies: {
                $0.studyClient.fetchMemberStats = { studyID, userID in
                    MemberStats(
                        userID: userID,
                        studyID: studyID,
                        feedbackGivenCount: 3,
                        feedbackReceivedCount: 5,
                        videosUploadedCount: 2,
                        joinedAt: Date().addingTimeInterval(-25 * 24 * 60 * 60)
                    )
                }
            }
        )
    }
}
