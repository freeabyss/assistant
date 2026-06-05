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
                ClipboardItemRow(item: item, isSelected: selectedItemID == item.id)
                    .tag(item.id)
                    .id(item.id)
                    .onTapGesture {
                        selectedItemID = item.id
                        previewItem = item
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
                    Text("Loading...")
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

            Text("No clipboard history")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("Items you copy will appear here")
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
            Label("Copy", systemImage: "doc.on.doc")
        }

        Button(action: {
            previewItem = item
        }) {
            Label("Preview", systemImage: "eye")
        }

        Button(action: {
            Task {
                await viewModel.togglePin(item)
            }
        }) {
            Label(
                item.isPinned ? "Unpin" : "Pin",
                systemImage: item.isPinned ? "pin.slash" : "pin"
            )
        }

        Divider()

        Button(role: .destructive, action: {
            Task {
                await viewModel.deleteItem(item)
            }
        }) {
            Label("Delete", systemImage: "trash")
        }
    }
}

#Preview {
    ClipboardListView(viewModel: ClipboardListViewModel())
}
