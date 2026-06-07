import Foundation
import AppKit
import os.log

/// Search source that converts a numeric quantity with a unit into a small
/// list of common target units. Supports length, mass, temperature, volume,
/// duration (via Foundation Measurement) and a hand-rolled currency table.
///
/// Input grammar (regex): `^\s*(-?\d+(?:\.\d+)?)\s*([a-zA-Z°]+)\s*$`
/// — a number (optional sign, optional decimal) followed by an alphabetic unit
/// token. Unit matching is case-insensitive.
///
/// For each unit family we pre-define 3-5 common target units (excluding the
/// source unit itself). Each conversion is returned as one `UnifiedSearchResult`
/// whose `.copyText(...)` action copies the converted numeric value (with
/// unit suffix) to the pasteboard when the user hits Enter.
///
/// Currency rates are static reference values (not live FX). Currency results
/// carry a subtitle suffix that explicitly states this.
///
/// If the input does not parse, or the unit token is unknown, the source
/// silently returns `[]` so it does not pollute other search results.
final class UnitConverterSource: SearchSource {
    let sourceType: SearchResultType = .unitConversion
    private let logger = Logger.search

    // MARK: - Input Parser

    /// Matches: optional sign, integer, optional decimal, whitespace, unit token (letters + °).
    private static let inputRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        return try! NSRegularExpression(pattern: #"^\s*(-?\d+(?:\.\d+)?)\s*([a-zA-Z°]+)\s*$"#)
    }()

