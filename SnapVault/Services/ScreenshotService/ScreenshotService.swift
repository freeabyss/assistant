import Foundation
import ScreenCaptureKit
import CoreGraphics
import Cocoa
import os.log

// MARK: - Protocol

/// Protocol for screenshot operations.
protocol ScreenshotServiceProtocol {
    /// Capture a region selected by the user via an overlay.
    func captureRegion() async throws -> ScreenshotResult

    /// Capture the window under the mouse cursor.
    func captureWindow() async throws -> ScreenshotResult

    /// Capture the entire screen.
    func captureScreen() async throws -> ScreenshotResult
}

// MARK: - Types

/// Result of a screenshot capture.
struct ScreenshotResult {
    let imageData: Data
    let width: Int
    let height: Int
    let captureDate: Date
    let sourceType: CaptureSource
}

/// The source type of a screenshot capture.
enum CaptureSource {
    case region
    case window
    case screen
}

// MARK: - CGImage Extension

extension CGImage {
    /// Convert CGImage to PNG data.
    func pngData() -> Data? {
        let rep = NSBitmapImageRep(cgImage: self)
        return rep.representation(using: .png, properties: [:])
    }
}

// MARK: - ScreenshotService

/// Screenshot service for high-quality screen capture.
///
/// Uses ScreenCaptureKit (SCShareableContent) for window enumeration,
/// and CoreGraphics APIs for actual capture (compatible with macOS 13+).
///
/// Supports three capture modes:
/// - Region: User selects a rectangular area via a transparent overlay
/// - Window: Captures the window under the mouse cursor
/// - Screen: Captures the entire screen
final class ScreenshotService: ScreenshotServiceProtocol {
    private let logger = Logger.screenshot

