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
        textView.font = .systemFont(ofSize: 16, weight: .regular)
        textView.tintColor = .systemBlue
        textView.typingAttributes = [
            .font: UIFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        return textView
    }

    public func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.isFocused = isFocused

        if textView.text != text {
            applyHighlighting(to: textView, with: text)
            let endPosition = textView.text.count
            textView.selectedRange = NSRange(location: endPosition, length: 0)
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

    public final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        var isFocused: Binding<Bool>?

        init(text: Binding<String>, isFocused: Binding<Bool>?) {
            _text = text
            self.isFocused = isFocused
        }

        public func textViewDidChange(_ textView: UITextView) {
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

        public func textViewDidBeginEditing(_ textView: UITextView) {
            isFocused?.wrappedValue = true
        }

        public func textViewDidEndEditing(_ textView: UITextView) {
            isFocused?.wrappedValue = false
        }
    }
}
