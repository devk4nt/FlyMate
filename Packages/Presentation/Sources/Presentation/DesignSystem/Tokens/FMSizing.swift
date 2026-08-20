import SwiftUI

public enum FMSizing {
    /// 페이지 인디케이터 점 크기
    public static let dot: CGFloat = 8
    /// 카드 내 콘텐츠 영역 표준 높이
    public static let cardStandard: CGFloat = 160

    public enum ContentWidth {
        public static let regular: CGFloat = 760
        public static let form: CGFloat = 640
    }

    /// SF Symbol 아이콘 크기 (Font 포인트 단위)
    public enum IconSize {
        /// 메타 정보 인라인 아이콘 (답글 화살표, 경고 등)
        public static let xs: CGFloat = 12
        /// 셀 내 액션 아이콘 (음소거, 더보기 등)
        public static let sm: CGFloat = 16
        /// 리스트 아이콘 (알림 타입 등)
        public static let md: CGFloat = 20
        /// 주요 액션 아이콘 (전송 버튼, 업로드 등)
        public static let lg: CGFloat = 32
        /// 플레이어 컨트롤 (재생/일시정지)
        public static let xl: CGFloat = 44
        /// 일러스트형 아이콘 (빈 화면, 안내 화면)
        public static let hero: CGFloat = 48
    }

    public enum IconContainer {
        public static let sm: CGFloat = 36
        public static let md: CGFloat = 40
        public static let lg: CGFloat = 52
        public static let hero: CGFloat = 64
    }
}

public enum FMOpacity {
    public static let half: Double = 0.5
}

public enum FMShadow {
    public static let cardColor = FMColors.deepIndigo.opacity(0.055)
    public static let cardRadius: CGFloat = 8
    public static let cardY: CGFloat = 3

    public static let heroColor = Color.black.opacity(0.08)
    public static let heroRadius: CGFloat = 12
    public static let heroY: CGFloat = 4

    public static let sectionColor = FMColors.deepIndigo.opacity(0.045)
    public static let sectionRadius: CGFloat = 7
    public static let sectionY: CGFloat = 3

    public static let floatingColor = Color.black.opacity(0.08)
    public static let floatingRadius: CGFloat = 3
    public static let floatingY: CGFloat = 1

    public static let avatarColor = FMColors.brandInk.opacity(0.2)
    public static let avatarRadius: CGFloat = 12
    public static let avatarY: CGFloat = 6
}
