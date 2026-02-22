import Foundation

extension String {
    /// 문자열이 비어있거나 공백만 포함하는지 확인
    public var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 초대 코드 유효성 검사 (영문 대문자 + 숫자, 고정 길이)
    public var isValidInviteCode: Bool {
        let pattern = "^[A-Z0-9]{\(AppConstants.inviteCodeLength)}$"
        return range(of: pattern, options: .regularExpression) != nil
    }
}
