import Foundation

/// Owns the Assistant Application Support directory layout used by Core Data and
/// large clipboard resources.
struct AssistantFileSystem: Hashable {
    var rootDirectory: URL

    /// The Application Support subdirectory name for the active data root.
    /// v1.2: renamed from "Assistant" to "Qingniao" (brand rename). Migration of an
    /// existing "Assistant" directory is handled by `DataDirectoryMigrator`.
    static let directoryName = "Qingniao"

    /// Legacy (pre-v1.2) Application Support subdirectory name, kept for migration.
    static let legacyDirectoryName = "Assistant"

    /// The Core Data SQLite store file name (v1.2: renamed from "Assistant.sqlite").
    static let storeFileName = "Qingniao.sqlite"

    /// Legacy (pre-v1.2) Core Data SQLite store file name, kept for migration.
    static let legacyStoreFileName = "Assistant.sqlite"

    static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    static var `default`: AssistantFileSystem {
        AssistantFileSystem(rootDirectory: applicationSupportDirectory.appendingPathComponent(directoryName, isDirectory: true))
    }

    var storeURL: URL {
        rootDirectory.appendingPathComponent(Self.storeFileName, isDirectory: false)
    }

    var clipboardDirectory: URL {
        rootDirectory.appendingPathComponent("Clipboard", isDirectory: true)
    }

    var imagesDirectory: URL {
        clipboardDirectory.appendingPathComponent("Images", isDirectory: true)
    }

    var thumbnailsDirectory: URL {
        clipboardDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    var richTextDirectory: URL {
        clipboardDirectory.appendingPathComponent("RichText", isDirectory: true)
    }

    var logsDirectory: URL {
        rootDirectory.appendingPathComponent("Logs", isDirectory: true)
    }

    func ensureDirectoryStructure(fileManager: FileManager = .default) throws {
        for directory in [rootDirectory, clipboardDirectory, imagesDirectory, thumbnailsDirectory, richTextDirectory, logsDirectory] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    func resourcePath(for id: UUID, type: AssistantClipboardResourceType) -> String {
        "Clipboard/\(type.directoryName)/\(id.uuidString).\(type.fileExtension)"
    }

    func resourceURL(relativePath: String) -> URL {
        rootDirectory.appendingPathComponent(relativePath, isDirectory: false)
    }
}

enum AssistantClipboardResourceType: String, CaseIterable {
    case imageOriginal
    case imageThumbnail
    case richTextRTF
    case richTextHTML

    var directoryName: String {
        switch self {
        case .imageOriginal:
            return "Images"
        case .imageThumbnail:
            return "Thumbnails"
        case .richTextRTF, .richTextHTML:
            return "RichText"
        }
    }

    var fileExtension: String {
        switch self {
        case .imageOriginal, .imageThumbnail:
            return "png"
        case .richTextRTF:
            return "rtf"
        case .richTextHTML:
            return "html"
        }
    }

    var mimeType: String {
        switch self {
        case .imageOriginal, .imageThumbnail:
            return "image/png"
        case .richTextRTF:
            return "application/rtf"
        case .richTextHTML:
            return "text/html"
        }
    }
}
