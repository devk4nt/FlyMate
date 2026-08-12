import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct StudyManagementView: View {
    @Bindable var store: StoreOf<StudyManagementFeature>
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<StudyManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.studies {
            case .idle, .loading:
                loadingContent

            case .loaded(let studies):
                if studies.isEmpty {
                    emptyContent
                } else {
                    studyList(studies)
                }

            case .failed(let error):
                FMErrorView(error: error) {
                    store.send(.onAppear)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColors.softCanvas)
        .navigationTitle("스터디 관리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("닫기") { dismiss() }
            }
        }
        .onAppear { store.send(.onAppear) }
        .alert($store.scope(state: \.confirmAlert, action: \.confirmAlert))
    }

    private var loadingContent: some View {
        ScrollView {
            LazyVStack(spacing: FMSpacing.md) {
                FMSkeletonView(height: 64)

                ForEach(0..<3, id: \.self) { _ in
                    FMSkeletonView(height: 176)
                }
            }
            .padding(FMSpacing.md)
        }
    }

    private func studyList(_ studies: [Study]) -> some View {
        ScrollView {
            LazyVStack(spacing: FMSpacing.md) {
                managementSummary(count: studies.count)

                ForEach(studies) { study in
                    StudyManagementCard(study: study) {
                        store.send(.leaveStudyTapped(study.id))
                    }
                }
            }
            .padding(.horizontal, FMSpacing.md)
            .padding(.top, FMSpacing.xs)
            .padding(.bottom, FMSpacing.xxxl)
        }
        .refreshable {
            store.send(.onAppear)
        }
    }

    private func managementSummary(count: Int) -> some View {
        HStack(spacing: FMSpacing.sm) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(FMColors.brandGradient, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                Text("참여 중인 스터디 \(count)개")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FMColors.label)

                Text("더 이상 참여하지 않는 스터디를 정리할 수 있어요")
                    .font(.caption)
                    .foregroundStyle(FMColors.secondaryLabel)
            }

            Spacer(minLength: 0)
        }
        .padding(FMSpacing.md)
        .background(FMColors.background, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous)
                .stroke(FMColors.accent.opacity(0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var emptyContent: some View {
        VStack(spacing: FMSpacing.md) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: FMSizing.IconSize.hero, weight: .medium))
                .foregroundStyle(FMColors.brandInk)
                .frame(width: 76, height: 76)
                .background(FMColors.accent.opacity(0.12), in: Circle())

            VStack(spacing: FMSpacing.xs) {
                Text("관리할 스터디가 없어요")
                    .font(.headline)
                    .foregroundStyle(FMColors.label)

                Text("스터디에 참여하면 이곳에서 멤버 현황을 확인하고 관리할 수 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(FMSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(FMColors.background, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous)
                .stroke(FMColors.accent.opacity(0.2), lineWidth: 1)
        }
        .padding(FMSpacing.md)
    }
}

private struct StudyManagementCard: View {
    let study: Study
    let onLeave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FMSpacing.md) {
            HStack(spacing: FMSpacing.sm) {
                memberStack

                Spacer(minLength: 0)

                Label("\(study.memberCount)/\(study.maxMembers)", systemImage: "person.2.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FMColors.brandInk)
                    .padding(.horizontal, FMSpacing.sm)
                    .padding(.vertical, FMSpacing.xs)
                    .background(FMColors.accent.opacity(0.12), in: Capsule())
            }

            VStack(alignment: .leading, spacing: FMSpacing.xs) {
                Text(study.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(FMColors.label)

                Text(study.description)
                    .font(.subheadline)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Button(role: .destructive, action: onLeave) {
                Label("스터디 탈퇴", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FMColors.destructive)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 42)
                    .background(FMColors.destructiveSurface, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint("탈퇴 확인 창을 엽니다")
        }
        .padding(FMSpacing.lg)
        .background(FMColors.background, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous)
                .stroke(FMColors.accent.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: FMColors.brandInk.opacity(0.06), radius: 12, y: 6)
    }

    private var memberStack: some View {
        HStack(spacing: -FMSpacing.xs) {
            ForEach(Array(study.members.prefix(3))) { member in
                FMProfileImage(
                    url: member.profileImageURL,
                    name: member.userName,
                    size: .md
                )
                .overlay {
                    Circle().stroke(FMColors.background, lineWidth: 2)
                }
            }

            if study.memberCount > 3 {
                Text("+\(study.memberCount - 3)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(FMColors.brandInk)
                    .frame(width: 32, height: 32)
                    .background(FMColors.softCanvas, in: Circle())
                    .overlay {
                        Circle().stroke(FMColors.background, lineWidth: 2)
                    }
            }
        }
        .accessibilityHidden(true)
    }
}
