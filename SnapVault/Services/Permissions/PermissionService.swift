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

    /// 触发屏幕录制权限申请，会促使系统首次注册本 App 到 TCC 数据库并加入设置候选列表。
    /// - Returns: 当前是否已授权(`CGRequestScreenCaptureAccess()` 的直接返回值)。
    /// - Note: 首次调用会弹出系统权限 UI；必须在主线程调用。参见 Issue #3、v1.1.0 architecture §4.1。
    @MainActor
    func requestScreenRecordingPrompt() -> Bool
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

    @MainActor
    func requestScreenRecordingPrompt() -> Bool {
        CGRequestScreenCaptureAccess()
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
