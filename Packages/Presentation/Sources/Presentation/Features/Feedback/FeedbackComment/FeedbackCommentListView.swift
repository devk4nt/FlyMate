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

            Divider()

            commentInputBar
        }
        .navigationTitle("댓글")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.send(.onAppear) }
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
                                FMSkeletonView()
                                    .frame(height: 48)
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

            HStack(alignment: .bottom, spacing: FMSpacing.sm) {
                ZStack(alignment: .leading) {
                    if store.commentText.isEmpty {
                        Text("댓글을 입력하세요...")
                            .font(FMTypography.callout)
                            .foregroundStyle(FMColors.secondaryLabel)
                            .padding(.horizontal, FMSpacing.xs)
                    }

                    MentionTextEditor(
                        text: $store.commentText.sending(\.commentTextChanged)
                    )
                    .frame(minHeight: 36, maxHeight: 100)
                }
                .padding(.horizontal, FMSpacing.xs)
                .background(FMColors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))

                Button {
                    store.send(.submitTapped)
                } label: {
                    if store.isSubmitting {
                        ProgressView()
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                store.isValid
                                    ? FMColors.accent
                                    : FMColors.secondaryLabel.opacity(0.5)
                            )
                    }
                }
                .disabled(!store.isValid || store.isSubmitting)
            }
            .padding(.horizontal, FMSpacing.md)
            .padding(.vertical, FMSpacing.sm)
            .background(FMColors.background)
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
        Group {
            if let url = member.profileImageURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundStyle(FMColors.secondaryLabel)
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(FMColors.secondaryLabel)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
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
                            .font(.system(size: 14))
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
        Group {
            if let url = comment.authorProfileURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundStyle(FMColors.secondaryLabel)
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(FMColors.secondaryLabel)
            }
        }
        .frame(width: 24, height: 24)
        .clipShape(Circle())
    }
}

// MARK: - MentionTextEditor (재사용)

private struct MentionTextEditor: UIViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.font = .systemFont(ofSize: 16, weight: .regular)
        textView.tintColor = .systemBlue
        textView.typingAttributes = [
            .font: UIFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            applyHighlighting(to: textView, with: text)
            let endPosition = textView.text.count
            textView.selectedRange = NSRange(location: endPosition, length: 0)
        }
    }

    private func applyHighlighting(to textView: UITextView, with text: String) {
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        let attributed = NSMutableAttributedString(string: text, attributes: baseAttributes)

        let mentionAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
        ]

        if let regex = try? NSRegularExpression(pattern: "@\\S+") {
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
            for match in matches {
                attributed.addAttributes(mentionAttributes, range: match.range)
            }
        }

        textView.attributedText = attributed
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            let newText = textView.text ?? ""
            let selectedRange = textView.selectedRange

            text = newText

            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor.label
            ]
            let attributed = NSMutableAttributedString(string: newText, attributes: baseAttributes)

            let mentionAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.systemBlue,
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
            ]

            if let regex = try? NSRegularExpression(pattern: "@\\S+") {
                let matches = regex.matches(
                    in: newText,
                    range: NSRange(location: 0, length: (newText as NSString).length)
                )
                for match in matches {
                    attributed.addAttributes(mentionAttributes, range: match.range)
                }
            }

            textView.attributedText = attributed

            let safeLocation = min(selectedRange.location, newText.count)
            let safeLength = min(selectedRange.length, newText.count - safeLocation)
            textView.selectedRange = NSRange(location: safeLocation, length: safeLength)
        }
    }
}
