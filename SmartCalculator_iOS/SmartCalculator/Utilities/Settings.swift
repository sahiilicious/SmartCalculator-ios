import SwiftUI
import UIKit

/// Keys used for values stored in `UserDefaults` / `@AppStorage`.
enum SettingsKeys {
    static let appearance = "settings.appearance"
    static let haptics = "settings.hapticsEnabled"
    static let currencyFrom = "currency.fromCode"
    static let currencyTo = "currency.toCode"
    static let calculatorHistory = "calculator.history.v1"

    /// Key that remembers the last "from" unit for a converter category.
    static func unitFrom(_ category: ConversionCategory) -> String { "units.\(category.rawValue).from" }
    /// Key that remembers the last "to" unit for a converter category.
    static func unitTo(_ category: ConversionCategory) -> String { "units.\(category.rawValue).to" }
}

/// Light / dark / follow-the-system choice shown in Settings.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// `nil` means "follow the device setting".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Tiny wrapper around UIKit haptics so views stay simple.
enum Haptics {
    static var isEnabled: Bool {
        (UserDefaults.standard.object(forKey: SettingsKeys.haptics) as? Bool) ?? true
    }

    static func tap() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
