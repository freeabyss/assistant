import SwiftUI
import AppKit

/// A single row in the unified search results list.
///
/// Displays a type icon, title with keyword highlighting, subtitle,
/// and an optional keyboard shortcut hint. Supports selected state highlighting.
struct UnifiedResultRow: View {
    let result: UnifiedSearchResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Type icon
            typeIcon

            // Title + subtitle
            VStack(alignment: .leading, spacing: 2) {
                titleText
                    .lineLimit(1)

                if let subtitle = result.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            // Action hint
            actionHint
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }

    // MARK: - Type Icon

    @ViewBuilder
    private var typeIcon: some View {
        if let icon = result.icon {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(typeColor.opacity(0.15))
                    .frame(width: 28, height: 28)

                Image(systemName: result.type.iconName)
                    .font(.system(size: 13))
                    .foregroundColor(typeColor)
            }
        }
    }

    private var typeColor: Color {
        switch result.type {
        case .application: return .blue
        case .file: return .green
        case .clipboard: return .orange
        case .systemCommand: return .purple
        }
    }

    // MARK: - Title with Highlighting

    @ViewBuilder
    private var titleText: some View {
        if !result.highlightRanges.isEmpty {
            Text(highlightedAttributedString(text: result.title, ranges: result.highlightRanges))
                .font(.system(size: 13, weight: .medium))
        } else {
            Text(result.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
    }

    /// Build an AttributedString with yellow background highlight at the specified ranges.
    private func highlightedAttributedString(text: String, ranges: [NSRange]) -> AttributedString {
        let nsString = text as NSString
        let nsAttr = NSMutableAttributedString(string: text, attributes: [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 13, weight: .medium)
        ])

        for range in ranges {
            let clampedRange = NSIntersectionRange(range, NSRange(location: 0, length: nsString.length))
            guard clampedRange.length > 0 else { continue }
            nsAttr.addAttributes([
                .backgroundColor: NSColor.systemYellow.withAlphaComponent(0.4),
                .foregroundColor: NSColor.labelColor
            ], range: clampedRange)
        }

        return AttributedString(nsAttr)
    }

    // MARK: - Action Hint

    @ViewBuilder
    private var actionHint: some View {
        switch result.action {
        case .launchApp:
            Text("Enter")
                .font(.system(size: 10, design: .monospaced))
        case .openFile:
            Text("Enter")
                .font(.system(size: 10, design: .monospaced))
        case .openInFinder:
            Text("Enter")
                .font(.system(size: 10, design: .monospaced))
        case .copyToClipboard:
            Text("Enter")
                .font(.system(size: 10, design: .monospaced))
        case .runSystemCommand:
            Text("Enter")
                .font(.system(size: 10, design: .monospaced))
        }
    }
}
