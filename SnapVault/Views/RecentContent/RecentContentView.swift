import SwiftUI

/// Recent Content Center — date-grouped unified view of clipboard / OCR / screenshots.
///
/// This is the "browse" half of the panel introduced by US-023; the "search"
/// half remains `UnifiedResultList` (Spotlight-style). Mode switching lives in
/// `MenuBarView` and feeds an empty/non-empty searchText state into both.
///
/// Layout:
/// - Filter tabs (All / Screenshot / OCR / Clipboard) at the top
/// - `List` with `Section`s — macOS 13+ renders sticky headers natively
/// - Each row uses `ClipboardItemRow` for visual consistency with the legacy
///   `ClipboardListView`
/// - Tap → `PreviewPanel` sheet (same component reused)
/// - Trailing swipe: Delete (destructive). Leading swipe: Favorite (yellow).
struct RecentContentView: View {
    @ObservedObject var viewModel: RecentContentViewModel
    @State private var selectedItemID: Int64?
    @State private var previewItem: ClipboardItem?

    var body: some View {
        VStack(spacing: 0) {
            filterTabs
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            content
        }
        .task {
            if viewModel.sections.isEmpty {
                await viewModel.loadGroups()
            }
        }
        .sheet(item: $previewItem) { item in
            PreviewPanel(
                item: item,
                onCopy: { viewModel.copyToClipboard(item) },
                onDelete: {
                    Task { await viewModel.deleteItem(item) }
                }
            )
        }
        .overlay(alignment: .center) {
            if viewModel.showToast {
                ToastView(message: viewModel.toastMessage)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.showToast)
            }
        }
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        HStack(spacing: 6) {
            ForEach(RecentFilter.allCases) { filter in
                Button(action: { viewModel.filter = filter }) {
                    HStack(spacing: 4) {
                        Image(systemName: filter.iconName)
                            .font(.system(size: 10))
                        Text(filter.title)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(viewModel.filter == filter ? Color.accentColor : Color.clear)
                    .foregroundColor(viewModel.filter == filter ? .white : .primary)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.sections.isEmpty {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyState
            }
        } else {
            listView
        }
    }

    private var listView: some View {
        List(selection: $selectedItemID) {
            ForEach(viewModel.sections) { section in
                Section(header: sectionHeader(section.group.title)) {
                    ForEach(section.items) { item in
                        ClipboardItemRow(
                            item: item,
                            isSelected: selectedItemID == item.id
                        )
                            .tag(item.id)
                            .id(item.id)
                            .onTapGesture {
                                selectedItemID = item.id
                                previewItem = item
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteItem(item) }
                                } label: {
                                    Label(L10n.localized("preview.delete"), systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    Task { await viewModel.toggleFavorite(item) }
                                } label: {
                                    Label(
                                        item.isFavorite ? L10n.localized("clipboard.unfavorite") : L10n.localized("clipboard.favorite"),
                                        systemImage: item.isFavorite ? "star.slash" : "star"
                                    )
                                }
                                .tint(.yellow)
                            }
                            .contextMenu {
                                contextMenu(for: item)
                            }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenu(for item: ClipboardItem) -> some View {
        Button(action: { viewModel.copyToClipboard(item) }) {
            Label(L10n.localized("preview.copy"), systemImage: "doc.on.doc")
        }
        Button(action: { previewItem = item }) {
            Label(L10n.localized("preview.open"), systemImage: "eye")
        }
        Button(action: { Task { await viewModel.togglePin(item) } }) {
            Label(
                item.isPinned ? L10n.localized("clipboard.unpin") : L10n.localized("clipboard.pin"),
                systemImage: item.isPinned ? "pin.slash" : "pin"
            )
        }
        Button(action: { Task { await viewModel.toggleFavorite(item) } }) {
            Label(
                item.isFavorite ? L10n.localized("clipboard.unfavorite") : L10n.localized("clipboard.favorite"),
                systemImage: item.isFavorite ? "star.slash" : "star"
            )
        }
        Divider()
        Button(role: .destructive, action: {
            Task { await viewModel.deleteItem(item) }
        }) {
            Label(L10n.localized("preview.delete"), systemImage: "trash")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text(L10n.localized("recent.empty.title"))
                .font(.title3)
                .foregroundColor(.secondary)
            Text(L10n.localized("recent.empty.subtitle"))
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    RecentContentView(viewModel: RecentContentViewModel())
        .frame(width: 400, height: 500)
}
