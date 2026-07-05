import SwiftUI

/// A grouped section of search results with a type header and result rows.
///
/// Displays a header with type icon, type name, and count badge,
/// followed by a list of UnifiedResultRow items.
struct ResultGroupView: View {
    let type: SearchResultType
    let results: [UnifiedSearchResult]
    let selectedResult: UnifiedSearchResult?
    let onResultTap: (UnifiedSearchResult) -> Void

    var body: some View {
        if results.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 2) {
                // Group header
                groupHeader
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                    .padding(.bottom, 2)

                // Result rows
                ForEach(results) { result in
                    UnifiedResultRow(
                        result: result,
                        isSelected: selectedResult?.id == result.id
                    )
                        .onTapGesture {
                            onResultTap(result)
                        }
                }
            }
        }
    }

    // MARK: - Group Header

    private var groupHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: type.iconName)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text(type.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            Text("\(results.count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.5))
                .cornerRadius(8)

            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: type.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary.opacity(0.4))
                Text(L10n.localized("search.noResults", type.displayName))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }
}
