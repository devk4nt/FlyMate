import SwiftUI
import ComposableArchitecture
import Core
import Domain

/// 피드 페이지에서 올라오는 시트 — 촬영 포인트/피드백 요청, 피드백 목록, 댓글 입력.
public struct VideoFeedbackSheet: View {
    @Bindable var store: StoreOf<VideoDetailFeature>

    public init(store: StoreOf<VideoDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            videoInfoSection
            feedbackSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColors.background)
        .safeAreaInset(edge: .bottom) {
            CommentInputBar(
                store: store.scope(state: \.commentInput, action: \.commentInput),
                currentTimestamp: store.player.currentTime
            )
        }
        .fmToast(
            isPresented: Binding(
                get: { store.showToast },
                set: { _ in store.send(.toastDismissed) }
            ),
            message: store.toastMessage,
            type: store.toastType
        )
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") {
                    store.send(.commentInput(.focusChanged(false)))
                }
            }
        }
        .sheet(item: $store.scope(state: \.feedbackCommentList, action: \.feedbackCommentList)) { commentStore in
            NavigationStack {
                FeedbackCommentListView(store: commentStore)
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Header

    private var header: some View {
        Text("피드백 \(feedbackCount)개")
            .font(FMTypography.caption1)
            .fontWeight(.semibold)
            .foregroundStyle(FMColors.secondaryLabel)
            .frame(maxWidth: .infinity)
            .padding(.top, FMSpacing.md)
            .padding(.bottom, FMSpacing.sm)
    }

    private var feedbackCount: Int {
        if case .loaded(let feedbacks) = store.feedbacks {
            return feedbacks.count
        }
        return store.video.feedbackCount
    }

    // MARK: - Video Info

    @ViewBuilder
    private var videoInfoSection: some View {
        let hasInfo = store.video.focusPoints != nil || store.video.feedbackRequest != nil
        if hasInfo {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                if let focusPoints = store.video.focusPoints {
                    VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                        Label("촬영 포인트", systemImage: "video.fill")
                            .font(FMTypography.caption1)
                            .foregroundStyle(FMColors.secondaryLabel)
                        Text(focusPoints)
                            .font(FMTypography.body)
                            .foregroundStyle(FMColors.label)
                    }
                }

                if let feedbackRequest = store.video.feedbackRequest {
                    VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                        Label("피드백 요청", systemImage: "text.bubble")
                            .font(FMTypography.caption1)
                            .foregroundStyle(FMColors.secondaryLabel)
                        Text(feedbackRequest)
                            .font(FMTypography.body)
                            .foregroundStyle(FMColors.label)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FMSpacing.md)
            .background(FMColors.secondaryBackground)
        }
    }

    // MARK: - Feedback Section

    private var feedbackSection: some View {
        Group {
            switch store.feedbacks {
            case .idle, .loading:
                VStack {
                    ForEach(0..<3, id: \.self) { _ in
                        FMSkeletonView()
                            .frame(height: 60)
                    }
                }
                .padding(FMSpacing.md)
                .frame(maxHeight: .infinity, alignment: .top)

            case .loaded(let feedbacks):
                if feedbacks.isEmpty {
                    VStack(spacing: FMSpacing.sm) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: FMSizing.IconSize.lg))
                            .foregroundStyle(FMColors.secondaryLabel)
                        Text("아직 피드백이 없습니다")
                            .font(FMTypography.callout)
                            .foregroundStyle(FMColors.secondaryLabel)
                        Text("첫 번째 댓글을 남겨보세요")
                            .font(FMTypography.caption1)
                            .foregroundStyle(FMColors.secondaryLabel.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(FMSpacing.xl)
                } else {
                    feedbackList(feedbacks)
                }

            case .failed(let error):
                FMErrorView(error: error) {}
            }
        }
    }

    private func feedbackList(_ feedbacks: [Domain.Feedback]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: FMSpacing.xs) {
                    ForEach(feedbacks) { feedback in
                        FeedbackRow(
                            feedback: feedback,
                            isHighlighted: store.focusedFeedbackID == feedback.id,
                            isExpanded: store.expandedFeedbackIDs.contains(feedback.id),
                            replies: store.repliesByFeedback[feedback.id],
                            currentUserID: store.currentUserID,
                            onTimestampTapped: {
                                store.send(.feedbackTapped(feedback))
                            },
                            onReplyTapped: {
                                store.send(.replyTapped(feedback))
                            },
                            onToggleReplies: {
                                store.send(.toggleRepliesTapped(feedback))
                            },
                            onDeleteReply: { comment in
                                store.send(.deleteReplyTapped(comment))
                            }
                        )
                        .id(feedback.id)
                    }
                }
                .padding(FMSpacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: store.focusedFeedbackID) { _, focusedID in
                if let focusedID {
                    withAnimation {
                        proxy.scrollTo(focusedID, anchor: .center)
                    }
                }
            }
            .onAppear {
                if let focusedID = store.focusedFeedbackID {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            proxy.scrollTo(focusedID, anchor: .center)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Feedback Row

private struct FeedbackRow: View {
    let feedback: Domain.Feedback
    var isHighlighted: Bool = false
    var isExpanded: Bool = false
    var replies: LoadingState<[FeedbackComment]>?
    var currentUserID: UUID?
    var onTimestampTapped: (() -> Void)?
    var onReplyTapped: (() -> Void)?
    var onToggleReplies: (() -> Void)?
    var onDeleteReply: ((FeedbackComment) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 메인 피드백 콘텐츠
            HStack(alignment: .top, spacing: FMSpacing.sm) {
                // 타임스탬프 뱃지
                Text(feedback.timestampSeconds.minuteSecondFormatted)
                    .font(FMTypography.caption1)
                    .padding(.horizontal, FMSpacing.xs)
                    .padding(.vertical, FMSpacing.xxxs)
                    .background(FMColors.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))
                    .onTapGesture {
                        onTimestampTapped?()
                    }

                VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                    HStack {
                        Text(feedback.authorName)
                            .font(FMTypography.caption1)
                            .fontWeight(.semibold)
                        Text(feedback.createdAt.relativeString)
                            .font(FMTypography.caption2)
                            .foregroundStyle(FMColors.secondaryLabel)
                    }
                    Text(feedback.content)
                        .font(FMTypography.callout)
                }

                Spacer(minLength: 0)
            }
            .padding(FMSpacing.sm)

            // 액션 버튼 영역
            HStack(spacing: FMSpacing.md) {
                // 답글 버튼
                Button {
                    onReplyTapped?()
                } label: {
                    HStack(spacing: FMSpacing.xxxs) {
                        Image(systemName: "arrowshape.turn.up.left")
                            .font(.system(size: FMSizing.IconSize.xs))
                        Text("답글")
                            .font(FMTypography.caption2)
                    }
                    .foregroundStyle(FMColors.secondaryLabel)
                }
                .accessibilityLabel("답글 달기")

                // 답글 토글 버튼 (댓글이 있을 때만)
                if feedback.commentCount > 0 {
                    Button {
                        onToggleReplies?()
                    } label: {
                        HStack(spacing: FMSpacing.xxxs) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: FMSizing.IconSize.xs))
                            Text(isExpanded ? "답글 숨기기" : "답글 \(feedback.commentCount)개 보기")
                                .font(FMTypography.caption2)
                        }
                        .foregroundStyle(FMColors.accent)
                    }
                    .accessibilityLabel(isExpanded ? "답글 숨기기" : "답글 \(feedback.commentCount)개 보기")
                }

                Spacer()
            }
            .padding(.horizontal, FMSpacing.sm)
            .padding(.bottom, FMSpacing.xs)

            // 인라인 답글 확장
            if isExpanded {
                Divider()
                    .padding(.horizontal, FMSpacing.sm)

                inlineRepliesSection
            }
        }
        .background(
            isHighlighted
                ? FMColors.accent.opacity(0.15)
                : FMColors.secondaryBackground
        )
        .animation(.easeInOut(duration: 0.6), value: isHighlighted)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))
    }

    // MARK: - Inline Replies

    @ViewBuilder
    private var inlineRepliesSection: some View {
        switch replies {
        case .loading:
            HStack {
                Spacer()
                ProgressView()
                    .padding(FMSpacing.sm)
                Spacer()
            }
            .padding(.leading, FMSpacing.xl)

        case .loaded(let comments):
            if comments.isEmpty {
                Text("아직 답글이 없습니다")
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .padding(FMSpacing.sm)
                    .padding(.leading, FMSpacing.xl)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(comments) { comment in
                        InlineReplyRow(
                            comment: comment,
                            isAuthor: comment.authorID == currentUserID,
                            onDelete: { onDeleteReply?(comment) }
                        )
                    }
                }
            }

        case .failed:
            Text("답글을 불러오지 못했습니다")
                .font(FMTypography.caption1)
                .foregroundStyle(FMColors.destructive)
                .padding(FMSpacing.sm)
                .padding(.leading, FMSpacing.xl)

        case .idle, .none:
            EmptyView()
        }
    }
}

// MARK: - Inline Reply Row

private struct InlineReplyRow: View {
    let comment: FeedbackComment
    var isAuthor: Bool = false
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: FMSpacing.xs) {
            profileImage

            VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                HStack {
                    Text(comment.authorName)
                        .font(FMTypography.caption2)
                        .fontWeight(.semibold)

                    Text(comment.createdAt.relativeString)
                        .font(FMTypography.caption2)
                        .foregroundStyle(FMColors.secondaryLabel)

                    Spacer()

                    if isAuthor {
                        Menu {
                            Button(role: .destructive) {
                                onDelete?()
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: FMSizing.IconSize.xs))
                                .foregroundStyle(FMColors.secondaryLabel)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                    }
                }

                Text(comment.content)
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.label)
            }
        }
        .padding(.horizontal, FMSpacing.sm)
        .padding(.vertical, FMSpacing.xs)
        .padding(.leading, FMSpacing.xl)
    }

    private var profileImage: some View {
        FMProfileImage(url: comment.authorProfileURL, name: comment.authorName, size: .xs)
    }
}
