import Testing
import Foundation

@testable import Presentation

struct DeepLinkParserTests {
    @Test
    func 초대코드_딥링크_파싱_성공() {
        let url = URL(string: "flymate://invite?code=ABC123")!
        let result = DeepLinkParser.parse(url: url)

        #expect(result == .inviteCode("ABC123"))
    }

    @Test
    func 코드_파라미터_없으면_nil() {
        let url = URL(string: "flymate://invite")!
        let result = DeepLinkParser.parse(url: url)

        #expect(result == nil)
    }

    @Test
    func 빈_코드_값이면_nil() {
        let url = URL(string: "flymate://invite?code=")!
        let result = DeepLinkParser.parse(url: url)

        #expect(result == nil)
    }

    @Test
    func 다른_스킴이면_nil() {
        let url = URL(string: "https://invite?code=ABC123")!
        let result = DeepLinkParser.parse(url: url)

        #expect(result == nil)
    }

    @Test
    func 알_수_없는_호스트면_nil() {
        let url = URL(string: "flymate://unknown?code=ABC123")!
        let result = DeepLinkParser.parse(url: url)

        #expect(result == nil)
    }

    @Test
    func 다른_쿼리_파라미터는_무시() {
        let url = URL(string: "flymate://invite?code=ABC123&extra=value")!
        let result = DeepLinkParser.parse(url: url)

        #expect(result == .inviteCode("ABC123"))
    }
}
