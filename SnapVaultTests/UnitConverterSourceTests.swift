import XCTest
@testable import SnapVault

final class UnitConverterSourceTests: XCTestCase {
    func testConvertsCentimetersToCommonLengthUnits() async throws {
        let source = UnitConverterSource()

        let results = try await source.search(query: "100 cm", limit: 10)

        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.type == .unitConversion })
        XCTAssertTrue(results.contains { result in
            if case .copyText(let value) = result.action {
                return value == "1 m"
            }
            return false
        })
    }

    func testConvertsKilogramsToPounds() async throws {
        let source = UnitConverterSource()

        let results = try await source.search(query: "100 kg", limit: 10)

        // Foundation Measurement: 100 kg → 220.4624 lb (4-decimal formatter drops trailing zeros)
        XCTAssertTrue(results.contains { result in
            if case .copyText(let value) = result.action {
                return value == "220.4624 lb"
            }
            return false
        })
    }

    func testConvertsCelsiusToFahrenheitAndKelvin() async throws {
        let source = UnitConverterSource()

        let results = try await source.search(query: "100 c", limit: 10)
        let copiedValues = results.compactMap { result -> String? in
            if case .copyText(let value) = result.action { return value }
            return nil
        }

        XCTAssertTrue(copiedValues.contains("212 °F"))
        XCTAssertTrue(copiedValues.contains("373.15 K"))
    }

    func testConvertsUSDCurrencyUsingStaticRates() async throws {
        let source = UnitConverterSource()

        let results = try await source.search(query: "100 usd", limit: 10)

        XCTAssertTrue(results.contains { result in
            if case .copyText(let value) = result.action {
                return value == "725 CNY"
            }
            return false
        })
    }

    func testUnknownUnitReturnsNoResults() async throws {
        let source = UnitConverterSource()

        let results = try await source.search(query: "100 widgets", limit: 10)

        XCTAssertTrue(results.isEmpty)
    }
}
