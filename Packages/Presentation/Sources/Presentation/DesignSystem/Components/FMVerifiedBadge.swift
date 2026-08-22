import SwiftUI

// MARK: - Verified User IDs Environment

private struct VerifiedUserIDsKey: EnvironmentKey {
    static let defaultValue: Set<UUID> = []
}

public extension EnvironmentValues {
    /// 현직자 인증된 사용자 ID 집합. 앱 루트(AppView)에서 주입하며 하위 트리·시트까지 전파된다.
    /// 작성자 표시 지점에서 `FMVerifiedBadge(userID:)`가 이 값을 읽어 뱃지 노출을 판단한다.
    var verifiedUserIDs: Set<UUID> {
        get { self[VerifiedUserIDsKey.self] }
        set { self[VerifiedUserIDsKey.self] = newValue }
    }
}

// MARK: - Verified Badge

/// 작성자 이름 우측에 붙는 현직자 인증 뱃지 (인스타그램 인증 마크 형태).
/// `userID`가 인증 집합에 포함될 때만 렌더된다 — 미인증이면 빈 뷰.
public struct FMVerifiedBadge: View {
    @Environment(\.verifiedUserIDs) private var verifiedUserIDs
    private let userID: UUID?

    public init(userID: UUID?) {
        self.userID = userID
    }

    public var body: some View {
        if let userID, verifiedUserIDs.contains(userID) {
            Image(systemName: "checkmark.seal.fill")
                .font(FMTypography.caption1)
                .foregroundStyle(FMColors.accent)
                .accessibilityLabel("현직자 인증됨")
        }
    }
}

private enum VerifiedBadgePreviewID {
    static let verified = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
}

#Preview {
    VStack(spacing: FMSpacing.md) {
        HStack { Text("인증 회원"); FMVerifiedBadge(userID: VerifiedBadgePreviewID.verified) }
        HStack { Text("일반 회원"); FMVerifiedBadge(userID: UUID()) }
    }
    .environment(\.verifiedUserIDs, [VerifiedBadgePreviewID.verified])
}
