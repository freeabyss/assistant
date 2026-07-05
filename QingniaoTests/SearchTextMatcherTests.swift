import XCTest
@testable import Qingniao

final class SearchTextMatcherTests: XCTestCase {
    func testPinyinPrefixMatchesChineseCandidate() {
        let candidate = SearchTextCandidate(text: "微信", aliases: [])

        XCTAssertEqual(SearchTextMatcher.match(query: "weix", candidate: candidate), .pinyinPrefix)
    }

    func testInitialsMatchChineseCandidate() {
        let candidate = SearchTextCandidate(text: "快捷键设置", aliases: [])

        XCTAssertEqual(SearchTextMatcher.match(query: "kjj", candidate: candidate), .initials)
    }

    func testEnglishAliasMatchesChineseCandidate() {
        let candidate = SearchTextCandidate(text: "权限", aliases: ["Permissions", "privacy"])

        XCTAssertEqual(SearchTextMatcher.match(query: "privacy", candidate: candidate), .alias)
    }

    func testChineseAliasPinyinMatches() {
        let candidate = SearchTextCandidate(text: "Settings", aliases: ["剪贴板历史"])

        XCTAssertEqual(SearchTextMatcher.match(query: "jtb", candidate: candidate), .initials)
    }
}