    /// Capture a region selected by the user.
    ///
    /// Shows a transparent overlay window covering the entire screen.
    /// The user drags to select a rectangle, then the selected region is captured.
    /// Pressing ESC cancels the capture.
    ///
    /// - Returns: The captured screenshot as PNG data
    /// - Throws: `SnapVaultError.screenshotFailed` if the user cancels or capture fails
    func captureRegion() async throws -> ScreenshotResult {
        logger.info("Starting region capture")

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: SnapVaultError.screenshotFailed(reason: L10n.localized("error.serviceDeallocated")))
                    return
                }

                let overlay = ScreenshotOverlayController { [weak self] rect in
                    guard let self else { return }

                    if let rect = rect {
                        Task {
                            do {
                                let result = try await self.captureRect(rect)
                                continuation.resume(returning: result)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    } else {
                        self.logger.info("Region capture cancelled by user")
                        continuation.resume(throwing: SnapVaultError.screenshotFailed(reason: L10n.localized("error.userCancelled")))
                    }
                }

                overlay.show()
                self.logger.debug("Screenshot overlay shown")
            }
        }
    }

    /// Capture the window under the mouse cursor.
    ///
    /// Uses ScreenCaptureKit to enumerate windows and find the one under the cursor,
    /// then uses CGWindowListCreateImage for the actual capture.
    ///
    /// - Returns: The captured window screenshot as PNG data
    /// - Throws: `SnapVaultError.screenshotFailed` if no window is found or capture fails
    func captureWindow() async throws -> ScreenshotResult {
        logger.info("Starting window capture")

        let mouseLocation = NSEvent.mouseLocation
        logger.debug("Mouse location: \(mouseLocation.debugDescription)")

        // Get available content to enumerate on-screen windows
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard !content.windows.isEmpty else {
            throw SnapVaultError.screenshotFailed(reason: L10n.localized("error.noWindows"))
        }

        // Find the window under the mouse cursor.
        // SCWindow.frame uses top-left origin (Core Graphics coordinates).
        // NSEvent.mouseLocation uses bottom-left origin (AppKit coordinates).
        guard let screen = NSScreen.main else {
            throw SnapVaultError.screenshotFailed(reason: L10n.localized("error.noMainScreen"))
        }
        let screenHeight = screen.frame.height

        // Find the topmost window containing the mouse point.
        // Windows are ordered front-to-back in the array.
        guard let targetWindow = content.windows.first(where: { window in
            let frame = window.frame
            // Convert SCWindow frame (top-left origin) to AppKit coordinates (bottom-left origin)
            let appKitFrame = CGRect(
                x: frame.origin.x,
                y: screenHeight - frame.origin.y - frame.height,
                width: frame.width,
                height: frame.height
            )
            return appKitFrame.contains(mouseLocation)
        }) else {
            throw SnapVaultError.screenshotFailed(reason: L10n.localized("error.noWindowAtMouse"))
        }

        let windowID = targetWindow.windowID
        logger.info("Found window: \(targetWindow.title ?? "untitled") (ID: \(windowID))")

        // Capture the window using CGWindowListCreateImage
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionOnScreenAboveWindow,
            CGWindowID(windowID),
            .bestResolution
        ) else {
            throw SnapVaultError.screenshotFailed(reason: L10n.localized("error.captureWindowFailed"))
        }

        guard let data = cgImage.pngData() else {
            throw SnapVaultError.screenshotFailed(reason: L10n.localized("error.pngConversionFailed"))
        }

        logger.info("Window capture complete: \(cgImage.width)x\(cgImage.height), \(data.count) bytes")

        return ScreenshotResult(
            imageData: data,
            width: cgImage.width,
            height: cgImage.height,
            captureDate: Date(),
            sourceType: .window
        )
    }

    /// Capture the entire screen.
    ///
    /// - Returns: The captured full-screen screenshot as PNG data
    /// - Throws: `SnapVaultError.screenshotFailed` if capture fails
    func captureScreen() async throws -> ScreenshotResult {
        logger.info("Starting full screen capture")

        guard let cgImage = CGDisplayCreateImage(CGMainDisplayID()) else {
            throw SnapVaultError.screenshotFailed(reason: L10n.localized("error.captureScreenFailed"))
        }

        guard let data = cgImage.pngData() else {
            throw SnapVaultError.screenshotFailed(reason: L10n.localized("error.pngConversionFailed"))
        }

        logger.info("Full screen capture complete: \(cgImage.width)x\(cgImage.height), \(data.count) bytes")

        return ScreenshotResult(
            imageData: data,
            width: cgImage.width,
            height: cgImage.height,
            captureDate: Date(),
            sourceType: .screen
        )
    }

    // MARK: - Private

    /// Capture a specific rectangular region of the screen.
    ///
    /// Captures the full screen and crops to the specified region.
    ///
    /// - Parameter rect: The region to capture in AppKit coordinates (bottom-left origin)
    /// - Returns: The captured screenshot as PNG data
    private func captureRect(_ rect: NSRect) async throws -> ScreenshotResult {
        logger.info("Capturing rect: \(rect.debugDescription)")

        // Capture the full screen first
        guard let fullImage = CGDisplayCreateImage(CGMainDisplayID()) else {
            throw SnapVaultError.screenshotFailed(reason: L10n.localized("error.captureScreenFailed"))
        }

        // Convert AppKit coordinates (bottom-left origin) to CG coordinates (top-left origin).
        // CGDisplayCreateImage returns the image in the display's native coordinate system.
        let displayHeight = CGFloat(fullImage.height)
        let scaleFactor = CGFloat(fullImage.width) / NSScreen.main!.frame.width

        let cgRect = CGRect(
            x: rect.origin.x * scaleFactor,
            y: (displayHeight - rect.origin.y * scaleFactor - rect.height * scaleFactor),
            width: rect.width * scaleFactor,
            height: rect.height * scaleFactor
        )

        logger.debug("CG rect for cropping: \(cgRect.debugDescription)")

        // Crop to the selected region
        guard let croppedImage = fullImage.cropping(to: cgRect) else {
            throw SnapVaultError.screenshotFailed(reason: L10n.localized("error.cropFailed"))
        }

        guard let data = croppedImage.pngData() else {
            throw SnapVaultError.screenshotFailed(reason: L10n.localized("error.pngConversionFailed"))
        }

        logger.info("Region capture complete: \(croppedImage.width)x\(croppedImage.height), \(data.count) bytes")

        return ScreenshotResult(
            imageData: data,
            width: croppedImage.width,
            height: croppedImage.height,
            captureDate: Date(),
            sourceType: .region
        )
    }
}
