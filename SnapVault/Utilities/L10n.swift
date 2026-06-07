import Foundation

/// Localization helper providing a unified entry point for all user-facing strings.
///
/// Usage:
///   Text(L10n.localized("settings.general"))
///   Text(L10n.localized("settings.retention.format", viewModel.retentionDays))
///
/// Keys are defined in `Resources/Localizable.xcstrings` (Xcode String Catalog format).
enum L10n {
    /// Retrieve a static localized string for the given key.
    static func localized(_ key: String, comment: String = "") -> String {
        return NSLocalizedString(key, bundle: .main, comment: comment)
    }

    /// Retrieve a format string and interpolate the given arguments.
    static func localized(_ key: String, _ args: CVarArg..., comment: String = "") -> String {
        let format = NSLocalizedString(key, bundle: .main, comment: comment)
        return String(format: format, arguments: args)
    }
}
