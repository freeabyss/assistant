import Foundation

/// Application-wide error type.
enum SnapVaultError: LocalizedError {
    case databaseError(underlying: Error)
    case ocrFailed(reason: String)
    case clipboardAccessDenied
    case itemNotFound(id: Int64)
    case storageLimitExceeded
    case exportFailed(reason: String)
    case importFailed(reason: String)
    case screenshotFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .databaseError(let underlying):
            return "Database error: \(underlying.localizedDescription)"
        case .ocrFailed(let reason):
            return "OCR failed: \(reason)"
        case .clipboardAccessDenied:
            return "Clipboard access denied"
        case .itemNotFound(let id):
            return "Item with id \(id) not found"
        case .storageLimitExceeded:
            return "Storage limit exceeded"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .importFailed(let reason):
            return "Import failed: \(reason)"
        case .screenshotFailed(let reason):
            return "Screenshot failed: \(reason)"
        }
    }
}
