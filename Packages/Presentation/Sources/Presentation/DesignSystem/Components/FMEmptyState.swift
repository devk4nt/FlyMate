import SwiftUI

/// An empty state view displaying a system image, title, description,
/// and an optional action button.
public struct FMEmptyState: View {
    private let systemImage: String
    private let title: String
    private let description: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        systemImage: String,
        title: String,
        description: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: FMSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(FMColors.secondaryLabel)
                .accessibilityHidden(true)

            VStack(spacing: FMSpacing.xs) {
                Text(title)
                    .font(FMTypography.title3)
                    .foregroundStyle(FMColors.label)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(FMTypography.body)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                FMButton(
                    title: actionTitle,
                    style: .primary,
                    action: action
                )
                .fixedSize(horizontal: true, vertical: false)
                .padding(.top, FMSpacing.xs)
            }
        }
        .padding(FMSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    FMEmptyState(
        systemImage: "doc.text.magnifyingglass",
        title: "스터디가 없습니다",
        description: "새로운 스터디를 만들거나\n초대 코드로 참여해보세요.",
        actionTitle: "스터디 만들기"
    ) {
        // action
    }
}
