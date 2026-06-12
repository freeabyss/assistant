import Foundation
import AppKit
import os.log

/// Search source that evaluates math expressions typed into the Command Bar.
///
/// Holds no state. For every query it:
/// 1. Quickly rejects non-mathematical input via a regex sniff (must contain
///    at least one digit AND at least one operator).
/// 2. Hands the surviving expression to `NSExpression(format:)` for evaluation.
/// 3. Formats the numeric result with up to 10 fractional digits and strips
///    trailing zeros.
/// 4. Returns a single `UnifiedSearchResult` with `.copyText(...)` action.
///
/// Failure modes (division by zero, syntax errors, non-numeric result, ...)
/// silently return `[]` so the user simply sees no calculator row.
final class CalculatorSource: UnifiedSearchSource {
    let sourceType: SearchResultType = .calculator
    private let logger = Logger.search

    /// At least one digit (with optional decimal) AND at least one math operator
    /// or grouping symbol. Used as a cheap gate before invoking NSExpression.
    ///
    /// We allow digits, `. , + - * / ( ) % ^ ` and whitespace; anything else
    /// (letters, units, punctuation outside the set) disqualifies the input.
    private static let expressionGateRegex: NSRegularExpression = {
        // Permitted character set; if the input contains anything outside, bail.
        // Operator class includes + - * / % ^ ( )
        // swiftlint:disable:next force_try
        return try! NSRegularExpression(pattern: #"^[\s0-9\.,\+\-\*/%\^\(\)]+$"#)
    }()

    /// Result formatter: up to 10 fractional digits, no grouping separator,
    /// drops trailing zeros (e.g. 710.4 not 710.4000000000).
    private static let resultFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 10
        return f
    }()

    // MARK: - SearchSource

    func search(query: String, limit: Int) async throws -> [UnifiedSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Cheap gate: must look like a math expression (contains a digit AND an operator).
        guard Self.looksLikeExpression(trimmed) else {
            return []
        }

        // Normalize: NSExpression understands +, -, *, /, %, ( ); replace ^ with
        // pow-style isn't needed because NSExpression natively understands "**".
        // We replace single `^` with `**` for the few users who type it.
        let normalized = trimmed.replacingOccurrences(of: "^", with: "**")

        // Evaluate via NSExpression. Wrap in try-catch because malformed input
        // (e.g. "1++2", unmatched parens) throws Obj-C exceptions which are
        // not catchable in Swift; we mitigate by trapping ObjC exceptions where
        // possible and returning [] on any failure.
        guard let value = Self.safeEvaluate(expression: normalized) else {
            return []
        }

        // Reject NaN / Inf (e.g. division by zero produces .infinity here)
        guard value.isFinite else {
            return []
        }

        let formatted = Self.resultFormatter.string(from: NSNumber(value: value)) ?? "\(value)"

        let icon = NSImage(systemSymbolName: "function", accessibilityDescription: "Calculator")
        icon?.size = NSSize(width: 24, height: 24)

        let result = UnifiedSearchResult(
            id: "calculator:\(trimmed)",
            title: "= \(formatted)",
            subtitle: trimmed,
            icon: icon,
            type: .calculator,
            score: 1.0,
            highlightRanges: [],
            action: .copyText(formatted)
        )

        logger.info("Calculator '\(trimmed, privacy: .public)' = \(formatted, privacy: .public)")
        _ = limit  // single-result source; limit is irrelevant
        return [result]
    }

    // MARK: - Helpers

    /// Cheap gate: input must contain at least one digit, at least one operator,
    /// and consist entirely of characters in the math-allowed set.
    static func looksLikeExpression(_ input: String) -> Bool {
        let range = NSRange(input.startIndex..., in: input)

        // Whitelist character check
        guard expressionGateRegex.firstMatch(in: input, options: [], range: range) != nil else {
            return false
        }

        // Must contain at least one digit
        guard input.rangeOfCharacter(from: .decimalDigits) != nil else {
            return false
        }

        // Must contain at least one operator (+ - * / % ^) — parentheses alone don't count.
        // Exclude leading sign-only inputs like "-5" or "+3" (no real expression).
        let operatorSet = CharacterSet(charactersIn: "+-*/%^")
        guard let opRange = input.rangeOfCharacter(from: operatorSet) else {
            return false
        }

        // Reject inputs where the only operator is the very first character (leading sign).
        // e.g. "-5", "+3" are just signed numbers, not expressions.
        if opRange.lowerBound == input.startIndex {
            // Look for any operator past the first character
            let afterFirst = input.index(after: input.startIndex)
            if afterFirst >= input.endIndex {
                return false
            }
            let rest = input[afterFirst...]
            if rest.rangeOfCharacter(from: operatorSet) == nil {
                return false
            }
        }

        return true
    }

    /// Evaluate a numeric NSExpression and return its Double value, or nil if
    /// the expression is malformed, returns a non-numeric value, or throws.
    private static func safeEvaluate(expression: String) -> Double? {
        // NSExpression(format:) can throw Obj-C exceptions for malformed input.
        // We can't catch those from Swift directly without an ObjC bridge, so
        // we run a defensive syntactic sanity check before invoking it.
        guard isSyntacticallySafe(expression) else { return nil }

        let expr = NSExpression(format: expression)
        let value = expr.expressionValue(with: nil, context: nil)
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        return nil
    }

    /// Defensive syntactic check on the already-whitelisted expression:
    /// - balanced parentheses
    /// - no two consecutive operators (except the unary `-`/`+` after another operator or `(`)
    /// - does not start with `*`, `/`, `%`, `^`
    /// - does not end with any operator
    /// - no empty parens `()`
    /// - no `**` followed by another operator (we treat ** as exponent)
    private static func isSyntacticallySafe(_ s: String) -> Bool {
        guard balancedParens(s) else { return false }

        let stripped = s.replacingOccurrences(of: " ", with: "")
        guard !stripped.isEmpty else { return false }

        let chars = Array(stripped)
        let binaryOps: Set<Character> = ["*", "/", "%", "^"]
        let allOps: Set<Character> = ["+", "-", "*", "/", "%", "^"]

        // Cannot start with a binary-only operator
        if binaryOps.contains(chars.first!) { return false }
        // Cannot end with any operator or an opening paren
        if let last = chars.last, allOps.contains(last) || last == "(" { return false }

        for i in 0..<chars.count {
            let c = chars[i]
            // No "()"
            if c == "(", i + 1 < chars.count, chars[i + 1] == ")" { return false }
            // No operator immediately after "("  (except unary +/-)
            if c == "(", i + 1 < chars.count, binaryOps.contains(chars[i + 1]) { return false }
            // No two consecutive binary ops (allow "**", "+-", "*-", "/-" as unary follow-ups)
            if i > 0 && allOps.contains(c) && allOps.contains(chars[i - 1]) {
                let prev = chars[i - 1]
                // Permit `**` (exponent already normalized to **)
                if prev == "*" && c == "*" { continue }
                // Permit unary -/+ after a binary op or **
                if c == "-" || c == "+" { continue }
                return false
            }
        }
        return true
    }

    /// Returns true if parentheses in the string are balanced.
    private static func balancedParens(_ s: String) -> Bool {
        var depth = 0
        for ch in s {
            if ch == "(" { depth += 1 }
            if ch == ")" {
                depth -= 1
                if depth < 0 { return false }
            }
        }
        return depth == 0
    }
}
