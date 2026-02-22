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

    /// 초대 코드로 스터디에 참여한다.
    func joinStudy(inviteCode: String) async throws -> Study

    /// 스터디를 탈퇴한다.
    func leaveStudy(id: UUID) async throws

    /// 스터디를 삭제한다 (소유자만).
    func deleteStudy(id: UUID) async throws

    /// 스터디 멤버를 제거한다 (소유자만).
    func removeMember(studyID: UUID, userID: UUID) async throws

    /// 초대 코드 정보를 조회한다.
    func fetchInviteCodeInfo(code: String) async throws -> InviteCode
}
