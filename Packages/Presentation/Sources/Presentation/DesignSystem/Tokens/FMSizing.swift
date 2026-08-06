import SwiftUI

public enum FMSizing {
    /// 페이지 인디케이터 점 크기
    public static let dot: CGFloat = 8
    /// 카드 내 콘텐츠 영역 표준 높이
    public static let cardStandard: CGFloat = 160

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
}

public enum FMOpacity {
    public static let half: Double = 0.5
}

public enum FMShadow {
    public static let cardColor = Color.black.opacity(0.07)
    public static let cardRadius: CGFloat = 14
    public static let cardY: CGFloat = 6
}
