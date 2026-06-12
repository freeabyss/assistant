import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Toggle the Assistant Command Bar (floating panel) visibility.
    /// Default shortcut: Command+Space.
    ///
    /// Note: This conflicts with macOS Spotlight by default. Users are expected to
    /// either disable Spotlight's shortcut in System Settings or customise this
    /// binding in Assistant Preferences → Shortcuts. The KeyboardShortcuts library
    /// only applies this default the first time the app launches, so existing user
    /// customisations are preserved.
    static let togglePanel = Self("togglePanel", default: .init(.space, modifiers: [.command]))

    /// Capture a region of the screen (user selects area via overlay).
    /// Default shortcut: Command+Shift+A.
    static let captureRegion = Self("captureRegion", default: .init(.a, modifiers: [.command, .shift]))

    /// Capture the window under the mouse cursor.
    /// Default shortcut: Command+Shift+W.
    static let captureWindow = Self("captureWindow", default: .init(.w, modifiers: [.command, .shift]))
}
