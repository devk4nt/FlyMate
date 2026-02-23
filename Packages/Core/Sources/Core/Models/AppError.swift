import Foundation

/// 앱 전역에서 사용하는 에러 타입 계층 구조.
/// Network / Business / Unexpected 세 가지로 분류하여
/// 각 레이어에서 적절한 에러 핸들링을 수행한다.
public enum AppError: Equatable, Sendable, LocalizedError {
    case network(NetworkError)
    case business(BusinessError)
    case unexpected(String)

    public var errorDescription: String? {
        switch self {
        case .network(let error):
            return error.userMessage
        case .business(let error):
            return error.userMessage
        case .unexpected(let message):
            return message
        }
    }
}

// MARK: - NetworkError

public enum NetworkError: Equatable, Sendable {
    case noConnection
    case timeout
    case serverError(statusCode: Int)
    case invalidResponse
    case decodingFailed

    public var userMessage: String {
        switch self {
        case .noConnection:
            return "네트워크 연결을 확인해주세요."
        case .timeout:
            return "요청 시간이 초과되었습니다. 다시 시도해주세요."
        case .serverError(let statusCode):
            return "서버 오류가 발생했습니다. (코드: \(statusCode))"
        case .invalidResponse:
            return "잘못된 응답을 받았습니다."
        case .decodingFailed:
            return "데이터 처리 중 오류가 발생했습니다."
        }
    }
}

// MARK: - BusinessError

public enum BusinessError: Equatable, Sendable {
    case videoTooLong
    case videoTooLarge
    case invalidVideoFormat
    case studyFull
    case unauthorized
    case invalidInviteCode
    case alreadyJoined
    case notFound

    public var userMessage: String {
        switch self {
        case .videoTooLong:
            return "영상 길이가 최대 허용 시간을 초과했습니다."
        case .videoTooLarge:
            return "영상 파일 크기가 너무 큽니다. 더 짧은 영상을 선택해주세요."
        case .invalidVideoFormat:
            return "지원하지 않는 영상 형식입니다."
        case .studyFull:
            return "스터디 인원이 가득 찼습니다."
        case .unauthorized:
            return "권한이 없습니다. 다시 로그인해주세요."
        case .invalidInviteCode:
            return "유효하지 않은 초대 코드입니다."
        case .alreadyJoined:
            return "이미 참여 중인 스터디입니다."
        case .notFound:
            return "요청한 항목을 찾을 수 없습니다."
        }
    }
}
