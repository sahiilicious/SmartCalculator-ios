import Foundation

extension Decimal {
    /// Locale used for parsing constants written in source code (always "." as decimal point).
    private static let posix = Locale(identifier: "en_US_POSIX")

    /// Builds a `Decimal` from a string such as "0.3048" without the binary rounding errors
    /// that a Swift floating-point literal would introduce. Returns 0 if the string is invalid
    /// (the unit tests make sure no conversion factor is accidentally 0).
    static func exact(_ text: String) -> Decimal {
        Decimal(string: text, locale: posix) ?? 0
    }

    /// Plain, locale-independent text such as "1234.5" (used internally, never for display).
    var plainString: String {
        NSDecimalNumber(decimal: self).description(withLocale: Decimal.posix)
    }

    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }

    /// Rounds to a number of digits after the decimal point.
    /// A negative `places` rounds to tens, hundreds, ...
    func rounded(toPlaces places: Int, mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, places, mode)
        return result
    }

    /// Rounds to a number of significant digits (e.g. 12). Used to hide tiny math noise.
    func rounded(toSignificantDigits digits: Int) -> Decimal {
        guard !isNaN, self != 0, digits > 0 else { return self }
        let magnitude = abs(doubleValue)
        guard magnitude.isFinite, magnitude > 0 else { return self }
        let exponent = Int(floor(log10(magnitude)))
        return rounded(toPlaces: digits - 1 - exponent)
    }
}
