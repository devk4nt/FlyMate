import Foundation
import Core
import Domain
import Supabase

public struct StudyRepositoryImpl: StudyRepository {
    private let client: SupabaseClient
    private let storageService: StorageService

    public init(client: SupabaseClient) {
        self.client = client
        self.storageService = StorageService(client: client)
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

    public func fetchMyJoinRequests() async throws -> [JoinRequest] {
        // RLS는 방장에게 자기 스터디의 신청도 보여주므로 내 것만 명시적으로 필터
        let userID = try await client.auth.session.user.id
        let dtos: [JoinRequestDTO] = try await client.from(SupabaseConfig.Table.joinRequests)
            .select()
            .eq("user_id", value: userID)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
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

        do {
            try await removeMemberContent(studyID: id, userID: userID)

            // 방장 탈퇴는 서버 트리거가 판정: 혼자면 스터디 삭제, 멤버가 있으면 OWNER_MUST_TRANSFER_BEFORE_LEAVE 거부
            try await client.from(SupabaseConfig.Table.studyMembers)
                .delete()
                .eq("study_id", value: id)
                .eq("user_id", value: userID)
                .execute()
        } catch {
            throw mapRPCError(error)
        }
    }

    public func deleteStudy(id: UUID) async throws {
        try await client.from(SupabaseConfig.Table.studies)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    public func removeMember(studyID: UUID, userID: UUID) async throws {
        try await removeMemberContent(studyID: studyID, userID: userID)

        try await client.from(SupabaseConfig.Table.studyMembers)
            .delete()
            .eq("study_id", value: studyID)
            .eq("user_id", value: userID)
            .execute()
    }

    public func transferOwnership(studyID: UUID, newOwnerID: UUID) async throws {
        do {
            try await client.rpc(
                "transfer_study_ownership",
                params: ["p_study_id": studyID, "p_new_owner_id": newOwnerID]
            ).execute()
        } catch {
            throw mapRPCError(error)
        }
    }

    /// 탈퇴/강퇴 멤버의 영상·피드백·댓글 삭제 및 멘션 치환 후,
    /// 삭제된 영상의 Storage 파일 정리 (멤버 삭제 전에 실행)
    private func removeMemberContent(studyID: UUID, userID: UUID) async throws {
        let deletedVideoIDs: [UUID] = try await client.rpc(
            "remove_member_content_in_study",
            params: ["p_study_id": studyID, "p_user_id": userID]
        ).execute().value

        await storageService.deleteVideoFiles(studyID: studyID, videoIDs: deletedVideoIDs)
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

    public func fetchMemberStats(studyID: UUID, userID: UUID) async throws -> MemberStats {
        do {
            let response: MemberStatsResponse = try await client.rpc(
                "get_member_stats",
                params: ["p_study_id": studyID, "p_user_id": userID]
            )
            .single()
            .execute()
            .value

            return MemberStats(
                userID: response.userID,
                studyID: response.studyID,
                feedbackGivenCount: response.feedbackGivenCount,
                feedbackReceivedCount: response.feedbackReceivedCount,
                videosUploadedCount: response.videosUploadedCount,
                joinedAt: response.joinedAt
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
        } else if message.contains("OWNER_MUST_TRANSFER_BEFORE_LEAVE") {
            return AppError.business(.ownerMustTransferBeforeLeave)
        } else if message.contains("UNAUTHORIZED") {
            return AppError.business(.unauthorized)
        }
        return AppError.unexpected(message)
    }
}

// MARK: - RPC Response DTOs

private struct MemberStatsResponse: Codable, Sendable {
    let userID: UUID
    let studyID: UUID
    let feedbackGivenCount: Int
    let feedbackReceivedCount: Int
    let videosUploadedCount: Int
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case studyID = "study_id"
        case feedbackGivenCount = "feedback_given_count"
        case feedbackReceivedCount = "feedback_received_count"
        case videosUploadedCount = "videos_uploaded_count"
        case joinedAt = "joined_at"
    }
}
