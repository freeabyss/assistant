import SwiftUI

/// Notification posted when the panel is shown via global shortcut,
/// requesting the search field to receive keyboard focus.
extension Notification.Name {
    static let focusSearchField = Notification.Name("SnapVault.focusSearchField")
    static let checkForUpdates = Notification.Name("SnapVault.checkForUpdates")
}

/// Main container view shown in the floating panel.
///
/// Displays a Spotlight-style search bar at the top. When the search field is empty,
/// shows clipboard history (ClipboardListView). When the user types, switches to
/// unified search results (UnifiedResultList) with grouped display.
struct MenuBarView: View {
    @ObservedObject var searchViewModel: UnifiedSearchViewModel
    @StateObject private var clipboardViewModel = ClipboardListViewModel()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header: App title + settings
            headerBar

            // Spotlight-style search bar
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // Search timing info (when searching)
            if searchViewModel.isSearchActive {
                searchTimingBar
            }

            // Group filter tabs (when searching)
            if searchViewModel.isSearchActive {
                groupFilterTabs
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            }

            // Content area: search results or clipboard history
            if searchViewModel.isSearchActive {
                UnifiedResultList(viewModel: searchViewModel)
            } else {
                ClipboardListView(viewModel: clipboardViewModel)
            }
        }
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .background(
            KeyEventHandler(
                onUpArrow: { searchViewModel.moveSelectionUp() },
                onDownArrow: { searchViewModel.moveSelectionDown() },
                onReturn: {
                    if searchViewModel.isSearchActive {
                        searchViewModel.confirmSelection()
                    }
                },
                onTab: { searchViewModel.cycleGroupForward() }
            )
            .allowsHitTesting(false)
        )
        .onReceive(NotificationCenter.default.publisher(for: .focusSearchField)) { _ in
            isSearchFocused = true
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text("SnapVault")
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            // Check for Updates button
            Button(action: requestUpdateCheck) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Check for Updates")

            // Settings button
            Button(action: openSettings) {
                Image(systemName: "gear")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open Settings")
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Spotlight-Style Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary.opacity(0.7))
                .font(.system(size: 15))

            TextField("Search apps, files, clipboard...", text: $searchViewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($isSearchFocused)

            if !searchViewModel.searchText.isEmpty {
                Button(action: {
                    searchViewModel.searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
        )
    }

    // MARK: - Search Timing Bar

    private var searchTimingBar: some View {
        HStack(spacing: 4) {
            if searchViewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
            }
            Text("\(searchViewModel.totalCount) results")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.7))
            Text("·")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.5))
            Text("\(Int(searchViewModel.elapsed))ms")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.7))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 2)
    }

    // MARK: - Group Filter Tabs

    private var groupFilterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // "All" tab
                GroupTabButton(
                    title: "All",
                    icon: "tray",
                    count: searchViewModel.totalCount,
                    isSelected: searchViewModel.selectedGroup == nil,
                    action: { searchViewModel.selectedGroup = nil }
                )

                // Application tab
                if !searchViewModel.applications.isEmpty || searchViewModel.selectedGroup == .application {
                    GroupTabButton(
                        title: "Apps",
                        icon: "app.fill",
                        count: searchViewModel.applications.count,
                        isSelected: searchViewModel.selectedGroup == .application,
                        action: { searchViewModel.selectedGroup = .application }
                    )
                }

                // File tab
                if !searchViewModel.files.isEmpty || searchViewModel.selectedGroup == .file {
                    GroupTabButton(
                        title: "Files",
                        icon: "doc.fill",
                        count: searchViewModel.files.count,
                        isSelected: searchViewModel.selectedGroup == .file,
                        action: { searchViewModel.selectedGroup = .file }
                    )
                }

                // Clipboard tab
                if !searchViewModel.clipboard.isEmpty || searchViewModel.selectedGroup == .clipboard {
                    GroupTabButton(
                        title: "Clipboard",
                        icon: "clipboard.fill",
                        count: searchViewModel.clipboard.count,
                        isSelected: searchViewModel.selectedGroup == .clipboard,
                        action: { searchViewModel.selectedGroup = .clipboard }
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func openSettings() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func requestUpdateCheck() {
        NotificationCenter.default.post(name: .checkForUpdates, object: nil)
    }
}

// MARK: - Group Tab Button

struct GroupTabButton: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MenuBarView(searchViewModel: UnifiedSearchViewModel(unifiedSearchService: UnifiedSearchService()))
}
