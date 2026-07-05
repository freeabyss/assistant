import AppKit
import XCTest
@testable import Qingniao

final class CalculatorSourceTests: XCTestCase {
    func testEvaluatesArithmeticExpressionWithPrecedenceAndDecimals() async throws {
        let source = CalculatorSource()

        let results = await source.search(query: "888*0.8")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].sourceID, .calculator)
        XCTAssertEqual(results[0].title, "= 710.4")
        XCTAssertEqual(results[0].typeLabel, "Calculator")
        if case .copyText(let value) = results[0].primaryAction {
            XCTAssertEqual(value, "710.4")
        } else {
            XCTFail("Calculator result should copy the formatted result")
        }
    }

    func testEvaluatesParenthesesAndUnaryOperators() async throws {
        let source = CalculatorSource()

        let results = await source.search(query: "(1.5 + 2.5) * -3")

        XCTAssertEqual(results.first?.title, "= -12")
    }

    func testRejectsPlainTextAndSignedNumberWithoutOperator() async throws {
        let source = CalculatorSource()

        let textResults = await source.search(query: "chrome")
        let signedNumberResults = await source.search(query: "-5")

        XCTAssertTrue(textResults.isEmpty)
        XCTAssertTrue(signedNumberResults.isEmpty)
    }

    func testRejectsInvalidExpressionsAndDivisionByZero() async throws {
        let source = CalculatorSource()

        let directDivisionByZero = await source.search(query: "1/0")
        let nestedDivisionByZero = await source.search(query: "1/(2-2)")
        let invalidOperator = await source.search(query: "1++")
        let unbalancedParentheses = await source.search(query: "(1+2")

        XCTAssertTrue(directDivisionByZero.isEmpty)
        XCTAssertTrue(nestedDivisionByZero.isEmpty)
        XCTAssertTrue(invalidOperator.isEmpty)
        XCTAssertTrue(unbalancedParentheses.isEmpty)
    }

    func testRejectsFunctionsVariablesCurrencyAndHistoryLikeInput() async throws {
        let source = CalculatorSource()

        let functionResults = await source.search(query: "sin(1)")
        let variableResults = await source.search(query: "a + 1")
        let currencyResults = await source.search(query: "100 usd to cny")
        let historyResults = await source.search(query: "history")

        XCTAssertTrue(functionResults.isEmpty)
        XCTAssertTrue(variableResults.isEmpty)
        XCTAssertTrue(currencyResults.isEmpty)
        XCTAssertTrue(historyResults.isEmpty)
    }

    func testLooksLikeExpressionGate() {
        XCTAssertTrue(CalculatorSource.looksLikeExpression("1 + 2"))
        XCTAssertTrue(CalculatorSource.looksLikeExpression("(2.5 + 1) / 7"))
        XCTAssertFalse(CalculatorSource.looksLikeExpression("2^10"))
        XCTAssertFalse(CalculatorSource.looksLikeExpression("100 usd"))
        XCTAssertFalse(CalculatorSource.looksLikeExpression("+3"))
    }

    func testLegacyUnifiedSearchCompatibility() async throws {
        let source = CalculatorSource()

        let results = try await source.search(query: "1 + 2", limit: 5)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].type, .calculator)
        XCTAssertEqual(results[0].title, "= 3")
        if case .copyText(let value) = results[0].action {
            XCTAssertEqual(value, "3")
        } else {
            XCTFail("Legacy result should copy text")
        }
    }

    @MainActor
    func testSearchServiceExecuteCopiesTextForEnterAction() async throws {
        let service = SearchService(sources: [CalculatorSource()])
        let response = await service.search(query: "40 + 2")
        guard let action = response.results.first?.primaryAction else {
            return XCTFail("Expected calculator result")
        }

        let executeResponse = try await service.execute(action)

        XCTAssertTrue(executeResponse.shouldCloseSearchPanel)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "42")
    }
}
