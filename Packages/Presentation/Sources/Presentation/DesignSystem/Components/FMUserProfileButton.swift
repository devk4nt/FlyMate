import Foundation
import SwiftUI

/// 작성자의 프로필 이미지와 이름을 함께 표시하고 활동 내역을 여는 버튼.
public struct FMUserProfileButton: View {
    public enum Style {
        case compact
        case standard
    }

    private let url: URL?
    private let name: String
    private let userID: UUID?
    private let imageSize: FMProfileImage.Size
    private let style: Style
    private let action: () -> Void

    public init(
        url: URL?,
        name: String,
        userID: UUID? = nil,
        imageSize: FMProfileImage.Size = .sm,
        style: Style = .standard,
        action: @escaping () -> Void
    ) {
        self.url = url
        self.name = name
        self.userID = userID
        self.imageSize = imageSize
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: FMSpacing.xs) {
                FMProfileImage(url: url, name: name, size: imageSize)

                Text(name)
                    .font(style == .compact ? FMTypography.feedMetaEmphasis : FMTypography.authorName)
                    .foregroundStyle(FMColors.label)
                    .lineLimit(1)

                FMVerifiedBadge(userID: userID)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name) 프로필")
        .accessibilityHint("활동 내역을 엽니다")
    }
}
