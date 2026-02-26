import Foundation
import Core
import Domain
import Supabase

public struct StudyRepositoryImpl: StudyRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func fetchMyStudies() async throws -> [Study] {
        let userID = try await client.auth.session.user.id

        // 사용자가 멤버인 스터디 ID 목록 조회
        struct MemberRow: Codable { let studyID: UUID; enum CodingKeys: String, CodingKey { case studyID = "study_id" } }
        let memberRows: [MemberRow] = try await client.from(SupabaseConfig.Table.studyMembers)
            .select("study_id")
            .eq("user_id", value: userID)
            .execute()
            .value

        let studyIDs = memberRows.map(\.studyID)
        guard !studyIDs.isEmpty else { return [] }

        // 스터디 목록 조회
        let studies: [StudyDTO] = try await client.from(SupabaseConfig.Table.studies)
            .select()
            .in("id", values: studyIDs)
            .order("created_at", ascending: false)
            .execute()
            .value

        // 각 스터디의 멤버 조회
        var result: [Study] = []
        for study in studies {
            let members: [StudyMemberDTO] = try await client.from(SupabaseConfig.Table.studyMembers)
                .select()
                .eq("study_id", value: study.id)
                .execute()
                .value
            result.append(DTOMapper.toDomain(study, members: members))
        }
        return result
    }

    public func fetchStudy(id: UUID) async throws -> Study {
        let dto: StudyDTO = try await client.from(SupabaseConfig.Table.studies)
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value

        let members: [StudyMemberDTO] = try await client.from(SupabaseConfig.Table.studyMembers)
            .select()
            .eq("study_id", value: id)
            .execute()
            .value

        return DTOMapper.toDomain(dto, members: members)
    }

    public func createStudy(_ request: CreateStudyRequest) async throws -> Study {
        let inviteCode = generateInviteCode()

        struct CreateStudyParams: Encodable {
            let p_name: String
            let p_description: String
            let p_max_members: Int
            let p_invite_code: String
        }

        do {
            let studyID: UUID = try await client.rpc(
                "create_study_with_limits",
                params: CreateStudyParams(
                    p_name: request.name,
                    p_description: request.description,
                    p_max_members: request.maxMembers,
                    p_invite_code: inviteCode
                )
            )
            .single()
            .execute()
            .value

            return try await fetchStudy(id: studyID)
        } catch {
            throw mapRPCError(error)
        }
    }

    public func requestJoinStudy(inviteCode: String) async throws -> JoinRequest {
        do {
            let dto: JoinRequestDTO = try await client.rpc(
                "request_join_study",
                params: ["p_invite_code": inviteCode]
            )
            .single()
            .execute()
            .value

            return DTOMapper.toDomain(dto)
        } catch {
            throw mapRPCError(error)
        }
    }

    public func fetchPendingRequests(studyID: UUID) async throws -> [JoinRequest] {
        let dtos: [JoinRequestDTO] = try await client.from(SupabaseConfig.Table.joinRequests)
            .select()
            .eq("study_id", value: studyID)
            .eq("status", value: "pending")
            .order("created_at", ascending: true)
            .execute()
            .value

        return dtos.map(DTOMapper.toDomain)
    }

    public func approveJoinRequest(requestID: UUID) async throws {
        do {
            try await client.rpc(
                "approve_join_request",
                params: ["p_request_id": requestID]
            ).execute()
        } catch {
            throw mapRPCError(error)
        }
    }

    public func rejectJoinRequest(requestID: UUID) async throws {
        do {
            try await client.rpc(
                "reject_join_request",
                params: ["p_request_id": requestID]
            ).execute()
        } catch {
            throw mapRPCError(error)
        }
    }

    public func cancelJoinRequest(requestID: UUID) async throws {
        try await client.from(SupabaseConfig.Table.joinRequests)
            .delete()
            .eq("id", value: requestID)
            .execute()
    }

    public func leaveStudy(id: UUID) async throws {
        let userID = try await client.auth.session.user.id

        // 콘텐츠 익명화 (멤버 삭제 전에 실행)
        try await client.rpc(
            "anonymize_member_in_study",
            params: ["p_study_id": id, "p_user_id": userID]
        ).execute()

        try await client.from(SupabaseConfig.Table.studyMembers)
            .delete()
            .eq("study_id", value: id)
            .eq("user_id", value: userID)
            .execute()
    }

    public func deleteStudy(id: UUID) async throws {
        try await client.from(SupabaseConfig.Table.studies)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    public func removeMember(studyID: UUID, userID: UUID) async throws {
        // 콘텐츠 익명화 (멤버 삭제 전에 실행)
        try await client.rpc(
            "anonymize_member_in_study",
            params: ["p_study_id": studyID, "p_user_id": userID]
        ).execute()

        try await client.from(SupabaseConfig.Table.studyMembers)
            .delete()
            .eq("study_id", value: studyID)
            .eq("user_id", value: userID)
            .execute()
    }

    public func updateNotice(studyID: UUID, notice: String?) async throws {
        struct UpdateNotice: Codable {
            let notice: String?
            let noticeUpdatedAt: String?
            enum CodingKeys: String, CodingKey {
                case notice
                case noticeUpdatedAt = "notice_updated_at"
            }
        }

        let now = notice != nil ? ISO8601DateFormatter().string(from: Date()) : nil
        try await client.from(SupabaseConfig.Table.studies)
            .update(UpdateNotice(notice: notice, noticeUpdatedAt: now))
            .eq("id", value: studyID)
            .execute()
    }

    public func fetchInviteCodeInfo(code: String) async throws -> InviteCode {
        do {
            let response: InviteCodeResponse = try await client.rpc(
                "get_study_by_invite_code",
                params: ["p_invite_code": code]
            )
            .single()
            .execute()
            .value

            return InviteCode(
                code: response.code,
                studyID: response.studyID,
                studyName: response.studyName,
                createdAt: response.createdAt,
                expiresAt: response.expiresAt,
                isActive: response.isActive
            )
        } catch {
            throw mapRPCError(error)
        }
    }

    // MARK: - Private

    private func generateInviteCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }

    private func mapRPCError(_ error: Error) -> Error {
        let message = error.localizedDescription
        if message.contains("INVALID_INVITE_CODE") {
            return AppError.business(.invalidInviteCode)
        } else if message.contains("INVITE_CODE_EXPIRED") {
            return AppError.business(.inviteCodeExpired)
        } else if message.contains("INVITE_CODE_INACTIVE") {
            return AppError.business(.inviteCodeInactive)
        } else if message.contains("ALREADY_REQUESTED") {
            return AppError.business(.alreadyRequested)
        } else if message.contains("REQUEST_NOT_FOUND") {
            return AppError.business(.requestNotFound)
        } else if message.contains("REQUEST_ALREADY_HANDLED") {
            return AppError.business(.requestAlreadyHandled)
        } else if message.contains("ALREADY_MEMBER") {
            return AppError.business(.alreadyJoined)
        } else if message.contains("STUDY_FULL") {
            return AppError.business(.studyFull)
        } else if message.contains("MAX_OWNED_STUDIES_REACHED") {
            return AppError.business(.maxOwnedStudiesReached)
        } else if message.contains("MAX_JOINED_STUDIES_REACHED") {
            return AppError.business(.maxJoinedStudiesReached)
        } else if message.contains("UNAUTHORIZED") {
            return AppError.business(.unauthorized)
        }
        return AppError.unexpected(message)
    }
}

// MARK: - RPC Response DTOs

private struct InviteCodeResponse: Codable, Sendable {
    let code: String
    let studyID: UUID
    let studyName: String
    let createdAt: Date
    let expiresAt: Date
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case code
        case studyID = "study_id"
        case studyName = "study_name"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case isActive = "is_active"
    }
}
