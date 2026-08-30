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
    case quickFeedbackVideoTooLong
    case videoTooLarge
    case invalidVideoFormat
    case studyFull
    case unauthorized
    case invalidInviteCode
    case alreadyJoined
    case alreadyRequested
    case requestAlreadyHandled
    case requestNotFound
    case notFound
    case maxOwnedStudiesReached
    case maxJoinedStudiesReached
    case ownerMustTransferBeforeLeave
    case nameAlreadyTaken
    case activeQuickFeedbackExists
    case quickFeedbackUnavailable
    case quickFeedbackExpired

    public var userMessage: String {
        switch self {
        case .videoTooLong:
            return "영상은 최대 \(Int(AppConstants.maxVideoDurationSeconds) / 60)분까지 업로드할 수 있습니다."
        case .quickFeedbackVideoTooLong:
            return "빠른 피드백 영상은 최대 \(Int(AppConstants.maxQuickFeedbackVideoDurationSeconds))초까지 업로드할 수 있습니다."
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
        case .alreadyRequested:
            return "이미 참여 요청을 보낸 스터디입니다."
        case .requestAlreadyHandled:
            return "이미 처리된 요청입니다."
        case .requestNotFound:
            return "참여 요청을 찾을 수 없습니다."
        case .notFound:
            return "요청한 항목을 찾을 수 없습니다."
        case .maxOwnedStudiesReached:
            return "스터디는 최대 \(AppConstants.maxOwnedStudies)개까지 만들 수 있습니다."
        case .maxJoinedStudiesReached:
            return "참여할 수 있는 스터디는 최대 \(AppConstants.maxJoinedStudies)개입니다."
        case .ownerMustTransferBeforeLeave:
            return "팀장은 다른 멤버에게 팀장을 위임한 후 탈퇴할 수 있습니다."
        case .nameAlreadyTaken:
            return "이미 사용 중인 이름입니다. 다른 이름을 입력해주세요."
        case .activeQuickFeedbackExists:
            return "진행 중인 빠른 피드백 요청을 먼저 완료해주세요."
        case .quickFeedbackUnavailable:
            return "이미 배정되었거나 참여할 수 없는 요청입니다. 다른 영상을 선택해주세요."
        case .quickFeedbackExpired:
            return "피드백 작성 시간이 만료되었습니다."
        }
    }
}
