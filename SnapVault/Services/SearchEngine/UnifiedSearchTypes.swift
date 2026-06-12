import Foundation
import AppKit

// MARK: - Search Result Type

/// Type of search result source.
enum SearchResultType: String, Codable, CaseIterable {
    case application
    case file
    case clipboard
    case systemCommand
    case calculator
    case unitConversion

    var displayName: String {
        switch self {
        case .application: return L10n.localized("search.type.applications")
        case .file: return L10n.localized("search.type.files")
        case .clipboard: return L10n.localized("search.type.clipboard")
        case .systemCommand: return L10n.localized("search.type.system")
        case .calculator: return L10n.localized("search.type.calculator")
        case .unitConversion: return L10n.localized("search.type.convert")
        }
    }

    var iconName: String {
        switch self {
        case .application: return "app.fill"
        case .file: return "doc.fill"
        case .clipboard: return "clipboard.fill"
        case .systemCommand: return "gearshape"
        case .calculator: return "function"
        case .unitConversion: return "arrow.left.arrow.right"
        }
    }
}

// MARK: - Unified Search Result

/// A unified search result from any source.
struct UnifiedSearchResult: Identifiable {
    let id: String                // Unique identifier (sourceType:originalID)
    let title: String             // Primary title
    let subtitle: String?         // Secondary info
    let icon: NSImage?            // Display icon
    let type: SearchResultType    // Result source type
    let score: Double             // Composite ranking score (0-1)
    let highlightRanges: [NSRange] // Highlight positions in title
    let action: SearchResultAction // Action when selected
}

// MARK: - System Command

/// Legacy unified-search compatibility wrapper for the Assistant MVP command whitelist.
///
/// This enum intentionally mirrors the 14 allowed `CommandID` values from
/// `doc/architecture_api.md` section 10.1. It does not include arbitrary shell,
/// sudo, shutdown, system restart, logout, file deletion, or process-kill actions.
enum SystemCommand: String, Codable, CaseIterable {
    case openSystemSettings
    case openAppSettings
    case openDownloads
    case openApplications
    case openDesktop
    case captureRegion
    case captureFullScreen
    case captureWindow
    case clearClipboardHistory
    case toggleClipboardRecording
    case checkPermissions
    case restartFinder
    case restartDock
    case toggleAppearance

    init(commandID: CommandID) {
        self = SystemCommand(rawValue: commandID.rawValue) ?? .openAppSettings
    }

    var commandID: CommandID {
        CommandID(rawValue: rawValue)
    }

    /// Whether this command requires an explicit user confirmation.
    var requiresConfirmation: Bool {
        switch self {
        case .clearClipboardHistory, .restartFinder, .restartDock:
            return true
        case .openSystemSettings, .openAppSettings, .openDownloads, .openApplications, .openDesktop,
             .captureRegion, .captureFullScreen, .captureWindow, .toggleClipboardRecording,
             .checkPermissions, .toggleAppearance:
            return false
        }
    }
}

// MARK: - Search Result Action

/// Action to perform when a search result is selected.
enum SearchResultAction {
    case launchApp(bundleID: String, path: URL)
    case openFile(path: URL)
    case openInFinder(path: URL)
    case copyToClipboard(itemID: Int64)
    case runSystemCommand(SystemCommand)
    /// Copy an arbitrary string (e.g. calculator result, converter output) to NSPasteboard.
    case copyText(String)
}

// MARK: - Unified Search Response

/// Response from a unified search query, grouped by type.
struct UnifiedSearchResponse {
    let applications: [UnifiedSearchResult]
    let files: [UnifiedSearchResult]
    let clipboard: [UnifiedSearchResult]
    let systemCommands: [UnifiedSearchResult]
    let calculations: [UnifiedSearchResult]
    let conversions: [UnifiedSearchResult]
    let totalCount: Int
    let elapsed: TimeInterval  // Search duration in milliseconds
}

// MARK: - SearchSource Protocol

/// Protocol for pluggable search sources.
///
/// Each source searches a specific domain (apps, files, clipboard)
/// and returns results in the unified format.
protocol UnifiedSearchSource {
    /// The type of results this source produces.
    var sourceType: SearchResultType { get }

    /// Search this source for matching items.
    /// - Parameters:
    ///   - query: Search query string
    ///   - limit: Maximum number of results to return
    /// - Returns: Array of unified search results
    func search(query: String, limit: Int) async throws -> [UnifiedSearchResult]
}
