import Foundation

public struct CreateStudyRequest: Equatable, Sendable {
    public let name: String
    public let description: String
    public let maxMembers: Int

    public init(name: String, description: String, maxMembers: Int) {
        self.name = name
        self.description = description
        self.maxMembers = maxMembers
    }
}

public protocol StudyRepository: Sendable {
    /// 사용자가 참여 중인 스터디 목록을 조회한다.
    func fetchMyStudies() async throws -> [Study]

    /// 스터디 상세 정보를 조회한다.
    func fetchStudy(id: UUID) async throws -> Study

    /// 새 스터디를 생성한다.
    func createStudy(_ request: CreateStudyRequest) async throws -> Study

    /// 초대 코드로 스터디 참여를 요청한다.
    func requestJoinStudy(inviteCode: String) async throws -> JoinRequest

    /// 스터디의 대기 중인 참여 요청 목록을 조회한다 (소유자만).
    func fetchPendingRequests(studyID: UUID) async throws -> [JoinRequest]

    /// 참여 요청을 승인한다 (소유자만).
    func approveJoinRequest(requestID: UUID) async throws

    /// 참여 요청을 거절한다 (소유자만).
    func rejectJoinRequest(requestID: UUID) async throws

    /// 참여 요청을 취소한다 (요청자 본인만).
    func cancelJoinRequest(requestID: UUID) async throws

    /// 스터디를 탈퇴한다.
    func leaveStudy(id: UUID) async throws

    /// 스터디를 삭제한다 (소유자만).
    func deleteStudy(id: UUID) async throws

    /// 스터디 멤버를 제거한다 (소유자만).
    func removeMember(studyID: UUID, userID: UUID) async throws

    /// 스터디 방장을 다른 멤버에게 위임한다 (소유자만).
    func transferOwnership(studyID: UUID, newOwnerID: UUID) async throws

    /// 초대 코드 정보를 조회한다.

    /// 스터디 공지사항을 업데이트한다 (소유자만).
    func updateNotice(studyID: UUID, notice: String?) async throws

    func fetchInviteCodeInfo(code: String) async throws -> InviteCode

    /// 스터디 멤버의 활동 통계를 조회한다.
    func fetchMemberStats(studyID: UUID, userID: UUID) async throws -> MemberStats
}
