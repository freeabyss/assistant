import AppKit
import SwiftUI

struct SearchPanelView: View {
    @ObservedObject var viewModel: SearchPanelViewModel

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, viewModel.hasQuery ? 10 : 18)

            if viewModel.hasQuery {
                resultsList
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            } else {
                emptyState
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 22)
            }
        }
        .frame(width: 640, height: viewModel.hasQuery ? 560 : 156)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.98))
                .shadow(color: Color.black.opacity(0.28), radius: 28, y: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .background(
            KeyEventHandler(
                onUpArrow: { viewModel.moveUp() },
                onDownArrow: { viewModel.moveDown() },
                onReturn: { viewModel.confirmSelection() },
                onEscape: { viewModel.close() },
                onTab: {}
            )
            .allowsHitTesting(false)
        )
        .onReceive(NotificationCenter.default.publisher(for: .focusSearchField)) { _ in }
        .toast(message: viewModel.toastMessage, isShowing: viewModel.showToast)
    }

    private var searchBar: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.7))

            AutoFocusTextField(
                text: $viewModel.query,
                placeholder: L10n.localized("searchPanel.placeholder")
            )
            .frame(height: 30)

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 18, height: 18)
            } else if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "return")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary.opacity(0.6))
            Text(L10n.localized("searchPanel.emptyHint"))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
            Text("ESC")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 5))
        }
    }

    private var resultsList: some View {
        Group {
            if viewModel.results.isEmpty && !viewModel.isLoading {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.45))
                    Text(L10n.localized("searchPanel.noResults"))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, result in
                                SearchPanelResultRow(
                                    result: result,
                                    isSelected: index == viewModel.selectedIndex
                                )
                                .id(result.id)
                                .onTapGesture {
                                    viewModel.select(result)
                                    Task { await viewModel.execute(result) }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: viewModel.selectedIndex) { _ in
                        if let selected = viewModel.selectedResult {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                proxy.scrollTo(selected.id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct SearchPanelResultRow: View {
    let result: SearchResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            iconView

            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(result.subtitle ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Text(result.typeLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(typeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(typeColor.opacity(0.12), in: Capsule())

            Text("⏎")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.7))
                .frame(width: 24)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(isSelected ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var iconView: some View {
        switch result.icon {
        case .appIcon(let url):
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
        case .systemSymbol(let name):
            symbolIcon(name)
        case .thumbnail, .none:
            symbolIcon("sparkles")
        }
    }

    private func symbolIcon(_ name: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(typeColor.opacity(0.14))
                .frame(width: 34, height: 34)
            Image(systemName: name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(typeColor)
        }
    }

    private var typeColor: Color {
        switch result.sourceID {
        case .app:
            return .blue
        case .command:
            return .purple
        case .calculator:
            return result.typeLabel == L10n.localized("searchPanel.type.convert") ? .pink : .green
        case .settings:
            return .indigo
        case .clipboard:
            return .orange
        default:
            return .secondary
        }
    }
}

#Preview {
    SearchPanelView(viewModel: SearchPanelViewModel(searchService: SearchService(sources: [])))
}
