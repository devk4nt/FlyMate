import SwiftUI
import ComposableArchitecture
import Core
import Domain

struct CommentInputBar: View {
    @Bindable var store: StoreOf<CommentInputFeature>
    let currentTimestamp: TimeInterval

    var body: some View {
        VStack(spacing: 0) {
            // 에러 배너
            if let error = store.error {
                HStack(spacing: FMSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: FMSizing.IconSize.xs))
                        .foregroundStyle(FMColors.destructive)

                    Text(error.localizedDescription)
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.destructive)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.horizontal, FMSpacing.md)
                .padding(.vertical, FMSpacing.xs)
                .background(FMColors.destructive.opacity(0.1))
            }

            // 멘션 서제스천
            if store.showMentionSuggestions {
                mentionSuggestionsView
            }

            // 답글 컨텍스트 배너
            if let context = store.replyContext {
                replyContextBanner(context: context)
            }

            Divider()

            // 입력 바
            HStack(alignment: .bottom, spacing: FMSpacing.sm) {
                ZStack(alignment: .leading) {
                    if store.text.isEmpty {
                        Text("댓글을 입력하세요...")
                            .font(FMTypography.callout)
                            .foregroundStyle(FMColors.secondaryLabel)
                            .padding(.horizontal, FMSpacing.xs)
                    }

                    FMMentionTextEditor(
                        text: $store.text.sending(\.textChanged),
                        isFocused: $store.isFocused.sending(\.focusChanged)
                    )
                    .frame(minHeight: 36, maxHeight: 100)
                }
                .padding(.horizontal, FMSpacing.xs)
                .background(FMColors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))

                Button {
                    store.send(.submitTapped(timestampSeconds: currentTimestamp))
                } label: {
                    if store.isSubmitting {
                        ProgressView()
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: FMSizing.IconSize.lg))
                            .foregroundStyle(
                                store.isValid
                                    ? FMColors.accent
                                    : FMColors.secondaryLabel.opacity(0.5)
                            )
                    }
                }
                .disabled(!store.isValid || store.isSubmitting)
                .accessibilityLabel("전송")
            }
            .padding(.horizontal, FMSpacing.md)
            .padding(.vertical, FMSpacing.sm)
        }
        .background(FMColors.background)
    }

    // MARK: - Reply Context Banner

    private func replyContextBanner(context: CommentInputFeature.ReplyContext) -> some View {
        HStack(spacing: FMSpacing.xs) {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.system(size: FMSizing.IconSize.xs))
                .foregroundStyle(FMColors.accent)

            Text("\(context.authorName)님에게 답글 남기는 중")
                .font(FMTypography.caption1)
                .foregroundStyle(FMColors.secondaryLabel)
                .lineLimit(1)

            Spacer()

            Button {
                store.send(.exitReplyMode)
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
