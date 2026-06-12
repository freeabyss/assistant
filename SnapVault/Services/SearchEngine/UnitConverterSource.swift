import Foundation

/// Legacy compatibility wrapper for unit conversion search.
///
/// Assistant MVP unit conversion now lives in `CalculatorSource` so calculation and
/// conversion share one `SearchSourceID.calculator`, one trigger rule, and one copy
/// action model. This wrapper remains only for the historical `UnifiedSearchService`
/// registration path and delegates all work to `CalculatorSource`.
final class UnitConverterSource: UnifiedSearchSource {
    let sourceType: SearchResultType = .unitConversion

    private let calculatorSource: CalculatorSource

    init(calculatorSource: CalculatorSource = CalculatorSource()) {
        self.calculatorSource = calculatorSource
    }

    func search(query: String, limit: Int) async throws -> [UnifiedSearchResult] {
        let results = try await calculatorSource.search(query: query, limit: limit)
        return results.filter { $0.type == .unitConversion }
    }
}
