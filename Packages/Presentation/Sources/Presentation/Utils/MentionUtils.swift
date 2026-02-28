import Foundation
import Domain

/// @멘션 파싱 관련 유틸리티
public enum MentionUtils {
    /// 텍스트 내 @멘션을 파싱하여 실제 멤버와 매칭된 userID Set을 반환
    public static func syncMentionedUserIDs(
        content: String,
        members: [StudyMember]
    ) -> Set<UUID> {
        guard let regex = try? NSRegularExpression(pattern: "@(\\S+)") else { return [] }
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

        var ids = Set<UUID>()
        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let nameRange = match.range(at: 1)
            let name = nsContent.substring(with: nameRange)

            if name == "전체" {
                for member in members {
                    ids.insert(member.userID)
                }
            } else if let member = members.first(where: { $0.userName == name }) {
                ids.insert(member.userID)
            }
        }
        return ids
    }
}
