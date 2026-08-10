import Foundation
import ComposableArchitecture
import Domain

public struct StudyClient: Sendable {
    public var fetchMyStudies: @Sendable () async throws -> [Study]
    public var fetchStudy: @Sendable (UUID) async throws -> Study
    public var createStudy: @Sendable (CreateStudyRequest) async throws -> Study
    public var requestJoinStudy: @Sendable (String) async throws -> JoinRequest
    public var leaveStudy: @Sendable (UUID) async throws -> Void
    public var deleteStudy: @Sendable (UUID) async throws -> Void
    public var removeMember: @Sendable (UUID, UUID) async throws -> Void
    public var transferOwnership: @Sendable (UUID, UUID) async throws -> Void
    public var fetchInviteCodeInfo: @Sendable (String) async throws -> InviteCode
    public var updateNotice: @Sendable (UUID, String?) async throws -> Void
    public var fetchPendingRequests: @Sendable (UUID) async throws -> [JoinRequest]
    public var approveJoinRequest: @Sendable (UUID) async throws -> Void
    public var rejectJoinRequest: @Sendable (UUID) async throws -> Void
    public var cancelJoinRequest: @Sendable (UUID) async throws -> Void
    public var fetchMemberStats: @Sendable (UUID, UUID) async throws -> MemberStats

    public init(
        fetchMyStudies: @escaping @Sendable () async throws -> [Study],
        fetchStudy: @escaping @Sendable (UUID) async throws -> Study,
        createStudy: @escaping @Sendable (CreateStudyRequest) async throws -> Study,
        requestJoinStudy: @escaping @Sendable (String) async throws -> JoinRequest,
        leaveStudy: @escaping @Sendable (UUID) async throws -> Void,
        deleteStudy: @escaping @Sendable (UUID) async throws -> Void,
        removeMember: @escaping @Sendable (UUID, UUID) async throws -> Void,
        transferOwnership: @escaping @Sendable (UUID, UUID) async throws -> Void,
        fetchInviteCodeInfo: @escaping @Sendable (String) async throws -> InviteCode,
        updateNotice: @escaping @Sendable (UUID, String?) async throws -> Void,
        fetchPendingRequests: @escaping @Sendable (UUID) async throws -> [JoinRequest],
        approveJoinRequest: @escaping @Sendable (UUID) async throws -> Void,
        rejectJoinRequest: @escaping @Sendable (UUID) async throws -> Void,
        cancelJoinRequest: @escaping @Sendable (UUID) async throws -> Void,
        fetchMemberStats: @escaping @Sendable (UUID, UUID) async throws -> MemberStats
    ) {
        self.fetchMyStudies = fetchMyStudies
        self.fetchStudy = fetchStudy
        self.createStudy = createStudy
        self.requestJoinStudy = requestJoinStudy
        self.leaveStudy = leaveStudy
        self.deleteStudy = deleteStudy
        self.removeMember = removeMember
        self.transferOwnership = transferOwnership
        self.fetchInviteCodeInfo = fetchInviteCodeInfo
        self.updateNotice = updateNotice
        self.fetchPendingRequests = fetchPendingRequests
        self.approveJoinRequest = approveJoinRequest
        self.rejectJoinRequest = rejectJoinRequest
        self.cancelJoinRequest = cancelJoinRequest
        self.fetchMemberStats = fetchMemberStats
    }
}

extension StudyClient: TestDependencyKey {
    public static let testValue = StudyClient(
        fetchMyStudies: unimplemented("\(Self.self).fetchMyStudies"),
        fetchStudy: unimplemented("\(Self.self).fetchStudy"),
        createStudy: unimplemented("\(Self.self).createStudy"),
        requestJoinStudy: unimplemented("\(Self.self).requestJoinStudy"),
        leaveStudy: unimplemented("\(Self.self).leaveStudy"),
        deleteStudy: unimplemented("\(Self.self).deleteStudy"),
        removeMember: unimplemented("\(Self.self).removeMember"),
        transferOwnership: unimplemented("\(Self.self).transferOwnership"),
        fetchInviteCodeInfo: unimplemented("\(Self.self).fetchInviteCodeInfo"),
        updateNotice: unimplemented("\(Self.self).updateNotice"),
        fetchPendingRequests: unimplemented("\(Self.self).fetchPendingRequests"),
        approveJoinRequest: unimplemented("\(Self.self).approveJoinRequest"),
        rejectJoinRequest: unimplemented("\(Self.self).rejectJoinRequest"),
        cancelJoinRequest: unimplemented("\(Self.self).cancelJoinRequest"),
        fetchMemberStats: unimplemented("\(Self.self).fetchMemberStats")
    )
}

extension DependencyValues {
    public var studyClient: StudyClient {
        get { self[StudyClient.self] }
        set { self[StudyClient.self] = newValue }
    }
}
