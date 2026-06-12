import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import os.log

/// MVP permissions that must be granted before Assistant can enter the full experience.
enum PermissionKind: String, Codable, CaseIterable, Hashable {
    case screenRecording
    case accessibility
}

enum PermissionStatus: String, Codable, Hashable {
    case authorized
    case denied
    case notDetermined
    case unknown

    var isAuthorized: Bool { self == .authorized }
}

protocol PermissionServiceProtocol {
    func status(for permission: PermissionKind) -> PermissionStatus
    func openSystemSettings(for permission: PermissionKind)
    func refreshStatuses() async -> [PermissionKind: PermissionStatus]
}

/// Thin macOS API wrapper for Screen Recording and Accessibility privacy permissions.
final class PermissionService: PermissionServiceProtocol {
    private let workspace: NSWorkspace
    private let logger = Logger.app

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func status(for permission: PermissionKind) -> PermissionStatus {
        switch permission {
        case .screenRecording:
            return CGPreflightScreenCaptureAccess() ? .authorized : .denied
        case .accessibility:
            return AXIsProcessTrusted() ? .authorized : .denied
        }
    }

    func openSystemSettings(for permission: PermissionKind) {
        if permission == .accessibility {
            requestAccessibilityPromptIfNeeded()
        }

        guard let url = systemSettingsURL(for: permission) else { return }
        workspace.open(url)
        logger.info("Opened System Settings for permission: \(permission.rawValue, privacy: .public)")
    }

    func refreshStatuses() async -> [PermissionKind: PermissionStatus] {
        Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, status(for: $0)) })
    }

    private func requestAccessibilityPromptIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func systemSettingsURL(for permission: PermissionKind) -> URL? {
        let anchor: String
        switch permission {
        case .screenRecording:
            anchor = "Privacy_ScreenCapture"
        case .accessibility:
            anchor = "Privacy_Accessibility"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")
    }
}
