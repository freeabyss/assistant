import XCTest
@testable import SnapVault

final class ReleaseInfoServiceTests: XCTestCase {
    func testFeedbackEmailIncludesVersionSystemSummaryAndUserDescription() throws {
        let service = FeedbackEmailService(recipient: "support@example.com")
        let url = try service.makeFeedbackEmail(context: FeedbackContext(
            appVersion: "0.1.0",
            buildNumber: "7",
            macOSVersion: "Version 15.0",
            errorSummary: "Screenshot failed",
            userDescription: "It happened after pressing the shortcut."
        ))

        let absolute = url.absoluteString.removingPercentEncoding ?? url.absoluteString
        XCTAssertTrue(absolute.hasPrefix("mailto:support@example.com?"))
        XCTAssertTrue(absolute.contains("Mac Super Assistant Feedback"))
        XCTAssertTrue(absolute.contains("App version: 0.1.0 (7)"))
        XCTAssertTrue(absolute.contains("macOS version: Version 15.0"))
        XCTAssertTrue(absolute.contains("Error summary: Screenshot failed"))
        XCTAssertTrue(absolute.contains("It happened after pressing the shortcut."))
        XCTAssertTrue(absolute.contains("does not attach clipboard history, screenshots, files, or automatic crash logs"))
    }

    func testUpdateCheckServiceOpensReleasesURLOnly() {
        let opener = RecordingURLOpener()
        let releasesURL = URL(string: "https://example.com/releases")!
        let service = WebUpdateCheckService(releasesURL: releasesURL, opener: opener)

        service.openDownloadPage()

        XCTAssertEqual(opener.openedURLs, [releasesURL])
    }
}

private final class RecordingURLOpener: ReleaseURLOpening {
    private(set) var openedURLs: [URL] = []

    func open(_ url: URL) -> Bool {
        openedURLs.append(url)
        return true
    }
}
