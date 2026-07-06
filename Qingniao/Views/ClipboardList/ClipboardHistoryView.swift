import AppKit
import SwiftUI

/// Qingniao clipboard history window (PRD P-02).
///
/// Two-column `NavigationSplitView`: a 180pt sidebar (type / special / time
/// segments + clear-all & settings footer) and a searchable detail list of
/// `JadeClipboardRow`s. Keyboard-driven: ⌘F focus search, ⌘A select all,
/// ↑↓ / jk move cursor, ⏎ / ⌘C copy & close, space / ⌘Y preview, ⌫ delete.
struct ClipboardHistoryView: View {
    @ObservedObject var viewModel: ClipboardListViewModel
    /// Invoked when an item is copied via ⏎ / click — closes the window.
    var onCopyAndClose: () -> Void = {}
    /// Opens the settings window from the sidebar footer.
    var onOpenSettings: () -> Void = {}

    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(180)
        } detail: {
            detail
        }
        .frame(minWidth: 880, minHeight: 600)
        .background(JadeColor.surface1)
        .tint(JadeColor.primary)
        .task { await viewModel.load() }
        .background(keyboardShortcuts)
        .jadeConfirmationDialog(
            "clipboard.clearAll.title",
            isPresented: $viewModel.showClearAllConfirmation,
            confirmTitle: "clipboard.clearAll.action",
            cancelTitle: "settings.alert.cancel",
            message: "clipboard.clearAll.message"
        ) {
            Task { await viewModel.clearAllConfirmed() }
        }
        .sheet(item: $viewModel.previewItem) { item in
            PreviewPanel(
                item: item,
                imageProvider: { await viewModel.originalImageData(for: $0) },
                richTextProvider: { await viewModel.richTextData(for: $0) },
                onCopy: { Task { await viewModel.copyToPasteboard(item) } },
                onDelete: { Task { await viewModel.delete(item) } }
            )
        }
        .jadeToast(viewModel.toastMessage, isShowing: $viewModel.showToast, variant: .info)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $viewModel.selection) {
            Section(L10n.localized("clipboard.sidebar.types")) {
                ForEach(ClipboardListViewModel.SidebarSelection.typeCases) { row in
                    sidebarRow(row)
                }
            }
            Section(L10n.localized("clipboard.sidebar.special")) {
                ForEach(ClipboardListViewModel.SidebarSelection.specialCases) { row in
                    sidebarRow(row)
                }
            }
            Section(L10n.localized("clipboard.sidebar.time")) {
                ForEach(ClipboardListViewModel.SidebarSelection.timeCases) { row in
                    sidebarRow(row)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
    }

    private func sidebarRow(_ row: ClipboardListViewModel.SidebarSelection) -> some View {
        Label(row.title, systemImage: row.iconName)
            .tag(row)
    }

    private var sidebarFooter: some View {
        VStack(spacing: JadeSpace.x2.value) {
            Divider()
            Button {
                viewModel.showClearAllConfirmation = true
            } label: {
                Label(L10n.localized("clipboard.clearAll.button"), systemImage: "trash")
            }
            .buttonStyle(.jadeDestructive)
            .disabled(viewModel.isClearing || viewModel.items.isEmpty)

            Button {
                onOpenSettings()
            } label: {
                Label(L10n.localized("management.page.settings"), systemImage: "gearshape")
            }
            .buttonStyle(.jadeGhost)
        }
        .padding(JadeSpace.x3.value)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Detail

    private var detail: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal, JadeSpace.x4.value)
                .padding(.vertical, JadeSpace.x3.value)

            Divider()

            content

            Divider()

            statusBar
                .padding(.horizontal, JadeSpace.x4.value)
                .padding(.vertical, JadeSpace.x2.value)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(JadeColor.surface1)
    }

    private var toolbar: some View {
        HStack(spacing: JadeSpace.x3.value) {
            JadeTextField(
                "clipboard.search.placeholder",
                text: $viewModel.query,
                icon: Image(systemName: "magnifyingglass")
            )
            .focused($searchFocused)

            JadePill("\(viewModel.items.count)", style: .primary)
                .accessibilityLabel(Text(L10n.localized("a11y.clipboard.itemCount", viewModel.items.count)))
        }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.clipboardEnabled {
            disabledState
        } else if viewModel.items.isEmpty && !viewModel.isLoading {
            emptyState
        } else {
            list
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: JadeSpace.x1.value) {
                    ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                        row(item, index: index)
                            .id(item.id)
                    }
                }
                .padding(.horizontal, JadeSpace.x3.value)
                .padding(.vertical, JadeSpace.x2.value)
            }
            .onChange(of: viewModel.selectedIndex) { _ in
                guard let selected = viewModel.selectedItem else { return }
                withAnimation(JadeAccessibility.animation(.easeInOut(duration: 0.12))) {
                    proxy.scrollTo(selected.id, anchor: .center)
                }
            }
        }
    }

    private func row(_ item: ClipboardRecordSnapshot, index: Int) -> some View {
        JadeClipboardRow(
            item: item,
            selected: viewModel.selectedIDs.contains(item.id) || index == viewModel.selectedIndex,
            thumbnailProvider: { await viewModel.thumbnailData(for: $0) },
            onPin: { Task { await viewModel.togglePin(item) } },
            onCopy: { Task { await viewModel.copyToPasteboard(item) } },
            onPreview: { viewModel.previewItem = item },
            onDelete: { Task { await viewModel.delete(item) } }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.select(item)
            Task {
                await viewModel.copyToPasteboard(item)
                onCopyAndClose()
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task { await viewModel.toggleFavorite(item) }
            } label: {
                Label(item.isFavorite ? L10n.localized("clipboard.unfavorite") : L10n.localized("clipboard.favorite"),
                      systemImage: "star.fill")
            }
            .tint(.yellow)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { await viewModel.delete(item) }
            } label: {
                Label(L10n.localized("preview.delete"), systemImage: "trash")
            }
            .tint(.red)
        }
        .contextMenu {
            Button(L10n.localized("clipboard.action.copy")) {
                Task { await viewModel.copyToPasteboard(item) }
            }
            Button(L10n.localized("preview.open")) { viewModel.previewItem = item }
            Button(item.isPinned ? L10n.localized("clipboard.unpin") : L10n.localized("clipboard.pin")) {
                Task { await viewModel.togglePin(item) }
            }
            Button(item.isFavorite ? L10n.localized("clipboard.unfavorite") : L10n.localized("clipboard.favorite")) {
                Task { await viewModel.toggleFavorite(item) }
            }
            Divider()
            Button(role: .destructive) {
                Task { await viewModel.delete(item) }
            } label: {
                Text(L10n.localized("preview.delete"))
            }
            Button(role: .destructive) {
                viewModel.showClearAllConfirmation = true
            } label: {
                Text(L10n.localized("clipboard.clearAll.button"))
            }
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: JadeSpace.x1.value) {
            Text(L10n.localized("clipboard.status.summary",
                                viewModel.items.count,
                                viewModel.formattedStorageUsage,
                                retentionText))
                .font(JadeFont.caption)
                .foregroundStyle(JadeColor.textTertiary)
            Spacer()
            if viewModel.isLoading {
                ProgressView().scaleEffect(0.6)
            }
        }
    }

    private var retentionText: String {
        if let days = viewModel.retentionDays {
            return L10n.localized("clipboard.status.retentionDays", days)
        }
        return L10n.localized("clipboard.status.retentionForever")
    }

    // MARK: - Empty states

    private var emptyState: some View {
        VStack(spacing: JadeSpace.x3.value) {
            Image(systemName: viewModel.isSearching ? "magnifyingglass" : "tray")
                .font(.system(size: 40))
                .foregroundStyle(JadeColor.textSecondary)
                .accessibilityHidden(true)
            Text(viewModel.isSearching
                 ? L10n.localized("clipboard.empty.search.title")
                 : L10n.localized("clipboard.empty.title"))
                .font(JadeFont.title3)
                .foregroundStyle(JadeColor.textSecondary)
            if !viewModel.isSearching {
                Text(L10n.localized("clipboard.empty.subtitle"))
                    .font(JadeFont.caption)
                    .foregroundStyle(JadeColor.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var disabledState: some View {
        VStack(spacing: JadeSpace.x3.value) {
            Image(systemName: "hand.raised.slash")
                .font(.system(size: 40))
                .foregroundStyle(JadeColor.textSecondary)
                .accessibilityHidden(true)
            Text(L10n.localized("clipboard.empty.disabled.title"))
                .font(JadeFont.title3)
                .foregroundStyle(JadeColor.textSecondary)
            Button(L10n.localized("clipboard.empty.disabled.enable")) {
                Task { await viewModel.enableClipboard() }
            }
            .buttonStyle(.jadePrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Keyboard shortcuts (hidden buttons, macOS 13 compatible)

    private var keyboardShortcuts: some View {
        ZStack {
            shortcutButton(.init("f"), modifiers: .command) { searchFocused = true }
            shortcutButton(.init("a"), modifiers: .command) { viewModel.selectAll() }
            shortcutButton(.upArrow, modifiers: []) { viewModel.moveSelectionUp() }
            shortcutButton(.downArrow, modifiers: []) { viewModel.moveSelectionDown() }
            shortcutButton(.init("k"), modifiers: []) { viewModel.moveSelectionUp() }
            shortcutButton(.init("j"), modifiers: []) { viewModel.moveSelectionDown() }
            shortcutButton(.return, modifiers: []) {
                viewModel.copySelectedToPasteboard()
                onCopyAndClose()
            }
            shortcutButton(.init("c"), modifiers: .command) {
                viewModel.copySelectedToPasteboard()
                onCopyAndClose()
            }
            shortcutButton(.init("y"), modifiers: .command) {
                viewModel.previewItem = viewModel.selectedItem
            }
            shortcutButton(.space, modifiers: []) {
                if !searchFocused { viewModel.previewItem = viewModel.selectedItem }
            }
            shortcutButton(.delete, modifiers: []) {
                if !searchFocused { Task { await viewModel.deleteSelected() } }
            }
        }
        .allowsHitTesting(false)
    }

    private func shortcutButton(_ key: KeyEquivalent, modifiers: EventModifiers, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: { EmptyView() }
        .buttonStyle(.plain)
        .keyboardShortcut(key, modifiers: modifiers)
        .frame(width: 0, height: 0)
        .opacity(0)
    }
}

#Preview {
    ClipboardHistoryView(viewModel: ClipboardListViewModel())
}
