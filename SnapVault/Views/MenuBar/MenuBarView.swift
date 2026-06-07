import SwiftUI
import AppKit

/// Notification posted when the panel is shown via global shortcut,
/// requesting the search field to receive keyboard focus.
extension Notification.Name {
    static let focusSearchField = Notification.Name("SnapVault.focusSearchField")
    static let checkForUpdates = Notification.Name("SnapVault.checkForUpdates")
}

// MARK: - AutoFocusTextField

/// A custom NSTextField wrapper that can programmatically become first responder.
/// Used instead of SwiftUI's TextField for reliable keyboard focus in borderless windows.
struct AutoFocusTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.font = NSFont.systemFont(ofSize: 16)
        textField.focusRingType = .none
        textField.delegate = context.coordinator
        context.coordinator.setTextField(textField)
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: AutoFocusTextField
        var focusObserver: NSObjectProtocol?

        init(_ parent: AutoFocusTextField) {
            self.parent = parent
        }

        func setTextField(_ textField: NSTextField) {
            // Listen for focus requests
            focusObserver = NotificationCenter.default.addObserver(
                forName: .focusSearchField,
                object: nil,
                queue: .main
            ) { [weak textField] _ in
                guard let textField = textField,
                      let window = textField.window else { return }
                window.makeFirstResponder(textField)
            }
        }

        deinit {
            if let observer = focusObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
    }

    static func dismantleNSView(_ nsView: NSTextField, coordinator: Coordinator) {
        if let observer = coordinator.focusObserver {
            NotificationCenter.default.removeObserver(observer)
            coordinator.focusObserver = nil
        }
    }
}

/// Main container view shown in the floating panel.
///
/// Pure Spotlight-style: centered search box when empty, results expand below when typing.
struct MenuBarView: View {
    @ObservedObject var searchViewModel: UnifiedSearchViewModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Push search bar to center when inactive
            if !searchViewModel.isSearchActive {
                Spacer()
            }

            // Single persistent search bar (never recreated)
            searchBar
                .padding(.horizontal, searchViewModel.isSearchActive ? 16 : 40)
                .padding(.top, searchViewModel.isSearchActive ? 12 : 0)
                .padding(.bottom, searchViewModel.isSearchActive ? 8 : 0)

            // Results section (only when searching)
            if searchViewModel.isSearchActive {
                searchTimingBar

                groupFilterTabs
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)

                UnifiedResultList(viewModel: searchViewModel)

                Spacer(minLength: 0)
            }

            // Push search bar to center when inactive
            if !searchViewModel.isSearchActive {
                Spacer()
            }
        }
        .frame(width: 400, height: searchViewModel.isSearchActive ? 500 : 72)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.2), radius: 20, y: 10)
        )
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
        .toast(message: searchViewModel.toastMessage, isShowing: searchViewModel.showToast)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary.opacity(0.6))
                .font(.system(size: 16))

            AutoFocusTextField(
                text: $searchViewModel.searchText,
                placeholder: "Search..."
            )
            .frame(height: 22)

            if !searchViewModel.searchText.isEmpty {
                Button(action: {
                    searchViewModel.searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.5))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
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
        .padding(.horizontal, 20)
        .padding(.bottom, 2)
    }

    // MARK: - Group Filter Tabs

    private var groupFilterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                GroupTabButton(
                    title: "All",
                    icon: "tray",
                    count: searchViewModel.totalCount,
                    isSelected: searchViewModel.selectedGroup == nil,
                    action: { searchViewModel.selectedGroup = nil }
                )

                if !searchViewModel.calculations.isEmpty || searchViewModel.selectedGroup == .calculator {
                    GroupTabButton(
                        title: "Calculator",
                        icon: "function",
                        count: searchViewModel.calculations.count,
                        isSelected: searchViewModel.selectedGroup == .calculator,
                        action: { searchViewModel.selectedGroup = .calculator }
                    )
                }

                if !searchViewModel.conversions.isEmpty || searchViewModel.selectedGroup == .unitConversion {
                    GroupTabButton(
                        title: "Convert",
                        icon: "arrow.left.arrow.right",
                        count: searchViewModel.conversions.count,
                        isSelected: searchViewModel.selectedGroup == .unitConversion,
                        action: { searchViewModel.selectedGroup = .unitConversion }
                    )
                }

                if !searchViewModel.applications.isEmpty || searchViewModel.selectedGroup == .application {
                    GroupTabButton(
                        title: "Apps",
                        icon: "app.fill",
                        count: searchViewModel.applications.count,
                        isSelected: searchViewModel.selectedGroup == .application,
                        action: { searchViewModel.selectedGroup = .application }
                    )
                }

                if !searchViewModel.systemCommands.isEmpty || searchViewModel.selectedGroup == .systemCommand {
                    GroupTabButton(
                        title: "System",
                        icon: "gearshape",
                        count: searchViewModel.systemCommands.count,
                        isSelected: searchViewModel.selectedGroup == .systemCommand,
                        action: { searchViewModel.selectedGroup = .systemCommand }
                    )
                }

                if !searchViewModel.files.isEmpty || searchViewModel.selectedGroup == .file {
                    GroupTabButton(
                        title: "Files",
                        icon: "doc.fill",
                        count: searchViewModel.files.count,
                        isSelected: searchViewModel.selectedGroup == .file,
                        action: { searchViewModel.selectedGroup = .file }
                    )
                }

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
