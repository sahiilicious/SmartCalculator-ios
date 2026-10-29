import Foundation

/// All number -> text formatting lives here so every screen looks consistent.
enum NumberFormatting {

    // MARK: - Decimal values (calculator + unit converters)

    /// Formats a value for the calculator display: at most 10 decimals, grouping separators,
    /// scientific notation for very large / very small numbers.
    static func calculatorString(_ value: Decimal, locale: Locale = .current) -> String {
        display(value, significantDigits: nil, maxFractionDigits: 10, locale: locale)
    }

    /// Formats a conversion result with `digits` significant digits (default 12).
    static func converterString(_ value: Decimal, digits: Int = 12, locale: Locale = .current) -> String {
        display(value, significantDigits: digits, maxFractionDigits: 10, locale: locale)
    }

    /// Core formatter.
    /// - Parameter significantDigits: when set, rounds to that many significant digits;
    ///   otherwise rounds to `maxFractionDigits` decimals.
    static func display(_ value: Decimal,
                        significantDigits: Int?,
                        maxFractionDigits: Int,
                        locale: Locale = .current) -> String {
        guard !value.isNaN else { return "—" }

        let rounded: Decimal
        if let digits = significantDigits {
            rounded = value.rounded(toSignificantDigits: digits)
        } else {
            rounded = value.rounded(toPlaces: maxFractionDigits)
        }
        if rounded == 0 { return "0" }

        let magnitude = abs(rounded.doubleValue)
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.roundingMode = .halfUp

        if magnitude >= 1e15 || magnitude < 1e-6 {
            // Too big / small for a readable plain number -> scientific notation, e.g. 1.2345E-7
            formatter.numberStyle = .scientific
            formatter.usesSignificantDigits = true
            formatter.minimumSignificantDigits = 1
            formatter.maximumSignificantDigits = 8
        } else {
            formatter.numberStyle = .decimal
            formatter.usesGroupingSeparator = true
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 20
        }

        let text = formatter.string(from: NSDecimalNumber(decimal: rounded)) ?? rounded.plainString
        return removeNegativeZero(text)
    }

    // MARK: - Text being typed in the calculator

    /// Adds grouping separators to the number the user is typing while keeping a trailing
    /// decimal point or trailing zeros ("1234." -> "1,234.", "0.50" -> "0.50").
    static func entryString(_ entry: String, locale: Locale = .current) -> String {
        guard !entry.isEmpty else { return "0" }
        let isNegative = entry.hasPrefix("-")
        let body = isNegative ? String(entry.dropFirst()) : entry
        let parts = body.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let integerDigits = String(parts.first ?? "0")

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 0
        let integerValue = Decimal.exact(integerDigits.isEmpty ? "0" : integerDigits)
        var text = formatter.string(from: NSDecimalNumber(decimal: integerValue)) ?? integerDigits

        if parts.count > 1 {
            text += (locale.decimalSeparator ?? ".") + String(parts[1])
        }
        return isNegative ? "-" + text : text
    }

    // MARK: - Currency (Double based)

    /// Money-style amount: 2 decimals normally, up to 6 for tiny amounts.
    static func currencyAmount(_ value: Double, locale: Locale = .current) -> String {
        guard value.isFinite else { return "—" }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = (abs(value) >= 1 || value == 0) ? 2 : 6
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Exchange-rate style number with 6 significant digits, e.g. 83.1234 or 0.012031.
    static func rateString(_ value: Double, locale: Locale = .current) -> String {
        guard value.isFinite else { return "—" }
        return display(Decimal(value), significantDigits: 6, maxFractionDigits: 10, locale: locale)
    }

    // MARK: - Helpers

    private static func removeNegativeZero(_ text: String) -> String {
        guard text.hasPrefix("-") else { return text }
        let rest = text.dropFirst()
        let hasNonZeroDigit = rest.contains { "123456789".contains($0) }
        return hasNonZeroDigit ? text : String(rest)
    }
}

/// Result of reading a number typed in a text field.
enum InputParseResult: Equatable {
    case empty
    case invalid
    case valid(Decimal)
}

/// Strictly parses user input (respects the device's decimal separator).
enum InputParser {
    static func parse(_ text: String, locale: Locale = .current) -> InputParseResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true

        if let number = formatter.number(from: trimmed) as? NSDecimalNumber, number != NSDecimalNumber.notANumber {
            return .valid(number.decimalValue)
        }
        return .invalid
    }
}
