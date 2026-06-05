import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Toggle the SnapVault floating panel visibility.
    /// Default shortcut: Command+Shift+V.
    static let togglePanel = Self("togglePanel", default: .init(.v, modifiers: [.command, .shift]))
}
