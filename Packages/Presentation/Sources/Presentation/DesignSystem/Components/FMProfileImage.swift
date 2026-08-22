import SwiftUI
import Kingfisher

/// 원형 프로필 이미지 — 피드·댓글·멤버 목록에서 작성자를 표시하는 기본 단위.
/// URL이 없거나 로딩 중이면 이름 이니셜(이름 제공 시) 또는 사람 심볼을 표시한다.
public struct FMProfileImage: View {
    public enum Size: CGFloat {
        /// 댓글 답글 (24pt)
        case xs = 24
        /// 댓글 입력바, 피드백 셀 (28pt)
        case sm = 28
        /// 피드 작성자 헤더 (32pt)
        case md = 32
        /// 멤버/가입 신청 목록 (40pt)
        case lg = 40
        /// 프로필 상세, 멤버 통계 (64pt)
        case xl = 64
    }

    private let url: URL?
    private let name: String?
    private let size: Size

    public init(url: URL?, name: String? = nil, size: Size = .md) {
        self.url = url
        self.name = name
        self.size = size
    }

    public var body: some View {
        Group {
            if let url {
                KFImage(url)
                    .resizable()
                    .placeholder { placeholderView }
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderView
            }
        }
        .frame(width: size.rawValue, height: size.rawValue)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var placeholderView: some View {
        if let initial = name?.first {
            Circle()
                .fill(FMColors.primary.opacity(0.12))
                .overlay {
                    Text(String(initial))
                        .font(FMTypography.font(
                            size: size.rawValue * 0.45,
                            relativeTo: .body,
                            weight: .semibold
                        ))
                        .foregroundStyle(FMColors.primary)
                }
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .foregroundStyle(FMColors.secondaryLabel)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: FMSpacing.md) {
        FMProfileImage(url: nil, size: .xs)
        FMProfileImage(url: nil, name: "김승무", size: .md)
        FMProfileImage(url: nil, name: "박아나", size: .lg)
        FMProfileImage(url: nil, size: .xl)
    }
    .padding()
}
