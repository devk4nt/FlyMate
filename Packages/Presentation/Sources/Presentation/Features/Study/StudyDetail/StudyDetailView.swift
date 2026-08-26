import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct StudyDetailView: View {
    @Bindable var store: StoreOf<StudyDetailFeature>
    @State private var isDeleteNoticeConfirmationPresented = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(store: StoreOf<StudyDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        contentView
            .frame(maxWidth: FMSizing.ContentWidth.regular)
            .frame(maxWidth: .infinity)
            .navigationTitle(store.study.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.uploadVideoTapped(studyID: store.study.id))
                    } label: {
                        Image(systemName: "video.badge.plus")
                    }
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .sheet(isPresented: Binding(
                get: { store.isEditingNotice },
                set: { newValue in
                    if !newValue { store.send(.dismissNoticeEditor) }
                }
            )) {
                noticeEditorSheet
            }
            .background(FMColors.canvas)
    }

    @ViewBuilder
    private var contentView: some View {
        switch store.videos {
        case .idle, .loading:
            loadingView
        case .loaded(let videos):
            loadedView(videos: videos)
        case .failed(let error):
            FMErrorView(error: error) {
                store.send(.refresh)
            }
        }
    }

    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: FMSpacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    FMSkeletonView(height: 200)
                }
            }
            .padding(FMSpacing.md)
        }
        .background(FMColors.canvas)
    }

    @ViewBuilder
    private func loadedView(videos: [Video]) -> some View {
        if videos.isEmpty {
            FMEmptyState(
                systemImage: "video.badge.plus",
                title: "아직 영상이 없습니다",
                description: "면접 연습 영상을 업로드해보세요.",
                actionTitle: "영상 업로드"
            ) {
                store.send(.uploadVideoTapped(studyID: store.study.id))
            }
        } else {
            videoListView(videos: videos)
        }
    }

    private func videoListView(videos: [Video]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                VStack(spacing: FMSpacing.md) {
                    noticeBanner
                    studyInfoHeader
                }
                .padding(FMSpacing.md)

                ForEach(videos) { video in
                    feedCell(video)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.send(.videoTapped(video))
                        }
                        .onAppear {
                            if video == videos.last {
                                store.send(.loadMoreVideos)
                            }
                        }
                }

                if store.videosPagination.isLoadingMore {
                    ProgressView()
                        .padding()
                }
            }
        }
        .background(FMColors.canvas)
        .refreshable {
            await store.send(.refresh).finish()
        }
    }

    // MARK: - Notice Banner

    @ViewBuilder
    private var noticeBanner: some View {
        if let notice = store.study.notice, !notice.isEmpty {
            Button {
                store.send(.noticeTapped)
            } label: {
                HStack(spacing: FMSpacing.xs) {
                    Image(systemName: "megaphone.fill")
                        .foregroundStyle(FMColors.primary)
                        .font(FMTypography.callout)

                    Text(notice)
                        .font(FMTypography.callout)
                        .foregroundStyle(FMColors.label)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    if store.isOwner {
                        Image(systemName: "chevron.right")
                            .font(FMTypography.caption2)
                            .foregroundStyle(FMColors.secondaryLabel)
                    }
                }
                .padding(FMSpacing.sm)
                .background(FMColors.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))
            }
            .buttonStyle(.plain)
        } else if store.isOwner {
            Button {
                store.send(.editNoticeTapped)
            } label: {
                HStack(spacing: FMSpacing.xs) {
                    Image(systemName: "megaphone")
                        .foregroundStyle(FMColors.secondaryLabel)
                        .font(FMTypography.callout)

                    Text("공지사항을 등록해보세요")
                        .font(FMTypography.callout)
                        .foregroundStyle(FMColors.secondaryLabel)

                    Spacer(minLength: 0)

                    Image(systemName: "plus")
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)
                }
                .padding(FMSpacing.sm)
                .background(FMColors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Notice Editor Sheet

    private var canSaveNotice: Bool {
        let trimmed = store.editingNoticeText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
    }

    private var noticeEditorSheet: some View {
        NavigationStack {
            noticeEditorContent
                .navigationTitle("공지사항 편집")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") {
                            store.send(.dismissNoticeEditor)
                        }
                        .disabled(store.noticeUpdateState.isLoading)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    noticeSaveArea
                }
        }
        .fmSheetStyle()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(store.noticeUpdateState.isLoading)
        .confirmationDialog(
            "공지사항을 삭제할까요?",
            isPresented: $isDeleteNoticeConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("공지사항 삭제", role: .destructive) {
                store.send(.deleteNoticeTapped)
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("삭제한 공지사항은 다시 복구할 수 없습니다.")
        }
    }

    private var noticeEditorContent: some View {
        ScrollView {
            VStack(spacing: FMSpacing.lg) {
                noticeEditorHeader
                noticeInputCard

                if case .failed(let error) = store.noticeUpdateState {
                    noticeErrorCard(message: error.errorDescription ?? "공지사항을 저장하지 못했습니다.")
                }

                if store.study.notice != nil {
                    deleteNoticeButton
                }
            }
            .padding(.horizontal, FMSpacing.md)
            .padding(.top, FMSpacing.sm)
            .padding(.bottom, FMSpacing.xxxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .background(FMColors.canvas)
    }

    private var noticeEditorHeader: some View {
        HStack(spacing: FMSpacing.md) {
            Image(systemName: "megaphone.fill")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: FMSizing.IconContainer.lg, height: FMSizing.IconContainer.lg)
                .background(FMColors.brandGradient)
                .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous))
                .shadow(color: FMShadow.floatingColor, radius: FMShadow.floatingRadius, y: FMShadow.floatingY)

            VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                Text("멤버에게 중요한 소식을 알려주세요")
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.label)

                Text("공지사항은 스터디 화면 상단에 표시됩니다.")
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.secondaryLabel)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var noticeInputCard: some View {
        FMCard {
            VStack(alignment: .leading, spacing: FMSpacing.md) {
                HStack(spacing: FMSpacing.sm) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(FMColors.iconAccent)
                        .frame(width: FMSizing.IconContainer.sm, height: FMSizing.IconContainer.sm)
                        .background(FMColors.primary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm, style: .continuous))

                    VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                        Text("공지 내용")
                            .font(FMTypography.headline)
                            .foregroundStyle(FMColors.label)

                        Text("핵심 내용이 잘 보이도록 간결하게 작성해 주세요.")
                            .font(FMTypography.caption1)
                            .foregroundStyle(FMColors.secondaryLabel)
                    }
                }

                Divider()

                ZStack(alignment: .topLeading) {
                    if store.editingNoticeText.isEmpty {
                        Text("예: 이번 주 스터디 일정과 준비물을 안내해 주세요.")
                            .font(FMTypography.body)
                            .foregroundStyle(FMColors.secondaryLabel.opacity(0.72))
                            .padding(.horizontal, FMSpacing.sm)
                            .padding(.vertical, FMSpacing.sm)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $store.editingNoticeText.sending(\.editingNoticeTextChanged))
                        .font(FMTypography.body)
                        .foregroundStyle(FMColors.label)
                        .scrollContentBackground(.hidden)
                        .padding(FMSpacing.xs)
                        .frame(minHeight: 150)
                }
                .fmInputSurface()

                HStack {
                    Label("모든 멤버에게 공개", systemImage: "person.2.fill")
                    Spacer()
                    Text("\(store.editingNoticeText.count)자")
                }
                .font(FMTypography.caption1)
                .foregroundStyle(FMColors.secondaryLabel)
            }
        }
    }

    private func noticeErrorCard(message: String) -> some View {
        HStack(alignment: .top, spacing: FMSpacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(FMColors.destructive)

            Text(message)
                .font(FMTypography.callout)
                .foregroundStyle(FMColors.label)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(FMSpacing.md)
        .background(FMColors.destructiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("오류: \(message)")
    }

    private var deleteNoticeButton: some View {
        Button {
            isDeleteNoticeConfirmationPresented = true
        } label: {
            HStack(spacing: FMSpacing.sm) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: FMSizing.IconContainer.sm, height: FMSizing.IconContainer.sm)
                    .background(FMColors.destructiveSurface)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                    Text("공지사항 삭제")
                        .font(FMTypography.headline)
                    Text("현재 등록된 공지를 스터디에서 내립니다.")
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(FMTypography.caption2)
                    .foregroundStyle(FMColors.secondaryLabel)
            }
            .foregroundStyle(FMColors.destructive)
            .padding(FMSpacing.md)
            .background(FMColors.elevatedBackground)
            .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous)
                    .stroke(FMColors.destructiveBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(store.noticeUpdateState.isLoading)
    }

    private var noticeSaveArea: some View {
        FMButton(
            title: "공지사항 저장",
            isLoading: store.noticeUpdateState.isLoading,
            isEnabled: canSaveNotice
        ) {
            store.send(.saveNoticeTapped)
        }
        .fmSheetBottomBar()
    }

    // MARK: - Study Info Header

    private var studyInfoHeader: some View {
        FMCard {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                Text(store.study.description)
                    .font(FMTypography.body)
                    .foregroundStyle(FMColors.secondaryLabel)

                Divider()

                HStack(spacing: FMSpacing.xs) {
                    HStack(spacing: FMSpacing.xs) {
                        Button {
                            store.send(.memberManagementTapped)
                        } label: {
                            HStack(spacing: FMSpacing.xxs) {
                                Image(systemName: "person.2.fill")

                                Text("스터디원 \(store.study.memberCount)명")
                                    .lineLimit(1)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            .font(FMTypography.caption1)
                            .fontWeight(.semibold)
                            .foregroundStyle(FMColors.actionForeground)
                            .padding(.horizontal, FMSpacing.xs)
                            .frame(minHeight: FMSizing.IconContainer.sm)
                            .background(FMColors.primary.opacity(0.1), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("스터디원 목록을 엽니다")

                        if store.isOwner && store.pendingRequestCount > 0 {
                            Button {
                                store.send(.joinRequestManagementTapped)
                            } label: {
                                HStack(spacing: FMSpacing.xxs) {
                                    Image(systemName: "person.badge.clock")

                                    Text("대기 \(store.pendingRequestCount)명")
                                        .lineLimit(1)
                                }
                                .fixedSize(horizontal: true, vertical: false)
                                .font(FMTypography.caption1)
                                .fontWeight(.semibold)
                                .foregroundStyle(FMColors.attentionFill)
                                .padding(.horizontal, FMSpacing.xs)
                                .frame(minHeight: FMSizing.IconContainer.sm)
                                .background(FMColors.attentionFill.opacity(0.1), in: Capsule())
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("가입 대기 \(store.pendingRequestCount)명")
                            .accessibilityHint("가입 요청 관리 화면을 엽니다")
                        }
                    }

                    Spacer(minLength: 0)

                    Button {
                        store.send(.copyInviteCode)
                    } label: {
                        ZStack {
                            Label("초대 코드 복사", systemImage: "doc.on.doc")
                                .opacity(store.isCopied ? 0 : 1)

                            Label("복사됨", systemImage: "checkmark")
                                .opacity(store.isCopied ? 1 : 0)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .font(FMTypography.caption1)
                        .fontWeight(.semibold)
                        .foregroundStyle(store.isCopied ? FMColors.success : FMColors.actionForeground)
                        .padding(.horizontal, FMSpacing.xs)
                        .frame(minHeight: FMSizing.IconContainer.sm)
                        .background(
                            (store.isCopied ? FMColors.success : FMColors.primary).opacity(0.1),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(store.isCopied ? "복사됨" : "초대 코드 복사")
                    .accessibilityHint("초대 코드를 클립보드에 복사합니다")
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: store.isCopied)
                }
            }
        }
    }

    // MARK: - Feed Cell

    private func feedCell(_ video: Domain.Video) -> some View {
        FMFeedCell(
            authorName: video.uploaderName,
            authorID: video.uploaderID,
            timeText: video.createdAt.relativeString,
            thumbnailURL: video.thumbnailURL,
            durationText: video.durationSeconds.minuteSecondFormatted,
            title: video.title,
            feedbackCount: video.feedbackCount
        )
    }
}

#Preview("영상 없음") {
    let study = Study(
        id: UUID(),
        name: "승무원 영상면접 스터디",
        description: "국내·외항사 승무원 영상면접을 함께 준비해요",
        ownerID: UUID(),
        inviteCode: "ABC123",
        maxMembers: 8,
        members: [],
        createdAt: Date()
    )
    var state = StudyDetailFeature.State(study: study)
    state.videos = .loaded([])
    return NavigationStack {
        StudyDetailView(store: Store(initialState: state) { StudyDetailFeature() })
    }
}
