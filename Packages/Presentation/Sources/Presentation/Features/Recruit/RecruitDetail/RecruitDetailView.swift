import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct RecruitDetailView: View {
    @Bindable var store: StoreOf<RecruitDetailFeature>
    @FocusState private var isCommentInputFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let commentBottomAnchor = "recruit-comment-bottom-anchor"

    public init(store: StoreOf<RecruitDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: FMSpacing.lg) {
                    header
                    infoSection
                    descriptionSection
                    contactSection
                    commentSection

                    Color.clear
                        .frame(height: 1)
                        .id(Self.commentBottomAnchor)
                }
                .frame(maxWidth: FMSizing.ContentWidth.form)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, FMSpacing.md)
                .padding(.bottom, FMSpacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .onChange(of: store.scrollToCommentID) { _, commentID in
                guard let commentID else { return }
                withAnimation(reduceMotion ? nil : .default) {
                    proxy.scrollTo(commentID, anchor: .bottom)
                }
            }
            .onChange(of: isCommentInputFocused) { _, isFocused in
                guard isFocused else { return }

                // Wait for the keyboard-safe-area update before moving the content.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard isCommentInputFocused else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                        proxy.scrollTo(Self.commentBottomAnchor, anchor: .bottom)
                    }
                }
            }
        }
        .background(FMColors.softCanvas)
        .navigationTitle("모집 글")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { toolbarMenu }
        .safeAreaInset(edge: .bottom) { commentInputBar }
        .onAppear { store.send(.onAppear) }
        .refreshable { await store.send(.refresh).finish() }
        .sheet(item: $store.scope(state: \.report, action: \.report)) { reportStore in
            ReportView(store: reportStore)
        }
        .alert($store.scope(state: \.blockAlert, action: \.blockAlert))
        .sheet(item: $store.scope(state: \.edit, action: \.edit)) { editStore in
            NavigationStack {
                RecruitCreateView(store: editStore)
            }
            .interactiveDismissDisabled(editStore.hasChanges)
        }
        .sheet(isPresented: Binding(
            get: { store.showReopenSheet },
            set: { if !$0 { store.send(.reopenDismissed) } }
        )) {
            reopenSheet
        }
        .alert(
            "모집을 마감할까요?",
            isPresented: Binding(
                get: { store.showCloseAlert },
                set: { if !$0 { store.send(.closeCancelled) } }
            )
        ) {
            Button("취소", role: .cancel) { store.send(.closeCancelled) }
            Button("마감하기", role: .destructive) { store.send(.closeConfirmed) }
        } message: {
            Text("마감 후에도 글과 댓글은 계속 볼 수 있어요.")
        }
        .alert(
            "모집 글을 삭제할까요?",
            isPresented: Binding(
                get: { store.showDeleteAlert },
                set: { if !$0 { store.send(.deleteCancelled) } }
            )
        ) {
            Button("취소", role: .cancel) { store.send(.deleteCancelled) }
            Button("삭제", role: .destructive) { store.send(.deleteConfirmed) }
        } message: {
            Text("삭제하면 댓글을 포함한 모든 내용이 사라져요.")
        }
        .fmToast(
            isPresented: Binding(
                get: { store.showToast },
                set: { _ in store.send(.toastDismissed) }
            ),
            message: store.toastMessage,
            type: .info
        )
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: FMSpacing.sm) {
            HStack(spacing: FMSpacing.xs) {
                statusBadge

                if store.post.isEdited {
                    Text("수정됨")
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)
                }

                Spacer(minLength: 0)
            }

            Text(store.post.title)
                .font(FMTypography.title2)
                .foregroundStyle(FMColors.label)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: FMSpacing.xs) {
                Text(store.post.authorName)
                    .font(FMTypography.feedMetaEmphasis)
                    .foregroundStyle(FMColors.label)

                Text(store.post.createdAt.relativeString)
                    .font(FMTypography.feedMeta)
                    .foregroundStyle(FMColors.secondaryLabel)
            }
        }
        .padding(FMSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous)
                    .fill(FMColors.background)

                Circle()
                    .fill(FMColors.accent.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .offset(x: 44, y: -54)
            }
            .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous)
                .stroke(FMColors.accent.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: FMShadow.cardColor, radius: FMShadow.cardRadius, y: FMShadow.cardY)
        .padding(.top, FMSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var statusBadge: some View {
        Text(store.post.isRecruiting() ? "모집 중" : "모집 마감")
            .font(FMTypography.caption1.weight(.semibold))
            .foregroundStyle(store.post.isRecruiting() ? FMColors.onAccent : FMColors.secondaryLabel)
            .padding(.horizontal, FMSpacing.xs)
            .padding(.vertical, FMSpacing.xxs)
            .background(
                store.post.isRecruiting() ? FMColors.accentFill : FMColors.secondaryBackground,
                in: Capsule()
            )
            .accessibilityIdentifier("스터디_상세_모집상태")
    }

    // MARK: - Info

    private var infoSection: some View {
        sectionCard("모집 정보") {
            infoRow("분야", store.post.field.displayText)
            infoRow("진행 방식", store.post.meetingType.displayText)
            if let region = store.post.region, !region.isEmpty {
                infoRow("활동 지역", region)
            }
            infoRow("활동 일정", store.post.schedule)
            infoRow("활동 기간", periodText)
            infoRow("모집 인원", "\(store.post.maxMembers)명")
            infoRow("모집 마감일", store.post.deadline.dotFormatted)
            infoRow("참여 조건", store.post.requirement)
        }
    }

    private var periodText: String {
        let start = store.post.startDate.koreanFormatted
        if let endDate = store.post.endDate {
            return "\(start) ~ \(endDate.koreanFormatted)"
        }
        return "\(start) 시작 · 기간 미정"
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: FMSpacing.sm) {
            Text(title)
                .font(FMTypography.caption1)
                .foregroundStyle(FMColors.secondaryLabel)
                .frame(width: 72, alignment: .leading)

            Text(value)
                .font(FMTypography.body)
                .foregroundStyle(FMColors.label)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }

    // MARK: - Description

    private var descriptionSection: some View {
        sectionCard("스터디 소개") {
            Text(store.post.description)
                .font(FMTypography.body)
                .foregroundStyle(FMColors.label)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Contact

    private var contactSection: some View {
        sectionCard("참여 방법") {
            Text(store.post.contactMethod)
                .font(FMTypography.body)
                .foregroundStyle(FMColors.label)
                .fixedSize(horizontal: false, vertical: true)

            if let linkURL = store.post.linkURL {
                Link(destination: linkURL) {
                    Label("문의 링크 열기", systemImage: "link")
                        .font(FMTypography.feedMetaEmphasis)
                        .foregroundStyle(FMColors.primary)
                }
                .accessibilityHint("외부 서비스로 이동합니다")
                .accessibilityIdentifier("스터디_상세_문의링크")

                Text("외부 서비스로 이동해요. 개인정보 요구나 금전 요구에 주의하세요.")
                    .font(FMTypography.caption2)
                    .foregroundStyle(FMColors.secondaryLabel)
            }
        }
    }

    // MARK: - Comments

    private var commentSection: some View {
        sectionCard("댓글 \(store.post.commentCount)") {
            switch store.comments {
            case .idle, .loading:
                FMSkeletonView(height: 80)

            case .loaded(let comments):
                if comments.isEmpty {
                    Text("아직 댓글이 없어요. 참여 문의를 남겨보세요.")
                        .font(FMTypography.callout)
                        .foregroundStyle(FMColors.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, FMSpacing.md)
                } else {
                    let roots = comments.filter { $0.parentID == nil }
                    VStack(alignment: .leading, spacing: FMSpacing.md) {
                        ForEach(roots) { comment in
                            commentRow(comment)
                                .id(comment.id)

                            ForEach(comments.filter { $0.parentID == comment.id }) { reply in
                                commentRow(reply)
                                    .padding(.leading, FMSpacing.xl)
                                    .id(reply.id)
                            }
                        }
                    }
                }

            case .failed(let error):
                Text(error.localizedDescription)
                    .font(FMTypography.callout)
                    .foregroundStyle(FMColors.secondaryLabel)
            }
        }
    }

    private func commentRow(_ comment: RecruitComment) -> some View {
        VStack(alignment: .leading, spacing: FMSpacing.xxs) {
            HStack(spacing: FMSpacing.xs) {
                Text(comment.authorName)
                    .font(FMTypography.feedMetaEmphasis)
                    .foregroundStyle(FMColors.label)

                if comment.authorID == store.post.authorID {
                    Text("모집자")
                        .font(FMTypography.caption2)
                        .foregroundStyle(FMColors.primary)
                        .padding(.horizontal, FMSpacing.xxs)
                        .padding(.vertical, 1)
                        .background(FMColors.primary.opacity(0.1), in: Capsule())
                }

                Text(comment.createdAt.relativeString)
                    .font(FMTypography.caption2)
                    .foregroundStyle(FMColors.secondaryLabel)

                Spacer(minLength: 0)

                Menu {
                    if !comment.isReply {
                        Button {
                            store.send(.replyTapped(comment))
                        } label: {
                            Label("대댓글 작성", systemImage: "arrowshape.turn.up.left")
                        }
                    }
                    if comment.authorID == store.currentUserID {
                        Button(role: .destructive) {
                            store.send(.deleteCommentTapped(comment))
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive) {
                            store.send(.reportCommentTapped(comment))
                        } label: {
                            Label("신고", systemImage: "exclamationmark.bubble")
                        }
                        Button(role: .destructive) {
                            store.send(.blockUserTapped(authorID: comment.authorID, authorName: comment.authorName))
                        } label: {
                            Label("사용자 차단", systemImage: "person.slash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("댓글 메뉴")
                .accessibilityIdentifier("스터디_댓글_대댓글작성_\(comment.id.uuidString)")
            }

            Text(comment.content)
                .font(FMTypography.body)
                .foregroundStyle(FMColors.label)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(comment.authorName)의 댓글, \(comment.content)")
    }

    // MARK: - Comment Input

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            if let replyTarget = store.replyTarget {
                HStack(spacing: FMSpacing.xs) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.selection)

                    Text("\(replyTarget.authorName)님에게 답글 남기는 중")
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        store.send(.replyCancelled)
                    } label: {
                        Image(systemName: "xmark")
                            .font(FMTypography.feedMetaEmphasis)
                            .foregroundStyle(FMColors.secondaryLabel)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("답글 취소")
                }
                .padding(.horizontal, FMSpacing.md)
                .padding(.vertical, FMSpacing.xs)
                .background(FMColors.secondaryBackground.opacity(0.5))
            }

            Divider()

            HStack(alignment: .bottom, spacing: FMSpacing.sm) {
                TextField(
                    "참여 문의를 남겨주세요",
                    text: Binding(
                        get: { store.commentText },
                        set: { store.send(.commentTextChanged($0)) }
                    ),
                    axis: .vertical
                )
                .font(FMTypography.body)
                .lineLimit(1...4)
                .focused($isCommentInputFocused)
                .padding(.horizontal, FMSpacing.sm)
                .padding(.vertical, FMSpacing.xs)
                .fmComposerSurface(isFocused: isCommentInputFocused)
                .accessibilityLabel("댓글 입력")
                .accessibilityIdentifier("스터디_상세_댓글작성")

                Button {
                    store.send(.submitCommentTapped)
                } label: {
                    if store.isSubmittingComment {
                        ProgressView()
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: FMSizing.IconSize.lg))
                            .foregroundStyle(
                                store.isCommentValid
                                    ? FMColors.accent
                                    : FMColors.secondaryLabel.opacity(0.5)
                            )
                    }
                }
                .disabled(!store.isCommentValid || store.isSubmittingComment)
                .accessibilityLabel("댓글 등록")
            }
            .padding(.horizontal, FMSpacing.md)
            .padding(.vertical, FMSpacing.sm)
        }
        .background(FMColors.background)
    }

    // MARK: - Toolbar

    private var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                if store.isAuthor {
                    Button {
                        store.send(.editTapped)
                    } label: {
                        Label("수정", systemImage: "pencil")
                    }

                    if store.post.status == .recruiting {
                        Button {
                            store.send(.closeTapped)
                        } label: {
                            Label("모집 마감", systemImage: "lock")
                        }
                    } else {
                        Button {
                            store.send(.reopenTapped)
                        } label: {
                            Label("모집 재개", systemImage: "lock.open")
                        }
                    }

                    Button(role: .destructive) {
                        store.send(.deleteTapped)
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                } else {
                    Button(role: .destructive) {
                        store.send(.reportPostTapped)
                    } label: {
                        Label("신고", systemImage: "exclamationmark.bubble")
                    }
                    Button(role: .destructive) {
                        store.send(.blockUserTapped(authorID: store.post.authorID, authorName: store.post.authorName))
                    } label: {
                        Label("작성자 차단", systemImage: "person.slash")
                    }
                }
            } label: {
                if store.isProcessing {
                    ProgressView()
                } else {
                    Image(systemName: "ellipsis")
                }
            }
            .disabled(store.isProcessing)
            .accessibilityLabel(store.isAuthor ? "모집 글 관리" : "신고")
            .accessibilityIdentifier(store.isAuthor ? "스터디_상세_모집마감" : "스터디_상세_신고")
        }
    }

    // MARK: - Reopen Sheet

    private var reopenSheet: some View {
        NavigationStack {
            ZStack {
                FMColors.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: FMSpacing.md) {
                        Text("새로운 모집 마감일을 설정해주세요.")
                            .font(FMTypography.callout)
                            .foregroundStyle(FMColors.secondaryLabel)

                        FMCard {
                            DatePicker(
                                "모집 마감일",
                                selection: Binding(
                                    get: { store.reopenDeadline },
                                    set: { store.send(.reopenDeadlineChanged($0)) }
                                ),
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                        }
                    }
                    .padding(FMSpacing.md)
                }
            }
            .navigationTitle("모집 재개")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.locale, Locale(identifier: "ko_KR"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        store.send(.reopenDismissed)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                FMButton(title: "모집 재개") {
                    store.send(.reopenConfirmed)
                }
                .fmSheetBottomBar()
            }
        }
        .fmSheetStyle()
        .presentationDetents([.medium, .large])
    }

    // MARK: - Styling Helpers

    private func sectionCard<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: FMSpacing.sm) {
            Text(title)
                .font(FMTypography.headline)
                .foregroundStyle(FMColors.label)

            content()
        }
        .padding(FMSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FMColors.background)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous)
                .stroke(FMColors.accent.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: FMShadow.sectionColor, radius: FMShadow.sectionRadius, y: FMShadow.sectionY)
    }
}