    /// Number formatter for output values (up to 4 fractional digits, no
    /// grouping separator, drops trailing zeros).
    private static let resultFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 4
        return f
    }()

    // MARK: - SearchSource

    func search(query: String, limit: Int) async throws -> [UnifiedSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard let (value, unitToken) = parse(trimmed) else { return [] }

        // Dispatch on unit family.
        if let lengthUnit = Self.lengthUnit(for: unitToken) {
            let targets = Self.lengthTargets(excluding: lengthUnit)
            return makeResults(
                familyName: L10n.localized("unit.length") + " " + "长度",
                originalInput: trimmed,
                value: value,
                sourceUnit: lengthUnit,
                sourceToken: unitToken,
                targets: targets
            )
        }
        if let massUnit = Self.massUnit(for: unitToken) {
            let targets = Self.massTargets(excluding: massUnit)
            return makeResults(
                familyName: L10n.localized("unit.mass") + " " + "质量",
                originalInput: trimmed,
                value: value,
                sourceUnit: massUnit,
                sourceToken: unitToken,
                targets: targets
            )
        }
        if let tempUnit = Self.temperatureUnit(for: unitToken) {
            let targets = Self.temperatureTargets(excluding: tempUnit)
            return makeResults(
                familyName: L10n.localized("unit.temperature") + " " + "温度",
                originalInput: trimmed,
                value: value,
                sourceUnit: tempUnit,
                sourceToken: unitToken,
                targets: targets
            )
        }
        if let volumeUnit = Self.volumeUnit(for: unitToken) {
            let targets = Self.volumeTargets(excluding: volumeUnit)
            return makeResults(
                familyName: L10n.localized("unit.volume") + " " + "体积",
                originalInput: trimmed,
                value: value,
                sourceUnit: volumeUnit,
                sourceToken: unitToken,
                targets: targets
            )
        }
        if let durationUnit = Self.durationUnit(for: unitToken) {
            let targets = Self.durationTargets(excluding: durationUnit)
            return makeResults(
                familyName: L10n.localized("unit.duration") + " " + "时间",
                originalInput: trimmed,
                value: value,
                sourceUnit: durationUnit,
                sourceToken: unitToken,
                targets: targets
            )
        }
        if let currencyCode = Self.currencyCode(for: unitToken) {
            return makeCurrencyResults(
                originalInput: trimmed,
                value: value,
                sourceCode: currencyCode
            )
        }

        _ = limit  // each unit produces a fixed small number of targets; limit is irrelevant
        return []
    }

    // MARK: - Parser

    private func parse(_ input: String) -> (Double, String)? {
        let range = NSRange(input.startIndex..., in: input)
        guard let match = Self.inputRegex.firstMatch(in: input, options: [], range: range),
              match.numberOfRanges >= 3 else {
            return nil
        }
        guard let numberRange = Range(match.range(at: 1), in: input),
              let unitRange = Range(match.range(at: 2), in: input) else {
            return nil
        }
        let numberStr = String(input[numberRange])
        let unitStr = String(input[unitRange]).lowercased()
        guard let value = Double(numberStr) else { return nil }
        return (value, unitStr)
    }

    // MARK: - Unit Family Dispatch

    /// Build conversion results for non-currency families using Measurement.
    private func makeResults<U: Dimension>(
        familyName: String,
        originalInput: String,
        value: Double,
        sourceUnit: U,
        sourceToken: String,
        targets: [U]
    ) -> [UnifiedSearchResult] {
        let measurement = Measurement(value: value, unit: sourceUnit)

        var results: [UnifiedSearchResult] = []
        for (index, target) in targets.enumerated() {
            let converted = measurement.converted(to: target)
            let convertedValue = converted.value
            // Skip non-finite / NaN.
            guard convertedValue.isFinite else { continue }

            let displayValue = Self.resultFormatter.string(from: NSNumber(value: convertedValue))
                ?? "\(convertedValue)"
            let targetSymbol = target.symbol
            let title = L10n.localized("unit.result.format", originalInput, displayValue, targetSymbol)
            let subtitle = L10n.localized("unit.result.subtitle", familyName, sourceUnit.symbol, targetSymbol)

            let icon = NSImage(systemSymbolName: "arrow.left.arrow.right",
                               accessibilityDescription: "Convert")
            icon?.size = NSSize(width: 24, height: 24)

            let result = UnifiedSearchResult(
                id: "unitconvert:\(sourceToken):\(targetSymbol):\(index)",
                title: title,
                subtitle: subtitle,
                icon: icon,
                type: .unitConversion,
                score: 1.0 - Double(index) * 0.05, // mild ranking by listing order
                highlightRanges: [],
                action: .copyText("\(displayValue) \(targetSymbol)")
            )
            results.append(result)
        }

        logger.info("UnitConverter '\(originalInput, privacy: .public)' produced \(results.count) results")
        return results
    }

    /// Build currency conversion results using a static rate table (USD-based).
    private func makeCurrencyResults(
        originalInput: String,
        value: Double,
        sourceCode: String
    ) -> [UnifiedSearchResult] {
        guard let sourceRate = Self.currencyRates[sourceCode] else { return [] }
        // value (sourceCode) -> USD = value / sourceRate
        let valueInUSD = value / sourceRate

        var results: [UnifiedSearchResult] = []
        let targets = Self.currencyRates.keys.filter { $0 != sourceCode }.sorted {
            Self.currencyDisplayOrder($0) < Self.currencyDisplayOrder($1)
        }

        for (index, target) in targets.enumerated() {
            guard let targetRate = Self.currencyRates[target] else { continue }
            let converted = valueInUSD * targetRate
            guard converted.isFinite else { continue }

            let displayValue = Self.resultFormatter.string(from: NSNumber(value: converted))
                ?? "\(converted)"
            let title = L10n.localized("unit.result.format", originalInput.uppercased(), displayValue, target)
            let subtitle = L10n.localized("unit.currency.result.subtitle", Self.currencyName(sourceCode), Self.currencyName(target))

            let icon = NSImage(systemSymbolName: "dollarsign.circle",
                               accessibilityDescription: "Currency")
            icon?.size = NSSize(width: 24, height: 24)

            let result = UnifiedSearchResult(
                id: "unitconvert:currency:\(sourceCode):\(target):\(index)",
                title: title,
                subtitle: subtitle,
                icon: icon,
                type: .unitConversion,
                score: 1.0 - Double(index) * 0.05,
                highlightRanges: [],
                action: .copyText("\(displayValue) \(target)")
            )
            results.append(result)
        }

        logger.info("UnitConverter currency '\(originalInput, privacy: .public)' produced \(results.count) results")
        return results
    }

    // MARK: - Unit Tables

    /// Length unit mapping. Accepts common abbreviations (mm/cm/m/km/in/inch/ft/feet/mi/mile).
    private static func lengthUnit(for token: String) -> UnitLength? {
        switch token {
        case "mm": return .millimeters
        case "cm": return .centimeters
        case "m":  return .meters
        case "km": return .kilometers
        case "in", "inch", "inches": return .inches
        case "ft", "feet", "foot": return .feet
        case "yd", "yard", "yards": return .yards
        case "mi", "mile", "miles": return .miles
        default: return nil
        }
    }

    /// Mass unit mapping (g/kg/lb/lbs/oz/ton).
    private static func massUnit(for token: String) -> UnitMass? {
        switch token {
        case "mg": return .milligrams
        case "g":  return .grams
        case "kg": return .kilograms
        case "lb", "lbs", "pound", "pounds": return .pounds
        case "oz", "ounce", "ounces": return .ounces
        case "ton", "tons", "t": return .metricTons
        default: return nil
        }
    }

    /// Temperature unit mapping (c/f/k/°C/°F). Note `°` may have been
    /// stripped by the parser if the token was just `°c`; we handle both.
    private static func temperatureUnit(for token: String) -> UnitTemperature? {
        // The regex captures `°` together with letters, so tokens like "°c" reach here lowercased.
        switch token {
        case "c", "°c", "celsius": return .celsius
        case "f", "°f", "fahrenheit": return .fahrenheit
        case "k", "kelvin": return .kelvin
        default: return nil
        }
    }

    /// Volume unit mapping (ml/l/gal/gallon).
    private static func volumeUnit(for token: String) -> UnitVolume? {
        switch token {
        case "ml": return .milliliters
        case "l", "liter", "liters", "litre", "litres": return .liters
        case "gal", "gallon", "gallons": return .gallons
        case "cup", "cups": return .cups
        case "floz", "fl_oz": return .fluidOunces
        default: return nil
        }
    }

    /// Duration unit mapping (s/min/h/hour/day).
    private static func durationUnit(for token: String) -> UnitDuration? {
        switch token {
        case "s", "sec", "second", "seconds": return .seconds
        case "min", "mins", "minute", "minutes": return .minutes
        case "h", "hr", "hour", "hours": return .hours
        default: return nil
        }
    }

    /// Currency code lookup (case-insensitive token → ISO code present in rate table).
    private static func currencyCode(for token: String) -> String? {
        let upper = token.uppercased()
        return currencyRates.keys.contains(upper) ? upper : nil
    }

    // MARK: - Target Selection

    private static func lengthTargets(excluding source: UnitLength) -> [UnitLength] {
        let candidates: [UnitLength] = [
            .millimeters, .centimeters, .meters, .kilometers,
            .inches, .feet, .miles
        ]
        return Array(candidates.filter { $0.symbol != source.symbol }.prefix(5))
    }

    private static func massTargets(excluding source: UnitMass) -> [UnitMass] {
        let candidates: [UnitMass] = [
            .grams, .kilograms, .pounds, .ounces, .metricTons
        ]
        return Array(candidates.filter { $0.symbol != source.symbol }.prefix(5))
    }

    private static func temperatureTargets(excluding source: UnitTemperature) -> [UnitTemperature] {
        let candidates: [UnitTemperature] = [.celsius, .fahrenheit, .kelvin]
        return Array(candidates.filter { $0.symbol != source.symbol }.prefix(5))
    }

    private static func volumeTargets(excluding source: UnitVolume) -> [UnitVolume] {
        let candidates: [UnitVolume] = [
            .milliliters, .liters, .gallons, .cups, .fluidOunces
        ]
        return Array(candidates.filter { $0.symbol != source.symbol }.prefix(5))
    }

    private static func durationTargets(excluding source: UnitDuration) -> [UnitDuration] {
        let candidates: [UnitDuration] = [.seconds, .minutes, .hours]
        return Array(candidates.filter { $0.symbol != source.symbol }.prefix(5))
    }

    // MARK: - Currency Rate Table (Static)

    /// Static reference exchange rates (relative to USD = 1.0).
    /// NOT live FX. Refresh manually when needed.
    static let currencyRates: [String: Double] = [
        "USD": 1.0,
        "CNY": 7.25,
        "EUR": 0.92,
        "JPY": 151.0,
        "GBP": 0.79,
        "HKD": 7.82
    ]

    /// Stable ordering for currency display.
    private static func currencyDisplayOrder(_ code: String) -> Int {
        switch code {
        case "USD": return 0
        case "CNY": return 1
        case "EUR": return 2
        case "JPY": return 3
        case "GBP": return 4
        case "HKD": return 5
        default: return 99
        }
    }

    private static func currencyName(_ code: String) -> String {
        switch code {
        case "USD": return "美元 USD"
        case "CNY": return "人民币 CNY"
        case "EUR": return "欧元 EUR"
        case "JPY": return "日元 JPY"
        case "GBP": return "英镑 GBP"
        case "HKD": return "港币 HKD"
        default: return code
        }
    }
}
