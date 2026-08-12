import SwiftUI
import UIKit

/// YouTube-style @mention 하이라이팅을 지원하는 텍스트 에디터
public struct FMMentionTextEditor: UIViewRepresentable {
    @Binding var text: String
    var isFocused: Binding<Bool>?

    public init(text: Binding<String>, isFocused: Binding<Bool>? = nil) {
        _text = text
        self.isFocused = isFocused
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: isFocused)
    }

    public func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.adjustsFontForContentSizeCategory = true
        textView.font = Self.scaledBodyFont()
        textView.tintColor = Self.mentionColor
        textView.typingAttributes = Self.baseAttributes
        context.coordinator.lastContentSizeCategory = textView.traitCollection.preferredContentSizeCategory
        return textView
    }

    /// 콘텐츠 높이에 맞춰 자체 크기 계산 — 미구현 시 제안된 최대 높이를 항상 차지한다.
    /// 호출부의 frame(minHeight:maxHeight:)이 최종 클램핑을 담당한다.
    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, width.isFinite else { return nil }
        let fitting = uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: width, height: fitting.height)
    }

    public func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.isFocused = isFocused

        let contentSizeCategory = textView.traitCollection.preferredContentSizeCategory
        if textView.text != text || context.coordinator.lastContentSizeCategory != contentSizeCategory {
            let selectedRange = textView.selectedRange
            let textChanged = textView.text != text
            applyHighlighting(to: textView, with: text)
            let textLength = (text as NSString).length
            let safeLocation = textChanged ? textLength : min(selectedRange.location, textLength)
            let safeLength = textChanged ? 0 : min(selectedRange.length, textLength - safeLocation)
            textView.selectedRange = NSRange(location: safeLocation, length: safeLength)
            context.coordinator.lastContentSizeCategory = contentSizeCategory
        }

        // 포커스 관리
        if let isFocused = isFocused {
            if isFocused.wrappedValue && !textView.isFirstResponder {
                DispatchQueue.main.async {
                    textView.becomeFirstResponder()
                }
            } else if !isFocused.wrappedValue && textView.isFirstResponder {
                DispatchQueue.main.async {
                    textView.resignFirstResponder()
                }
            }
        }
    }

    private func applyHighlighting(to textView: UITextView, with text: String) {
        textView.attributedText = Self.highlightedText(text)
        textView.typingAttributes = Self.baseAttributes
    }

    private static var baseAttributes: [NSAttributedString.Key: Any] {
        [
            .font: scaledBodyFont(),
            .foregroundColor: UIColor.label
        ]
    }

    private static var mentionAttributes: [NSAttributedString.Key: Any] {
        [
            .foregroundColor: mentionColor,
            .font: scaledBodyFont(weight: .semibold)
        ]
    }

    private static var mentionColor: UIColor {
        UIColor(named: "Primary", in: .module, compatibleWith: nil) ?? .systemBlue
    }

    private static func scaledBodyFont(weight: UIFont.Weight = .regular) -> UIFont {
        UIFontMetrics(forTextStyle: .body).scaledFont(
            for: UIFont.systemFont(ofSize: 16, weight: weight)
        )
    }

    private static func highlightedText(_ text: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text, attributes: baseAttributes)
        if let regex = try? NSRegularExpression(pattern: "@\\S+") {
            let range = NSRange(location: 0, length: (text as NSString).length)
            for match in regex.matches(in: text, range: range) {
                attributed.addAttributes(mentionAttributes, range: match.range)
            }
        }
        return attributed
    }

    public final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        var isFocused: Binding<Bool>?
        var lastContentSizeCategory: UIContentSizeCategory?

        init(text: Binding<String>, isFocused: Binding<Bool>?) {
            _text = text
            self.isFocused = isFocused
        }

        public func textViewDidChange(_ textView: UITextView) {
            let newText = textView.text ?? ""
            let selectedRange = textView.selectedRange

            text = newText

            textView.attributedText = FMMentionTextEditor.highlightedText(newText)
            textView.typingAttributes = FMMentionTextEditor.baseAttributes

            let textLength = (newText as NSString).length
            let safeLocation = min(selectedRange.location, textLength)
            let safeLength = min(selectedRange.length, textLength - safeLocation)
            textView.selectedRange = NSRange(location: safeLocation, length: safeLength)
        }

        public func textViewDidBeginEditing(_ textView: UITextView) {
            isFocused?.wrappedValue = true
        }

        public func textViewDidEndEditing(_ textView: UITextView) {
            isFocused?.wrappedValue = false
        }
    }
}
