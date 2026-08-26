import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct FeedbackCommentListView: View {
    @Bindable var store: StoreOf<FeedbackCommentListFeature>

    public init(store: StoreOf<FeedbackCommentListFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            commentListContent
            commentInputBar
        }
        .background(FMColors.canvas)
        .navigationTitle("댓글")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.send(.onAppear) }
        .fmSheetStyle()
    }

    // MARK: - Comment List

    private var commentListContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // 원본 피드백
                    originalFeedbackHeader
                        .padding(FMSpacing.md)

                    Divider()
                        .padding(.horizontal, FMSpacing.md)

                    // 댓글 목록
                    switch store.comments {
                    case .idle, .loading:
                        VStack(spacing: FMSpacing.sm) {
                            ForEach(0..<3, id: \.self) { _ in
                                FMSkeletonView(height: 48)
                            }
                        }
                        .padding(FMSpacing.md)

                    case .loaded(let comments):
                        if comments.isEmpty {
                            VStack(spacing: FMSpacing.sm) {
                                Text("아직 댓글이 없습니다")
                                    .font(FMTypography.callout)
                                    .foregroundStyle(FMColors.secondaryLabel)
                                    .padding(.top, FMSpacing.xl)
                            }
                        } else {
                            ForEach(comments) { comment in
                                CommentRow(
                                    comment: comment,
                                    isAuthor: comment.authorID == store.currentUserID,
                                    onDelete: {
                                        store.send(.deleteCommentTapped(comment))
                                    }
                                )
                                .id(comment.id)
                            }
                        }

                    case .failed(let error):
                        FMErrorView(error: error) {
                            store.send(.onAppear)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
        }
    }

    // MARK: - Original Feedback Header

    private var originalFeedbackHeader: some View {
        VStack(alignment: .leading, spacing: FMSpacing.xs) {
            HStack(spacing: FMSpacing.sm) {
                Text(store.feedback.timestampSeconds.minuteSecondFormatted)
                    .font(FMTypography.caption1)
                    .padding(.horizontal, FMSpacing.xs)
                    .padding(.vertical, FMSpacing.xxxs)
                    .background(FMColors.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))

                Text(store.feedback.authorName)
                    .font(FMTypography.caption1)
                    .fontWeight(.semibold)

                FMVerifiedBadge(userID: store.feedback.authorID)

                Text(store.feedback.createdAt.relativeString)
                    .font(FMTypography.caption2)
                    .foregroundStyle(FMColors.secondaryLabel)

                Spacer()
            }

            Text(store.feedback.content)
                .font(FMTypography.body)
                .foregroundStyle(FMColors.label)
        }
    }

    // MARK: - Comment Input Bar

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            if store.showMentionSuggestions {
                mentionSuggestionsView
            }

            HStack(alignment: .bottom, spacing: FMSpacing.xs) {
                ZStack(alignment: .topLeading) {
                    if store.commentText.isEmpty {
                        Text("댓글을 입력하세요...")
                            .font(FMTypography.callout)
                            .foregroundStyle(FMColors.secondaryLabel)
                            .padding(.leading, FMSpacing.sm)
                            .padding(.top, FMSpacing.sm)
                            .allowsHitTesting(false)
                    }

                    FMMentionTextEditor(
                        text: $store.commentText.sending(\.commentTextChanged)
                    )
                    .frame(height: 44)
                }
                .fmComposerSurface()

                Button {
                    store.send(.submitTapped)
                } label: {
                    ZStack {
                        Circle()
                            .fill(store.isValid ? FMColors.accentFill : FMColors.secondaryBackground)

                        if store.isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: FMSizing.IconSize.sm, weight: .bold))
                                .foregroundStyle(store.isValid ? .white : FMColors.secondaryLabel.opacity(0.6))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .overlay {
                        if !store.isValid {
                            Circle()
                                .stroke(FMColors.border.opacity(0.45), lineWidth: 0.5)
                        }
                    }
                }
                .disabled(!store.isValid || store.isSubmitting)
                .accessibilityLabel("전송")
            }
            .padding(.horizontal, FMSpacing.md)
            .padding(.top, FMSpacing.xs)
            .padding(.bottom, FMSpacing.sm)
            .background(FMColors.background)
            .overlay(alignment: .top) {
                Divider()
            }
        }
    }

    // MARK: - Mention Suggestions

    private var mentionSuggestionsView: some View {
        VStack(spacing: 0) {
            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    Button {
                        store.send(.mentionAllTapped)
                    } label: {
                        HStack(spacing: FMSpacing.sm) {
                            Image(systemName: "person.3.fill")
                                .font(FMTypography.caption1)
                                .foregroundStyle(FMColors.accent)
                                .frame(width: 28, height: 28)

                            Text("전체 (@전체)")
                                .font(FMTypography.callout)
                                .fontWeight(.medium)
                                .foregroundStyle(FMColors.label)

                            Spacer()
                        }
                        .padding(.horizontal, FMSpacing.sm)
                        .padding(.vertical, FMSpacing.xs)
                    }

                    Divider()

                    ForEach(store.filteredMembers) { member in
                        Button {
                            store.send(.mentionSuggestionTapped(member))
                        } label: {
                            HStack(spacing: FMSpacing.sm) {
                                memberProfileImage(member)

                                Text(member.userName)
                                    .font(FMTypography.callout)
                                    .foregroundStyle(FMColors.label)

                                Spacer()
                            }
                            .padding(.horizontal, FMSpacing.sm)
                            .padding(.vertical, FMSpacing.xs)
                        }
                    }
                }
            }
            .frame(maxHeight: 180)
            .background(FMColors.secondaryBackground)
        }
    }

    private func memberProfileImage(_ member: StudyMember) -> some View {
        FMProfileImage(url: member.profileImageURL, name: member.userName, size: .sm)
    }
}

// MARK: - Comment Row

private struct CommentRow: View {
    let comment: FeedbackComment
    var isAuthor: Bool = false
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: FMSpacing.xxs) {
            HStack {
                profileImage

                Text(comment.authorName)
                    .font(FMTypography.caption1)
                    .fontWeight(.semibold)

                FMVerifiedBadge(userID: comment.authorID)

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
                            .font(.system(size: FMSizing.IconSize.sm))
                            .foregroundStyle(FMColors.secondaryLabel)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                }
            }

            Text(comment.content)
                .font(FMTypography.callout)
                .foregroundStyle(FMColors.label)
        }
        .padding(.horizontal, FMSpacing.md)
        .padding(.vertical, FMSpacing.sm)
    }

    private var profileImage: some View {
        FMProfileImage(url: comment.authorProfileURL, name: comment.authorName, size: .xs)
    }
}

#Preview("댓글 없음") {
    let feedback = Feedback(
        id: UUID(),
        videoID: UUID(),
        studyID: UUID(),
        authorID: UUID(),
        authorName: "김하늘",
        content: "첫 문장에서 미소가 좋았어요.",
        timestampSeconds: 15,
        createdAt: Date()
    )
    var state = FeedbackCommentListFeature.State(feedback: feedback, studyID: UUID())
    state.comments = .loaded([])
    return NavigationStack {
        FeedbackCommentListView(
            store: Store(initialState: state) {
                FeedbackCommentListFeature()
            } withDependencies: {
                $0.studyClient.fetchStudy = { _ in
                    Study(
                        id: UUID(), name: "스터디", description: "",
                        ownerID: UUID(), inviteCode: "AAA123", maxMembers: 8,
                        members: [], createdAt: Date()
                    )
                }
            }
        )
    }
}
