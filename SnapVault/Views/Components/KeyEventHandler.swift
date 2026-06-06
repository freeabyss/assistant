import SwiftUI
import AppKit

/// A transparent NSView that intercepts key events for keyboard navigation.
///
/// Used as an overlay on the main content view to handle arrow keys and Enter
/// for search result navigation, compatible with macOS 13+.
struct KeyEventHandler: NSViewRepresentable {
    var onUpArrow: () -> Void
    var onDownArrow: () -> Void
    var onReturn: () -> Void
    var onTab: () -> Void

    func makeNSView(context: Context) -> KeyEventNSView {
        let view = KeyEventNSView()
        view.onUpArrow = onUpArrow
        view.onDownArrow = onDownArrow
        view.onReturn = onReturn
        view.onTab = onTab
        return view
    }

    func updateNSView(_ nsView: KeyEventNSView, context: Context) {
        nsView.onUpArrow = onUpArrow
        nsView.onDownArrow = onDownArrow
        nsView.onReturn = onReturn
        nsView.onTab = onTab
    }
}

/// Custom NSView that accepts first responder and intercepts key events.
class KeyEventNSView: NSView {
    var onUpArrow: (() -> Void)?
    var onDownArrow: (() -> Void)?
    var onReturn: (() -> Void)?
    var onTab: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126: // Up arrow
            onUpArrow?()
        case 125: // Down arrow
            onDownArrow?()
        case 36: // Return/Enter
            onReturn?()
        case 48: // Tab
            onTab?()
        default:
            super.keyDown(with: event)
        }
    }
}
