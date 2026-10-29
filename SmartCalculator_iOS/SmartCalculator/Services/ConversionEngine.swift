import Foundation

/// Problems that can occur during a unit conversion.
enum ConversionError: LocalizedError, Equatable {
    case invalidNumber
    case negativeNotAllowed
    case outOfRange
    case belowAbsoluteZero
    case overflow
    case unknownUnit

    var errorDescription: String? {
        switch self {
        case .invalidNumber: return "Enter a valid number."
        case .negativeNotAllowed: return "This quantity cannot be negative."
        case .outOfRange: return "That number is too large. Use a value below 1,000,000,000,000,000."
        case .belowAbsoluteZero: return "That temperature is below absolute zero (−273.15 °C)."
        case .overflow: return "The result is too large to display."
        case .unknownUnit: return "That unit is not supported."
        }
    }
}

/// One reusable engine converts every category, so formulas are never duplicated in the UI.
///
/// * Linear categories (length, mass, volume, speed, angle, area):
///   `result = value × (fromFactor ÷ toFactor)` — convert to the base unit, then to the target.
/// * Temperature uses real formulas (offset + scale), via Celsius as the middle step.
enum ConversionEngine {
    /// Largest absolute input accepted.
    static let maxInputMagnitude = Decimal(1_000_000_000_000_000)
    private static let absoluteZeroCelsius = Decimal.exact("-273.15")

    static func convert(_ value: Decimal,
                        from: ConversionUnit,
                        to: ConversionUnit,
                        category: ConversionCategory) throws -> Decimal {
        guard !value.isNaN else { throw ConversionError.invalidNumber }
        guard abs(value) <= maxInputMagnitude else { throw ConversionError.outOfRange }
        if value < 0 && !category.allowsNegativeValues { throw ConversionError.negativeNotAllowed }

        let result: Decimal
        if category == .temperature {
            result = try convertTemperature(value, from: from.id, to: to.id)
        } else {
            guard from.factor != 0, to.factor != 0 else { throw ConversionError.unknownUnit }
            result = value * from.factor / to.factor
        }
        guard !result.isNaN else { throw ConversionError.overflow }
        return result
    }

    // MARK: Temperature

    /// Formulas:
    /// * °F → °C: (F − 32) × 5 ÷ 9        * °C → °F: C × 9 ÷ 5 + 32
    /// * K → °C: K − 273.15               * °C → K: C + 273.15
    static func convertTemperature(_ value: Decimal, from: String, to: String) throws -> Decimal {
        let celsius: Decimal
        switch from {
        case "c": celsius = value
        case "f": celsius = (value - 32) * 5 / 9
        case "k": celsius = value - Decimal.exact("273.15")
        default: throw ConversionError.unknownUnit
        }

        // Nothing can be colder than absolute zero.
        guard celsius >= absoluteZeroCelsius else { throw ConversionError.belowAbsoluteZero }

        switch to {
        case "c": return celsius
        case "f": return celsius * 9 / 5 + 32
        case "k": return celsius + Decimal.exact("273.15")
        default: throw ConversionError.unknownUnit
        }
    }
}
