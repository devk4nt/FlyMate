import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct FeedbackWriteView: View {
    @Bindable var store: StoreOf<FeedbackWriteFeature>

    public init(store: StoreOf<FeedbackWriteFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: FMSpacing.md) {
            // 타임스탬프 표시
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(FMColors.accent)
                Text(store.timestampSeconds.minuteSecondFormatted)
                    .font(FMTypography.headline)
                Spacer()
            }
            .padding(.horizontal, FMSpacing.md)

            // 피드백 입력
            VStack(alignment: .trailing, spacing: FMSpacing.xxs) {
                ZStack(alignment: .bottom) {
                    MentionTextEditor(
                        text: $store.content.sending(\.contentChanged)
                    )
                    .frame(minHeight: 120)
                    .padding(FMSpacing.xs)
                    .background(FMColors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))

                    if store.showMentionSuggestions {
                        mentionSuggestionsView
                    }
                }

                Text("\(store.content.count)/\(AppConstants.maxFeedbackLength)")
                    .font(FMTypography.caption2)
                    .foregroundStyle(
                        store.content.count > AppConstants.maxFeedbackLength
                            ? FMColors.destructive
                            : FMColors.secondaryLabel
                    )
            }
            .padding(.horizontal, FMSpacing.md)

            if let error = store.error {
                Text(error.errorDescription ?? "오류가 발생했습니다.")
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.destructive)
                    .padding(.horizontal, FMSpacing.md)
            }

            Spacer()
        }
        .padding(.top, FMSpacing.md)
        .navigationTitle("피드백 작성")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") { store.send(.cancelTapped) }
            }
            ToolbarItem(placement: .confirmationAction) {
                FMButton(
                    title: "등록",
                    style: .text,
                    isLoading: store.isSubmitting,
                    isEnabled: store.isValid
                ) {
                    store.send(.submitTapped)
                }
            }
        }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Mention Suggestions

    private var mentionSuggestionsView: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // @전체 옵션
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

                    // 개별 멤버 목록
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
        }
        .background(FMColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))
        .shadow(color: .black.opacity(0.1), radius: 4, y: -2)
        .padding(.horizontal, FMSpacing.xxs)
        .padding(.bottom, FMSpacing.xxs)
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

// MARK: - MentionTextEditor (UIViewRepresentable)

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
        // 외부(TCA)에서 text가 변경된 경우에만 업데이트
        if textView.text != text {
            applyHighlighting(to: textView, with: text)
            // 외부 변경(멘션 선택 등)이므로 커서를 텍스트 끝으로 이동
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
            // 커서 위치 저장
            let selectedRange = textView.selectedRange

            // Binding 업데이트 (TCA contentChanged 트리거)
            text = newText

            // 하이라이팅 재적용
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

            // 커서 위치 복원
            let safeLocation = min(selectedRange.location, newText.count)
            let safeLength = min(selectedRange.length, newText.count - safeLocation)
            textView.selectedRange = NSRange(location: safeLocation, length: safeLength)
        }
    }
}
