import SwiftUI
import ComposableArchitecture
import Core
import Domain
import Kingfisher

public struct StudyDetailView: View {
    @Bindable var store: StoreOf<StudyDetailFeature>

    public init(store: StoreOf<StudyDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        contentView
            .navigationTitle(store.study.name)
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
                    FMSkeletonView()
                        .frame(height: 200)
                }
            }
            .padding(FMSpacing.md)
        }
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
            LazyVStack(spacing: FMSpacing.md) {
                noticeBanner
                studyInfoHeader

                ForEach(videos) { video in
                    videoCard(video)
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
            .padding(FMSpacing.md)
        }
        .refreshable {
            store.send(.refresh)
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

    private var isSaveDisabled: Bool {
        let trimmed = store.editingNoticeText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || store.noticeUpdateState.isLoading
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
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장") {
                            store.send(.saveNoticeTapped)
                        }
                        .disabled(isSaveDisabled)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        if store.study.notice != nil {
                            Button(role: .destructive) {
                                store.send(.deleteNoticeTapped)
                            } label: {
                                Text("공지 삭제")
                                    .font(FMTypography.callout)
                            }
                            .disabled(store.noticeUpdateState.isLoading)
                        }
                    }
                }
                .overlay {
                    if store.noticeUpdateState.isLoading {
                        ProgressView()
                    }
                }
        }
        .presentationDetents([.medium])
    }

    private var noticeEditorContent: some View {
        VStack(spacing: FMSpacing.md) {
            TextEditor(text: $store.editingNoticeText.sending(\.editingNoticeTextChanged))
                .font(FMTypography.body)
                .frame(minHeight: 120)
                .padding(FMSpacing.xs)
                .background(FMColors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))

            if case .failed(let error) = store.noticeUpdateState {
                Text(error.errorDescription ?? "")
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.destructive)
            }

            Spacer()
        }
        .padding(FMSpacing.md)
    }

    // MARK: - Study Info Header

    private var studyInfoHeader: some View {
        VStack(alignment: .leading, spacing: FMSpacing.xs) {
            Text(store.study.description)
                .font(FMTypography.body)
                .foregroundStyle(FMColors.secondaryLabel)

            HStack {
                Button {
                    store.send(.memberManagementTapped)
                } label: {
                    HStack(spacing: FMSpacing.xxs) {
                        Label("\(store.study.memberCount)명", systemImage: "person.2")
                            .font(FMTypography.caption1)

                        if store.isOwner {
                            Image(systemName: "chevron.right")
                                .font(FMTypography.caption2)
                                .foregroundStyle(FMColors.secondaryLabel)
                        }
                    }
                }
                .buttonStyle(.plain)

                if store.isOwner && store.pendingRequestCount > 0 {
                    Button {
                        store.send(.joinRequestManagementTapped)
                    } label: {
                        HStack(spacing: FMSpacing.xxs) {
                            Label("대기", systemImage: "person.badge.clock")
                                .font(FMTypography.caption1)
                                .foregroundStyle(FMColors.primary)

                            FMBadge(count: store.pendingRequestCount)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    store.send(.inviteCodeInfoTapped)
                } label: {
                    Image(systemName: "info.circle")
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)
                }
                .popover(
                    isPresented: Binding(
                        get: { store.isInviteCodePopoverPresented },
                        set: { newValue in
                            if !newValue { store.send(.dismissInviteCodePopover) }
                        }
                    ),
                    arrowEdge: .bottom
                ) {
                    inviteCodeInfoPopoverContent
                        .presentationCompactAdaptation(.popover)
                }

                Button {
                    store.send(.copyInviteCode)
                } label: {
                    Label(
                        store.isCopied ? "복사됨" : "초대 코드 복사",
                        systemImage: store.isCopied ? "checkmark" : "doc.on.doc"
                    )
                    .font(FMTypography.caption1)
                    .foregroundStyle(store.isCopied ? FMColors.success : FMColors.label)
                }
                .animation(.easeInOut(duration: 0.2), value: store.isCopied)
            }
        }
        .padding(FMSpacing.md)
        .background(FMColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))
    }

    // MARK: - Invite Code Info Popover

    @ViewBuilder
    private var inviteCodeInfoPopoverContent: some View {
        switch store.inviteCodeInfo {
        case .idle, .loading:
            ProgressView()
                .frame(width: 180, height: 80)

        case .loaded(let info):
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                inviteCodeStatusBadge(info)

                if !info.isExpired {
                    Label(expirationText(info.expiresAt), systemImage: "calendar")
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)
                } else {
                    Label("만료됨", systemImage: "calendar.badge.exclamationmark")
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.destructive)
                }
            }
            .padding(FMSpacing.md)

        case .failed:
            VStack(spacing: FMSpacing.sm) {
                Text("정보를 불러올 수 없습니다")
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.secondaryLabel)

                Button {
                    store.send(.inviteCodeInfoTapped)
                } label: {
                    Text("다시 시도")
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.accent)
                }
            }
            .padding(FMSpacing.md)
        }
    }

    private func inviteCodeStatusBadge(_ info: InviteCode) -> some View {
        let (text, color): (String, Color) = if info.isValid {
            ("활성", FMColors.success)
        } else if info.isExpired {
            ("만료됨", FMColors.destructive)
        } else {
            ("비활성", FMColors.secondaryLabel)
        }

        return Text(text)
            .font(FMTypography.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, FMSpacing.xs)
            .padding(.vertical, FMSpacing.xxs)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func expirationText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일까지"
        return formatter.string(from: date)
    }

    // MARK: - Video Card

    private func videoCard(_ video: Domain.Video) -> some View {
        FMCard {
            VStack(alignment: .leading, spacing: FMSpacing.xs) {
                // 썸네일 영역
                ZStack {
                    if let thumbnailURL = video.thumbnailURL {
                        KFImage(thumbnailURL)
                            .resizable()
                            .placeholder {
                                RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm)
                                    .fill(FMColors.secondaryBackground)
                                    .overlay {
                                        ProgressView()
                                    }
                            }
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))
                    } else {
                        RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm)
                            .fill(FMColors.secondaryBackground)
                            .frame(height: 160)
                    }

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(radius: 4)
                }
                .frame(height: 160)
                .clipped()

                Text(video.title)
                    .font(FMTypography.headline)

                HStack {
                    Text(video.uploaderName)
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)

                    Spacer()

                    Text(video.durationSeconds.minuteSecondFormatted)
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)

                    if video.feedbackCount > 0 {
                        FMBadge(count: video.feedbackCount)
                    }
                }
            }
        }
    }
}
