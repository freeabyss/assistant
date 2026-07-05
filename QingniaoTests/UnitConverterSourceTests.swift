import XCTest
@testable import SnapVault

final class UnitConverterSourceTests: XCTestCase {
    func testConvertsCentimetersToInches() async throws {
        let source = CalculatorSource()

        let results = await source.search(query: "10 cm to inch")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].typeLabel, "Convert")
        XCTAssertEqual(results[0].title, "3.937008 in")
        if case .copyText(let value) = results[0].primaryAction {
            XCTAssertEqual(value, "3.937008 in")
        } else {
            XCTFail("Unit conversion should copy the converted value")
        }
    }

    func testConvertsKilogramsToPounds() async throws {
        let source = CalculatorSource()

        let results = await source.search(query: "100 kg to lb")

        XCTAssertEqual(results.first?.title, "220.462262 lb")
    }

    func testConvertsDataSizeUnits() async throws {
        let source = CalculatorSource()

        let decimal = await source.search(query: "1 GB to MB")
        let binary = await source.search(query: "1 GiB to MiB")

        XCTAssertEqual(decimal.first?.title, "1000 MB")
        XCTAssertEqual(binary.first?.title, "1024 MiB")
    }

    func testConvertsCelsiusToFahrenheitAndKelvin() async throws {
        let source = CalculatorSource()

        let fahrenheit = await source.search(query: "100 c to f")
        let kelvin = await source.search(query: "100 °C to K")

        XCTAssertEqual(fahrenheit.first?.title, "212 °F")
        XCTAssertEqual(kelvin.first?.title, "373.15 K")
    }

    func testRejectsCurrencyVolumeDurationUnknownAndMissingTargetUnit() async throws {
        let source = CalculatorSource()

        let currencyResults = await source.search(query: "100 usd to cny")
        let volumeResults = await source.search(query: "1 l to ml")
        let durationResults = await source.search(query: "1 h to min")
        let unknownUnitResults = await source.search(query: "100 widgets to kg")
        let missingTargetResults = await source.search(query: "100 cm")

        XCTAssertTrue(currencyResults.isEmpty)
        XCTAssertTrue(volumeResults.isEmpty)
        XCTAssertTrue(durationResults.isEmpty)
        XCTAssertTrue(unknownUnitResults.isEmpty)
        XCTAssertTrue(missingTargetResults.isEmpty)
    }

    func testLegacyUnitConverterWrapperOnlyReturnsConversionResults() async throws {
        let source = UnitConverterSource()

        let conversion = try await source.search(query: "1 m to cm", limit: 5)
        let expression = try await source.search(query: "1 + 2", limit: 5)

        XCTAssertEqual(conversion.count, 1)
        XCTAssertEqual(conversion[0].type, .unitConversion)
        XCTAssertEqual(conversion[0].title, "100 cm")
        XCTAssertTrue(expression.isEmpty)
    }
}
