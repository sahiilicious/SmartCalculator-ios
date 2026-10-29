import Foundation
import SwiftUI

/// Result of trying to convert what is currently typed.
enum ConversionOutcome: Equatable {
    case empty
    case success(Decimal)
    case failure(String)
}

/// State for one unit-converter screen (Length, Mass, Volume, ...).
@MainActor
final class UnitConverterViewModel: ObservableObject {
    let category: ConversionCategory
    private let defaults: UserDefaults
    private let locale: Locale

    @Published var inputText: String = ""
    @Published var fromUnit: ConversionUnit {
        didSet { defaults.set(fromUnit.id, forKey: SettingsKeys.unitFrom(category)) }
    }
    @Published var toUnit: ConversionUnit {
        didSet { defaults.set(toUnit.id, forKey: SettingsKeys.unitTo(category)) }
    }

    init(category: ConversionCategory,
         defaults: UserDefaults = .standard,
         locale: Locale = .current) {
        self.category = category
        self.defaults = defaults
        self.locale = locale

        let fallback = category.defaultUnitIDs
        let units = category.units
        let first = units.first ?? ConversionUnit("none", "None", "–")
        self.fromUnit = category.unit(withID: defaults.string(forKey: SettingsKeys.unitFrom(category)))
            ?? category.unit(withID: fallback.from) ?? first
        self.toUnit = category.unit(withID: defaults.string(forKey: SettingsKeys.unitTo(category)))
            ?? category.unit(withID: fallback.to) ?? first
    }

    // MARK: - Live result (recalculated whenever the input or a unit changes)

    var outcome: ConversionOutcome {
        switch InputParser.parse(inputText, locale: locale) {
        case .empty:
            return .empty
        case .invalid:
            return .failure(ConversionError.invalidNumber.localizedDescription)
        case .valid(let value):
            do {
                let result = try ConversionEngine.convert(value, from: fromUnit, to: toUnit, category: category)
                return .success(result)
            } catch {
                return .failure(error.localizedDescription)
            }
        }
    }

    /// Text shown in the result card.
    var resultText: String {
        if case .success(let value) = outcome {
            return NumberFormatting.converterString(value, locale: locale)
        }
        return "—"
    }

    var errorMessage: String? {
        if case .failure(let message) = outcome { return message }
        return nil
    }

    var hasResult: Bool {
        if case .success = outcome { return true }
        return false
    }

    /// "1 km = 0.621371192237 mi" — shows the ratio between the two selected units.
    var relationText: String? {
        guard let one = try? ConversionEngine.convert(1, from: fromUnit, to: toUnit, category: category) else {
            return nil
        }
        let value = NumberFormatting.converterString(one, locale: locale)
        return "1 \(fromUnit.symbol) = \(value) \(toUnit.symbol)"
    }

    var keyboardAllowsNegative: Bool { category.allowsNegativeValues }

    // MARK: - Actions

    func swapUnits() {
        let oldFrom = fromUnit
        fromUnit = toUnit
        toUnit = oldFrom
    }

    func reset() {
        inputText = ""
    }
}
