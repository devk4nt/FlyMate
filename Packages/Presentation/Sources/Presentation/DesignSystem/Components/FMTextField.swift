import SwiftUI

/// A styled text field wrapper with title label, placeholder,
/// optional error message, and optional character limit indicator.
public struct FMTextField: View {
    private let title: String
    private let placeholder: String
    @Binding private var text: String
    private let errorMessage: String?
    private let characterLimit: Int?

    public init(
        title: String,
        placeholder: String,
        text: Binding<String>,
        errorMessage: String? = nil,
        characterLimit: Int? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.errorMessage = errorMessage
        self.characterLimit = characterLimit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FMSpacing.xxs) {
            Text(title)
                .font(FMTypography.caption1)
                .foregroundStyle(FMColors.secondaryLabel)
                .accessibilityAddTraits(.isHeader)

            TextField(placeholder, text: $text)
                .font(FMTypography.body)
                .padding(.horizontal, FMSpacing.sm)
                .padding(.vertical, FMSpacing.xs)
                .background(FMColors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))
                .overlay {
                    RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm)
                        .stroke(borderColor, lineWidth: 1)
                }
                .onChange(of: text) { _, newValue in
                    if let limit = characterLimit, newValue.count > limit {
                        text = String(newValue.prefix(limit))
                    }
                }
                .accessibilityLabel(title)
                .accessibilityValue(text)

            HStack {
                if let errorMessage {
                    Text(errorMessage)
                        .font(FMTypography.caption2)
                        .foregroundStyle(FMColors.destructive)
                        .accessibilityLabel("오류: \(errorMessage)")
                }

                Spacer()

                if let limit = characterLimit {
                    Text("\(text.count)/\(limit)")
                        .font(FMTypography.caption2)
                        .foregroundStyle(characterCountColor)
                        .accessibilityLabel("글자 수 \(text.count) / \(limit)")
                }
            }
        }
    }

    // MARK: - Styling Helpers

    private var borderColor: Color {
        if errorMessage != nil {
            return FMColors.destructive
        }
        return FMColors.border
    }

    private var characterCountColor: Color {
        guard let limit = characterLimit else { return FMColors.secondaryLabel }
        if text.count >= limit {
            return FMColors.destructive
        }
        return FMColors.secondaryLabel
    }
}

#Preview {
    VStack(spacing: FMSpacing.md) {
        FMTextField(
            title: "제목",
            placeholder: "스터디 이름을 입력하세요",
            text: .constant("테스트"),
            characterLimit: 30
        )

        FMTextField(
            title: "설명",
            placeholder: "설명을 입력하세요",
            text: .constant(""),
            errorMessage: "필수 입력 항목입니다."
        )
    }
    .padding()
}
