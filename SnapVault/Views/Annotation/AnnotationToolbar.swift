import Cocoa
import SwiftUI

struct AnnotationTopToolbar: View {
    @ObservedObject var state: AnnotationCanvasState
    let onUndo: () -> Void
    let onRedo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(AnnotationTool.allCases) { tool in
                    ToolPill(tool: tool, selected: state.tool == tool) {
                        state.tool = tool
                    }
                }
            }

            Divider().frame(height: 30)

            HStack(spacing: 5) {
                ForEach(AnnotationColor.allCases) { color in
                    ColorSwatch(color: color, selected: state.style.color == color) {
                        state.style.color = color
                    }
                }
            }

            Divider().frame(height: 30)

            Picker("", selection: Binding(get: { state.style.lineWidth }, set: { state.style.lineWidth = $0 })) {
                ForEach(AnnotationLineWidth.allCases) { width in
                    Text(width.displayName).tag(width)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 132)
            .help(L10n.localized("annotation.lineWidth.help"))

            Picker("", selection: Binding(get: { state.style.textSize }, set: { state.style.textSize = $0 })) {
                ForEach(AnnotationTextSize.allCases) { size in
                    Text(size.displayName).tag(size)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 132)
            .help(L10n.localized("annotation.textSize.help"))

            Divider().frame(height: 30)

            IconButton(systemName: "arrow.uturn.backward", tooltip: L10n.localized("annotation.undo.help"), disabled: !state.canUndo, action: onUndo)
            IconButton(systemName: "arrow.uturn.forward", tooltip: L10n.localized("annotation.redo.help"), disabled: !state.canRedo, action: onRedo)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct AnnotationBottomToolbar: View {
    let onCancel: () -> Void
    let onCopy: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(L10n.localized("annotation.hint"))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Button(L10n.localized("annotation.cancel"), action: onCancel)
                .keyboardShortcut(.cancelAction)
            Button(L10n.localized("annotation.copy"), action: onCopy)
                .keyboardShortcut("c", modifiers: .command)
            Button(L10n.localized("annotation.save"), action: onSave)
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

private struct ToolPill: View {
    let tool: AnnotationTool
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(tool.displayName)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(selected ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Color.accentColor : (hovering ? Color.primary.opacity(0.1) : Color.clear)))
        }
        .buttonStyle(.plain)
        .help(tool.displayName)
        .onHover { hovering = $0 }
    }
}

private struct ColorSwatch: View {
    let color: AnnotationColor
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(nsColor: color.nsColor))
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(Color.primary.opacity(color == .white ? 0.35 : 0), lineWidth: 1))
                .overlay(Circle().stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2).frame(width: 26, height: 26))
                .shadow(color: .black.opacity(hovering ? 0.35 : 0.12), radius: hovering ? 3 : 1)
        }
        .buttonStyle(.plain)
        .help(color.displayName)
        .onHover { hovering = $0 }
    }
}

private struct IconButton: View {
    let systemName: String
    let tooltip: String
    let disabled: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 28)
                .foregroundColor(disabled ? .secondary.opacity(0.45) : .primary)
                .background(RoundedRectangle(cornerRadius: 6).fill(hovering && !disabled ? Color.primary.opacity(0.1) : Color.clear))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(tooltip)
        .onHover { hovering = $0 }
    }
}
