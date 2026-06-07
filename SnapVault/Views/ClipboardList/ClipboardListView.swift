import SwiftUI

/// Main clipboard history list view with virtual scrolling and pagination.
struct ClipboardListView: View {
    @ObservedObject var viewModel: ClipboardListViewModel
    @State private var selectedItemID: Int64?
    @State private var previewItem: ClipboardItem?

    var body: some View {
        Group {
            if viewModel.items.isEmpty && !viewModel.isLoading {
                emptyStateView
            } else {
                listView
            }
        }
        .task {
            if viewModel.items.isEmpty {
                await viewModel.loadMore()
            }
        }
        .sheet(item: $previewItem) { item in
            PreviewPanel(
                item: item,
                onCopy: {
                    viewModel.copyToClipboard(item)
                },
                onDelete: {
                    Task {
                        await viewModel.deleteItem(item)
                    }
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

    // MARK: - List View

    private var listView: some View {
        List(selection: $selectedItemID) {
            ForEach(viewModel.items) { item in
                ClipboardItemRow(
                    item: item,
                    isSelected: selectedItemID == item.id,
                    highlightRanges: item.id.flatMap { viewModel.searchHighlights[$0] } ?? []
                )
                    .tag(item.id)
                    .id(item.id)
                    .onTapGesture {
                        selectedItemID = item.id
                        previewItem = item
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteItem(item)
                            }
                        } label: {
                            Label(L10n.localized("preview.delete"), systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            Task {
                                await viewModel.toggleFavorite(item)
                            }
                        } label: {
                            Label(
                                item.isFavorite ? L10n.localized("clipboard.unfavorite") : L10n.localized("clipboard.favorite"),
                                systemImage: item.isFavorite ? "star.slash" : "star"
                            )
                        }
                        .tint(.yellow)
                    }
                    .contextMenu {
                        itemContextMenu(item)
                    }
                    .onAppear {
                        // Trigger pagination when near the end
                        if item.id == viewModel.items.last?.id {
                            Task {
                                await viewModel.loadMore()
                            }
                        }
                    }
            }

            // Loading indicator at bottom
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L10n.localized("clipboard.loading"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "clipboard")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text(L10n.localized("clipboard.empty.title"))
                .font(.title3)
                .foregroundColor(.secondary)

            Text(L10n.localized("clipboard.empty.subtitle"))
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func itemContextMenu(_ item: ClipboardItem) -> some View {
        Button(action: {
            viewModel.copyToClipboard(item)
        }) {
            Label(L10n.localized("preview.copy"), systemImage: "doc.on.doc")
        }

        Button(action: {
            previewItem = item
        }) {
            Label(L10n.localized("preview.open"), systemImage: "eye")
        }

        Button(action: {
            Task {
                await viewModel.togglePin(item)
            }
        }) {
            Label(
                item.isPinned ? L10n.localized("clipboard.unpin") : L10n.localized("clipboard.pin"),
                systemImage: item.isPinned ? "pin.slash" : "pin"
            )
        }

        Button(action: {
            Task {
                await viewModel.toggleFavorite(item)
            }
        }) {
            Label(
                item.isFavorite ? L10n.localized("clipboard.unfavorite") : L10n.localized("clipboard.favorite"),
                systemImage: item.isFavorite ? "star.slash" : "star"
            )
        }

        Divider()

        Button(role: .destructive, action: {
            Task {
                await viewModel.deleteItem(item)
            }
        }) {
            Label(L10n.localized("preview.delete"), systemImage: "trash")
        }
    }
}

#Preview {
    ClipboardListView(viewModel: ClipboardListViewModel())
}
