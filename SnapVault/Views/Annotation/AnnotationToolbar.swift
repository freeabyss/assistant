import SwiftUI
import Cocoa

// MARK: - Annotation Toolbar (SwiftUI)

/// The toolbar strips above and below the canvas inside `AnnotationEditorWindow`.
/// Split into top-bar (tools, colours, line-width, undo/redo) and bottom-bar
/// (Save / Copy / Cancel) so the layout mirrors standard image editors.
struct AnnotationTopToolbar: View {
    @ObservedObject var state: AnnotationCanvasState

    /// Closure invoked for undo / redo (the NSView owns the UndoManager).
    let onUndo: () -> Void
    let onRedo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // --- Tool selector ---
            HStack(spacing: 2) {
                ForEach(AnnotationTool.allCases) { tool in
                    ToolPill(tool: tool, selected: state.tool == tool) {
                        state.tool = tool
                    }
                }
            }
            .padding(.leading, 12)

            Divider().frame(height: 28)

            // --- Colour picker ---
            HStack(spacing: 2) {
                ForEach(AnnotationPalette.colors, id: \.self) { c in
                    ColorSwatch(color: c, selected: state.color == c) {
                        state.color = c
                    }
                }
            }

            Divider().frame(height: 28)

            // --- Line-width slider ---
            HStack(spacing: 4) {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Slider(value: Binding(
                    get: { state.lineWidth },
                    set: { state.lineWidth = $0 }
                ), in: AnnotationPalette.minLineWidth...AnnotationPalette.maxLineWidth, step: 1)
                    .frame(width: 80)
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Divider().frame(height: 28)

            // --- Undo / Redo ---
            HStack(spacing: 6) {
                IconButton(systemName: "arrow.uturn.backward", tooltip: L10n.localized("annotation.undo.help"), action: onUndo)
                IconButton(systemName: "arrow.uturn.forward", tooltip: L10n.localized("annotation.redo.help"), action: onRedo)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct AnnotationBottomToolbar: View {
    let onSave: () -> Void
    let onCopy: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(L10n.localized("annotation.cancel")) { onCancel() }
                .keyboardShortcut(.cancelAction)
            Button(L10n.localized("annotation.copy")) { onCopy() }
                .keyboardShortcut("c", modifiers: .command)
            Button(L10n.localized("annotation.save")) { onSave() }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Tool Pills

private struct ToolPill: View {
    let tool: AnnotationTool
    let selected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 12, weight: .medium))
                Text(tool.displayName)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(selected ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? Color.accentColor : (hovering ? Color.primary.opacity(0.1) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Color Swatches

private struct ColorSwatch: View {
    let color: NSColor
    let selected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(nsColor: color))
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2)
                        .frame(width: 26, height: 26)
                )
                .shadow(color: .black.opacity(hovering ? 0.3 : 0.15), radius: hovering ? 3 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Icon Button

private struct IconButton: View {
    let systemName: String
    let tooltip: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(hovering ? Color.primary.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering = $0 }
    }
}
