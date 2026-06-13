import AppKit
import Foundation

struct AboutInfo: Hashable {
    let appName: String
    let version: String
    let buildNumber: String
    let homepageURL: URL
    let privacyPolicyURL: URL
    let releasesURL: URL
    let thirdPartyLicensesURL: URL
    let feedbackEmail: String
    let copyright: String
}

struct FeedbackContext: Hashable {
    let appVersion: String
    let buildNumber: String
    let macOSVersion: String
    let errorSummary: String?
    let userDescription: String
}

protocol AboutInfoProviderProtocol {
    var info: AboutInfo { get }
}

protocol FeedbackServiceProtocol {
    func makeFeedbackEmail(context: FeedbackContext) throws -> URL
}

protocol UpdateCheckServiceProtocol {
    func openDownloadPage()
}

protocol ReleaseURLOpening {
    @discardableResult
    func open(_ url: URL) -> Bool
}

extension NSWorkspace: ReleaseURLOpening {}

struct BundleAboutInfoProvider: AboutInfoProviderProtocol {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var info: AboutInfo {
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let year = Calendar.current.component(.year, from: Date())

        return AboutInfo(
            appName: displayName ?? bundleName ?? "Mac Super Assistant",
            version: version ?? "0.1.0",
            buildNumber: build ?? "1",
            homepageURL: ReleaseLinks.homepageURL,
            privacyPolicyURL: ReleaseLinks.privacyPolicyURL,
            releasesURL: ReleaseLinks.releasesURL,
            thirdPartyLicensesURL: ReleaseLinks.thirdPartyLicensesURL,
            feedbackEmail: ReleaseLinks.feedbackEmail,
            copyright: "© \(year) Mac Super Assistant. All rights reserved."
        )
    }
}

enum ReleaseLinks {
    static let homepageURL = URL(string: "https://github.com/abyss/assistant")!
    static let privacyPolicyURL = URL(string: "https://github.com/abyss/assistant/blob/main/PRIVACY.md")!
    static let releasesURL = URL(string: "https://github.com/abyss/assistant/releases")!
    static let thirdPartyLicensesURL = URL(string: "https://github.com/abyss/assistant/blob/main/THIRD_PARTY_NOTICES.md")!
    static let feedbackEmail = "feedback@assistant.app"
}

struct FeedbackEmailService: FeedbackServiceProtocol {
    private let recipient: String

    init(recipient: String = ReleaseLinks.feedbackEmail) {
        self.recipient = recipient
    }

    func makeFeedbackEmail(context: FeedbackContext) throws -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Mac Super Assistant Feedback"),
            URLQueryItem(name: "body", value: emailBody(context: context))
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    private func emailBody(context: FeedbackContext) -> String {
        let summary = context.errorSummary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? context.errorSummary!
            : "No error summary provided"
        let description = context.userDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Please describe what happened here."
            : context.userDescription

        return """
        Please describe the issue or suggestion:
        \(description)

        Diagnostic information included by your action:
        - App version: \(context.appVersion) (\(context.buildNumber))
        - macOS version: \(context.macOSVersion)
        - Error summary: \(summary)

        Privacy note: this email is sent only after you confirm it in your mail app. Mac Super Assistant does not attach clipboard history, screenshots, files, or automatic crash logs.
        """
    }
}

struct WebUpdateCheckService: UpdateCheckServiceProtocol {
    private let releasesURL: URL
    private let opener: ReleaseURLOpening

    init(releasesURL: URL = ReleaseLinks.releasesURL, opener: ReleaseURLOpening = NSWorkspace.shared) {
        self.releasesURL = releasesURL
        self.opener = opener
    }

    func openDownloadPage() {
        opener.open(releasesURL)
    }
}
