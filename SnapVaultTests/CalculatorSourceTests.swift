import XCTest
@testable import SnapVault

final class CalculatorSourceTests: XCTestCase {
    func testEvaluatesMultiplicationExpression() async throws {
        let source = CalculatorSource()

        let results = try await source.search(query: "888*0.8", limit: 5)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].type, .calculator)
        XCTAssertEqual(results[0].title, "= 710.4")
        if case .copyText(let value) = results[0].action {
            XCTAssertEqual(value, "710.4")
        } else {
            XCTFail("Calculator result should copy the formatted result")
        }
    }

    func testRejectsPlainTextQuery() async throws {
        let source = CalculatorSource()

        let results = try await source.search(query: "chrome", limit: 5)

        XCTAssertTrue(results.isEmpty)
    }

    func testRejectsSignedNumberWithoutOperator() async throws {
        let source = CalculatorSource()

        let results = try await source.search(query: "-5", limit: 5)

        XCTAssertTrue(results.isEmpty)
    }

    func testRejectsDivisionByZero() async throws {
        let source = CalculatorSource()

        let results = try await source.search(query: "1/0", limit: 5)

        XCTAssertTrue(results.isEmpty)
    }

    func testLooksLikeExpressionGate() {
        XCTAssertTrue(CalculatorSource.looksLikeExpression("1 + 2"))
        XCTAssertTrue(CalculatorSource.looksLikeExpression("2^10"))
        XCTAssertFalse(CalculatorSource.looksLikeExpression("100 usd"))
        XCTAssertFalse(CalculatorSource.looksLikeExpression("+3"))
    }
}
