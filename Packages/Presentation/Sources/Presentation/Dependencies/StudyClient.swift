import Foundation
import ComposableArchitecture
import Domain

public struct StudyClient: Sendable {
    public var fetchMyStudies: @Sendable () async throws -> [Study]
    public var fetchStudy: @Sendable (UUID) async throws -> Study
    public var createStudy: @Sendable (CreateStudyRequest) async throws -> Study
    public var joinStudy: @Sendable (String) async throws -> Study
    public var leaveStudy: @Sendable (UUID) async throws -> Void
    public var deleteStudy: @Sendable (UUID) async throws -> Void
    public var removeMember: @Sendable (UUID, UUID) async throws -> Void
    public var fetchInviteCodeInfo: @Sendable (String) async throws -> InviteCode
    public var updateNotice: @Sendable (UUID, String?) async throws -> Void

    public init(
        fetchMyStudies: @escaping @Sendable () async throws -> [Study],
        fetchStudy: @escaping @Sendable (UUID) async throws -> Study,
        createStudy: @escaping @Sendable (CreateStudyRequest) async throws -> Study,
        joinStudy: @escaping @Sendable (String) async throws -> Study,
        leaveStudy: @escaping @Sendable (UUID) async throws -> Void,
        deleteStudy: @escaping @Sendable (UUID) async throws -> Void,
        removeMember: @escaping @Sendable (UUID, UUID) async throws -> Void,
        fetchInviteCodeInfo: @escaping @Sendable (String) async throws -> InviteCode,
        updateNotice: @escaping @Sendable (UUID, String?) async throws -> Void
    ) {
        self.fetchMyStudies = fetchMyStudies
        self.fetchStudy = fetchStudy
        self.createStudy = createStudy
        self.joinStudy = joinStudy
        self.leaveStudy = leaveStudy
        self.deleteStudy = deleteStudy
        self.removeMember = removeMember
        self.fetchInviteCodeInfo = fetchInviteCodeInfo
        self.updateNotice = updateNotice
    }
}

extension StudyClient: TestDependencyKey {
    public static let testValue = StudyClient(
        fetchMyStudies: unimplemented("\(Self.self).fetchMyStudies"),
        fetchStudy: unimplemented("\(Self.self).fetchStudy"),
        createStudy: unimplemented("\(Self.self).createStudy"),
        joinStudy: unimplemented("\(Self.self).joinStudy"),
        leaveStudy: unimplemented("\(Self.self).leaveStudy"),
        deleteStudy: unimplemented("\(Self.self).deleteStudy"),
        removeMember: unimplemented("\(Self.self).removeMember"),
        fetchInviteCodeInfo: unimplemented("\(Self.self).fetchInviteCodeInfo"),
        updateNotice: unimplemented("\(Self.self).updateNotice")
    )
}

extension DependencyValues {
    public var studyClient: StudyClient {
        get { self[StudyClient.self] }
        set { self[StudyClient.self] = newValue }
    }
}
