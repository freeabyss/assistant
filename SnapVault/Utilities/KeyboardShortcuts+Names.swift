import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Toggle the SnapVault floating panel visibility.
    /// Default shortcut: Command+Shift+V.
    static let togglePanel = Self("togglePanel", default: .init(.v, modifiers: [.command, .shift]))

    /// Capture a region of the screen (user selects area via overlay).
    /// Default shortcut: Command+Shift+S.
    static let captureRegion = Self("captureRegion", default: .init(.s, modifiers: [.command, .shift]))

    /// Capture the window under the mouse cursor.
    /// Default shortcut: Command+Shift+W.
    static let captureWindow = Self("captureWindow", default: .init(.w, modifiers: [.command, .shift]))
}
