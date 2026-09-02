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
    func 공유한_초대_링크를_유니버설_링크로_되돌려_파싱() {
        // 공유 → 유니버설 링크 탭 → 앱 라운드트립. 상수를 바꿔도 양쪽이 함께 움직여야 한다
        let url = DeepLinkParser.inviteShareURL(code: "ABC123")

        #expect(url.flatMap(DeepLinkParser.parse(url:)) == .inviteCode("ABC123"))
    }

    @Test
    func 같은_호스트라도_다른_경로면_nil() {
        let url = URL(string: "https://devk4nt.github.io/flymate-site/privacy.html?code=ABC123")!

        #expect(DeepLinkParser.parse(url: url) == nil)
    }

    @Test
    func 다른_호스트의_같은_경로면_nil() {
        let url = URL(string: "https://evil.example.com/flymate-site/invite.html?code=ABC123")!

        #expect(DeepLinkParser.parse(url: url) == nil)
    }

    @Test
    func 공유용_초대_링크는_랜딩_페이지_https_URL() {
        let url = DeepLinkParser.inviteShareURL(code: "ABC123")

        #expect(url?.absoluteString == "https://devk4nt.github.io/flymate-site/invite.html?code=ABC123")
    }

    @Test
    func 공유용_초대_링크는_코드를_퍼센트_인코딩() {
        // 코드는 서버가 만들어 주는 값 — URL 경계에서 그대로 신뢰하지 않는다
        let url = DeepLinkParser.inviteShareURL(code: "A B&code=X")

        #expect(url?.absoluteString.hasSuffix("?code=A%20B%26code%3DX") == true)
        #expect(url?.host == "devk4nt.github.io")
    }

    @Test
    func 다른_쿼리_파라미터는_무시() {
        let url = URL(string: "flymate://invite?code=ABC123&extra=value")!
        let result = DeepLinkParser.parse(url: url)

        #expect(result == .inviteCode("ABC123"))
    }
}
