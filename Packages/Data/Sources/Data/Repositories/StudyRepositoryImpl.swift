import Foundation
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
        let userID = try await client.auth.session.user.id
        let inviteCode = generateInviteCode()

        struct InsertStudy: Codable {
            let name: String
            let description: String
            let ownerID: UUID
            let inviteCode: String
            let maxMembers: Int
            enum CodingKeys: String, CodingKey {
                case name, description
                case ownerID = "owner_id"
                case inviteCode = "invite_code"
                case maxMembers = "max_members"
            }
        }

        let dto: StudyDTO = try await client.from(SupabaseConfig.Table.studies)
            .insert(InsertStudy(
                name: request.name,
                description: request.description,
                ownerID: userID,
                inviteCode: inviteCode,
                maxMembers: request.maxMembers
            ))
            .select()
            .single()
            .execute()
            .value

        // 소유자를 멤버로 추가
        struct InsertMember: Codable {
            let studyID: UUID
            let userID: UUID
            let role: String
            enum CodingKeys: String, CodingKey { case studyID = "study_id"; case userID = "user_id"; case role }
        }
        try await client.from(SupabaseConfig.Table.studyMembers)
            .insert(InsertMember(studyID: dto.id, userID: userID, role: "owner"))
            .execute()

        return try await fetchStudy(id: dto.id)
    }

    public func joinStudy(inviteCode: String) async throws -> Study {
        let userID = try await client.auth.session.user.id

        let studyDTO: StudyDTO = try await client.from(SupabaseConfig.Table.studies)
            .select()
            .eq("invite_code", value: inviteCode)
            .single()
            .execute()
            .value

        struct InsertMember: Codable {
            let studyID: UUID
            let userID: UUID
            let role: String
            enum CodingKeys: String, CodingKey { case studyID = "study_id"; case userID = "user_id"; case role }
        }

        try await client.from(SupabaseConfig.Table.studyMembers)
            .insert(InsertMember(studyID: studyDTO.id, userID: userID, role: "member"))
            .execute()

        return try await fetchStudy(id: studyDTO.id)
    }

    public func leaveStudy(id: UUID) async throws {
        let userID = try await client.auth.session.user.id
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
        try await client.from(SupabaseConfig.Table.studyMembers)
            .delete()
            .eq("study_id", value: studyID)
            .eq("user_id", value: userID)
            .execute()
    }

    public func fetchInviteCodeInfo(code: String) async throws -> InviteCode {
        let dto: StudyDTO = try await client.from(SupabaseConfig.Table.studies)
            .select()
            .eq("invite_code", value: code)
            .single()
            .execute()
            .value

        return InviteCode(
            code: dto.inviteCode,
            studyID: dto.id,
            studyName: dto.name,
            createdAt: Date()
        )
    }

    // MARK: - Private

    private func generateInviteCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}
