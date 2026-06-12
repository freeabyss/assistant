import AppKit
import SwiftUI

/// Assistant MVP clipboard history page for the management center / clipboard entry.
///
/// Scope: search only clipboard history, filter by type, keyboard selection + Enter
/// copies the item back to NSPasteboard, pin/delete/clear-all management, and storage
/// usage display. MVP intentionally does not provide a right-click menu or auto-paste.
struct ClipboardListView: View {
    @ObservedObject var viewModel: ClipboardListViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 10)

            filterBar
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            Divider()

            content
        }
        .frame(minWidth: 760, minHeight: 560)
        .background(Color(NSColor.windowBackgroundColor))
        .background(
            KeyEventHandler(
                onUpArrow: { viewModel.moveSelectionUp() },
                onDownArrow: { viewModel.moveSelectionDown() },
                onReturn: { viewModel.copySelectedToPasteboard() },
                onEscape: {},
                onTab: {}
            )
            .allowsHitTesting(false)
        )
        .task {
            await viewModel.load()
        }
        .confirmationDialog(
            L10n.localized("clipboard.clearAll.title"),
            isPresented: $viewModel.showClearAllConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.localized("clipboard.clearAll.action"), role: .destructive) {
                Task { await viewModel.clearAllConfirmed() }
            }
            Button(L10n.localized("settings.alert.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.localized("clipboard.clearAll.message"))
        }
        .toast(message: viewModel.toastMessage, isShowing: viewModel.showToast)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.localized("clipboard.history.title"))
                        .font(.system(size: 24, weight: .semibold))
                    Text(L10n.localized("clipboard.history.subtitle"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                storageUsageView
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary.opacity(0.7))
                TextField(L10n.localized("clipboard.search.placeholder"), text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var storageUsageView: some View {
        HStack(spacing: 10) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(L10n.localized("clipboard.storage.label"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(viewModel.formattedStorageUsage)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }

            Button(role: .destructive) {
                viewModel.showClearAllConfirmation = true
            } label: {
                Label(L10n.localized("clipboard.clearAll.button"), systemImage: "trash")
            }
            .disabled(viewModel.isClearing || viewModel.items.isEmpty)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(ClipboardListViewModel.Filter.allCases) { filter in
                Button {
                    viewModel.filter = filter
                } label: {
                    Label(filter.title, systemImage: filter.iconName)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            viewModel.filter == filter ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .foregroundColor(viewModel.filter == filter ? .accentColor : .primary)
            }

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.65)
                Text(L10n.localized("clipboard.loading"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(L10n.localized("clipboard.items.count", viewModel.items.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.items.isEmpty && !viewModel.isLoading {
            emptyState
        } else {
            list
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            List(selection: Binding(
                get: { viewModel.selectedItem?.id },
                set: { id in
                    if let id, let item = viewModel.items.first(where: { $0.id == id }) {
                        viewModel.select(item)
                    }
                }
            )) {
                ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                    ClipboardHistoryRow(
                        item: item,
                        isSelected: index == viewModel.selectedIndex,
                        viewModel: viewModel
                    )
                    .tag(item.id)
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.select(item) }
                }
            }
            .listStyle(.plain)
            .onChange(of: viewModel.selectedIndex) { _ in
                if let selected = viewModel.selectedItem {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        proxy.scrollTo(selected.id, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: viewModel.isSearching ? "magnifyingglass" : "clipboard")
                .font(.system(size: 42))
                .foregroundColor(.secondary.opacity(0.5))
            Text(viewModel.isSearching ? L10n.localized("clipboard.empty.search.title") : L10n.localized("clipboard.empty.title"))
                .font(.title3)
                .foregroundColor(.secondary)
            Text(viewModel.isSearching ? L10n.localized("clipboard.empty.search.subtitle") : L10n.localized("clipboard.empty.subtitle"))
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.75))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ClipboardHistoryRow: View {
    let item: ClipboardRecordSnapshot
    let isSelected: Bool
    @ObservedObject var viewModel: ClipboardListViewModel
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 12) {
            iconView

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(primaryText)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                            .rotationEffect(.degrees(45))
                    }
                    if item.failureReason != nil {
                        Label(L10n.localized("clipboard.resourceMissing"), systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }

                Text(secondaryText)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(typeLabel, systemImage: item.contentType.iconName)
                    Text(L10n.relativeTime(from: item.updatedAt))
                    Spacer(minLength: 0)
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.8))
            }

            Spacer(minLength: 12)

            actionButtons
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(isSelected ? Color.accentColor.opacity(0.13) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .task(id: item.id) {
            if item.contentType == .image, let data = await viewModel.thumbnailData(for: item) {
                thumbnail = NSImage(data: data)
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(typeColor.opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: item.contentType.iconName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(typeColor)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 6) {
            Button {
                Task { await viewModel.copyToPasteboard(item) }
            } label: {
                Image(systemName: "return")
            }
            .help(L10n.localized("clipboard.action.copy"))

            Button {
                Task { await viewModel.togglePin(item) }
            } label: {
                Image(systemName: item.isPinned ? "pin.slash" : "pin")
            }
            .help(item.isPinned ? L10n.localized("clipboard.unpin") : L10n.localized("clipboard.pin"))

            Button(role: .destructive) {
                Task { await viewModel.delete(item) }
            } label: {
                Image(systemName: "trash")
            }
            .help(L10n.localized("preview.delete"))
        }
        .buttonStyle(.borderless)
        .font(.system(size: 13))
    }

    private var primaryText: String {
        switch item.contentType {
        case .text, .richText:
            return item.summary ?? item.plainText ?? L10n.localized("preview.empty")
        case .image:
            return item.summary ?? L10n.localized("content.image")
        case .file:
            return item.fileDisplayName ?? item.filePath?.lastPathComponent ?? L10n.localized("content.file")
        }
    }

    private var secondaryText: String {
        if let failureReason = item.failureReason { return failureReason }
        switch item.contentType {
        case .text, .richText:
            return item.plainText ?? item.summary ?? ""
        case .image:
            if let original = item.resources.first(where: { $0.type == .imageOriginal }), let width = original.width, let height = original.height {
                return "\(width) × \(height) · \(ByteCountFormatter.string(fromByteCount: original.byteSize, countStyle: .file))"
            }
            return L10n.localized("clipboard.image.subtitle")
        case .file:
            return item.filePath?.path ?? ""
        }
    }

    private var typeLabel: String {
        switch item.contentType {
        case .text: return L10n.localized("content.text")
        case .richText: return L10n.localized("content.richText")
        case .image: return L10n.localized("content.image")
        case .file: return L10n.localized("content.file")
        }
    }

    private var typeColor: Color {
        switch item.contentType {
        case .text: return .blue
        case .richText: return .orange
        case .image: return .green
        case .file: return .gray
        }
    }
}

private extension ClipboardContentType {
    var iconName: String {
        switch self {
        case .text:
            return "doc.text"
        case .richText:
            return "doc.richtext"
        case .image:
            return "photo"
        case .file:
            return "doc"
        }
    }
}

#Preview {
    ClipboardListView(viewModel: ClipboardListViewModel())
}
