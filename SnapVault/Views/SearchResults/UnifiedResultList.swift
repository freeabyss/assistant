import SwiftUI

/// The main search results list that displays results grouped by type.
///
/// In "All" mode, groups are displayed in priority order: Applications -> Files -> Clipboard.
/// Each group is capped at 10 results. Supports keyboard navigation via the ViewModel.
struct UnifiedResultList: View {
    @ObservedObject var viewModel: UnifiedSearchViewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if !viewModel.hasResults {
                noResultsView
            } else {
                resultsScrollView
            }
        }
    }

    // MARK: - Results ScrollView

    private var resultsScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    if let group = viewModel.selectedGroup {
                        // Single group mode
                        ResultGroupView(
                            type: group,
                            results: viewModel.resultsForGroup(group),
                            selectedResult: viewModel.selectedResult,
                            onResultTap: { result in
                                viewModel.executeAction(for: result)
                            }
                        )
                    } else {
                        // All groups mode
                        if !viewModel.calculations.isEmpty {
                            ResultGroupView(
                                type: .calculator,
                                results: Array(viewModel.calculations.prefix(10)),
                                selectedResult: viewModel.selectedResult,
                                onResultTap: { result in
                                    viewModel.executeAction(for: result)
                                }
                            )
                        }

                        if !viewModel.conversions.isEmpty {
                            if !viewModel.calculations.isEmpty {
                                Divider()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            }
                            ResultGroupView(
                                type: .unitConversion,
                                results: Array(viewModel.conversions.prefix(10)),
                                selectedResult: viewModel.selectedResult,
                                onResultTap: { result in
                                    viewModel.executeAction(for: result)
                                }
                            )
                        }

                        if !viewModel.applications.isEmpty {
                            if !viewModel.calculations.isEmpty || !viewModel.conversions.isEmpty {
                                Divider()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            }
                            ResultGroupView(
                                type: .application,
                                results: Array(viewModel.applications.prefix(10)),
                                selectedResult: viewModel.selectedResult,
                                onResultTap: { result in
                                    viewModel.executeAction(for: result)
                                }
                            )
                        }

                        if !viewModel.systemCommands.isEmpty {
                            if !viewModel.applications.isEmpty || !viewModel.calculations.isEmpty || !viewModel.conversions.isEmpty {
                                Divider()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            }

                            ResultGroupView(
                                type: .systemCommand,
                                results: Array(viewModel.systemCommands.prefix(10)),
                                selectedResult: viewModel.selectedResult,
                                onResultTap: { result in
                                    viewModel.executeAction(for: result)
                                }
                            )
                        }

                        if !viewModel.files.isEmpty {
                            Divider()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)

                            ResultGroupView(
                                type: .file,
                                results: Array(viewModel.files.prefix(10)),
                                selectedResult: viewModel.selectedResult,
                                onResultTap: { result in
                                    viewModel.executeAction(for: result)
                                }
                            )
                        }

                        if !viewModel.clipboard.isEmpty {
                            Divider()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)

                            ResultGroupView(
                                type: .clipboard,
                                results: Array(viewModel.clipboard.prefix(10)),
                                selectedResult: viewModel.selectedResult,
                                onResultTap: { result in
                                    viewModel.executeAction(for: result)
                                }
                            )
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .onChange(of: viewModel.selectedResult?.id) { newID in
                if let id = newID {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Searching...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 40)
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary.opacity(0.4))
                Text("No results found")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 40)
    }
}
