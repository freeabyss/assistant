import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Toggle the Assistant Command Bar (floating panel) visibility.
    /// Default shortcut: Option+Space.
    ///
    /// Onboarding validates this binding against enabled macOS symbolic hotkeys.
    /// If it conflicts or cannot be recorded, the user must choose another
    /// successful shortcut before entering the full Assistant experience.
    static let togglePanel = Self("togglePanel", default: .init(.space, modifiers: [.option]))

    /// Capture a region of the screen (user selects area via overlay).
    /// Default shortcut: Command+Shift+A.
    static let captureRegion = Self("captureRegion", default: .init(.a, modifiers: [.command, .shift]))

    /// Capture the window under the mouse cursor.
    /// Default shortcut: Command+Shift+W.
    static let captureWindow = Self("captureWindow", default: .init(.w, modifiers: [.command, .shift]))
}
