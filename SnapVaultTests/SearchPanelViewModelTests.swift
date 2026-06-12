import XCTest
@testable import SnapVault

@MainActor
final class SearchPanelViewModelTests: XCTestCase {
    func testEmptyInputShowsNoResults() async {
        let service = StubPanelSearchService(results: [Self.makeResult(index: 0)])
        let viewModel = SearchPanelViewModel(searchService: service)

        viewModel.query = "   "
        await viewModel.searchNow()

        let wasSearchCalled = await service.wasSearchCalled()
        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertFalse(wasSearchCalled)
    }

    func testResultsAreCappedAtTwelveAndSelectionMoves() async {
        let service = StubPanelSearchService(results: (0..<20).map(Self.makeResult(index:)))
        let viewModel = SearchPanelViewModel(searchService: service)

        viewModel.query = "a"
        await viewModel.searchNow()

        XCTAssertEqual(viewModel.results.count, 12)
        XCTAssertEqual(viewModel.selectedIndex, 0)
        viewModel.moveUp()
        XCTAssertEqual(viewModel.selectedIndex, 11)
        viewModel.moveDown()
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func testConfirmSelectionExecutesAndClosesPanel() async {
        let service = StubPanelSearchService(results: [Self.makeResult(index: 0)])
        var didClose = false
        let viewModel = SearchPanelViewModel(searchService: service) {
            didClose = true
        }

        viewModel.query = "a"
        await viewModel.searchNow()
        viewModel.confirmSelection()
        try? await Task.sleep(nanoseconds: 80_000_000)

        let executedActions = await service.actions()
        XCTAssertEqual(executedActions, [.copyText("0")])
        XCTAssertTrue(didClose)
    }

    private static func makeResult(index: Int) -> SearchResult {
        SearchResult(
            id: SearchResultID(rawValue: "test:\(index)"),
            sourceID: .settings,
            title: "Result \(index)",
            subtitle: "Subtitle",
            icon: .systemSymbol("gearshape"),
            typeLabel: "Settings",
            baseScore: 80,
            matchScore: Double(index),
            usageScore: 0,
            primaryAction: .copyText("\(index)"),
            secondaryActions: []
        )
    }
}

actor StubPanelSearchService: SearchServiceProtocol {
    private let stubResults: [SearchResult]
    private(set) var searchWasCalled = false
    private(set) var executedActions: [SearchAction] = []

    func wasSearchCalled() -> Bool { searchWasCalled }
    func actions() -> [SearchAction] { executedActions }

    init(results: [SearchResult]) {
        self.stubResults = results
    }

    func search(query: String) async -> SearchResponse {
        searchWasCalled = true
        return SearchResponse(query: query, results: stubResults, elapsed: 0.01)
    }

    func execute(_ action: SearchAction) async throws -> SearchResponse {
        executedActions.append(action)
        return SearchResponse(query: "", results: [], elapsed: 0, shouldCloseSearchPanel: true)
    }

    func recordSelection(_ result: SearchResult) async {}
}
