import Foundation
import Combine

/// ViewModel for the clipboard history list.
/// Will be fully implemented in US-002.
@MainActor
final class ClipboardListViewModel: ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var searchText: String = ""
    @Published var selectedContentType: ContentType?
    @Published var isLoading: Bool = false

    private let repository = ContentRepository()

    func loadMore() async {
        // Will be implemented in US-002
    }

    func deleteItem(_ item: ClipboardItem) async {
        guard let id = item.id else { return }
        try? repository.delete(id: id)
    }

    func togglePin(_ item: ClipboardItem) async {
        guard let id = item.id else { return }
        try? repository.togglePin(id: id)
    }

    func copyToClipboard(_ item: ClipboardItem) {
        // Will be implemented in US-004
    }
}
