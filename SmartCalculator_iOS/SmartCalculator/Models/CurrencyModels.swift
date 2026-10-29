import Foundation

/// A snapshot of exchange rates. All rates are "units of currency per 1 unit of `base`".
struct ExchangeRates: Codable, Equatable {
    /// Currency every rate is relative to (the API is asked for USD).
    let base: String
    /// e.g. ["USD": 1, "INR": 83.2, "EUR": 0.92]
    let rates: [String: Double]
    /// When the provider says the rates were produced (may be nil if not supplied).
    let providerUpdated: Date?
    /// When this app downloaded the rates.
    let fetchedAt: Date

    /// How many `to` units one `from` unit buys. Returns nil if either currency is unknown.
    func rate(from: String, to: String) -> Double? {
        guard let fromRate = rate(for: from), let toRate = rate(for: to), fromRate > 0 else { return nil }
        return toRate / fromRate
    }

    /// Converts an amount. Returns nil if the pair is unknown.
    func convert(_ amount: Double, from: String, to: String) -> Double? {
        guard let rate = rate(from: from, to: to) else { return nil }
        return amount * rate
    }

    var availableCodes: [String] { rates.keys.sorted() }

    private func rate(for code: String) -> Double? {
        if let value = rates[code] { return value }
        return code == base ? 1 : nil
    }
}

/// Everything that can go wrong while fetching rates, with a friendly message for each.
enum CurrencyServiceError: LocalizedError, Equatable {
    case invalidURL
    case missingAPIKey
    case noConnection
    case timedOut
    case cancelled
    case rateLimited
    case badStatus(Int)
    case apiError(String)
    case invalidResponse
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The exchange-rate service address is invalid."
        case .missingAPIKey: return "This exchange-rate provider needs an API key. See the README for setup."
        case .noConnection: return "No internet connection. Check your network and try again."
        case .timedOut: return "The request timed out. Please try again."
        case .cancelled: return "The request was cancelled."
        case .rateLimited: return "The exchange-rate provider is limiting requests. Please try again in about 20 minutes."
        case .badStatus(let code): return "The exchange-rate server returned an error (HTTP \(code))."
        case .apiError(let message): return "The exchange-rate provider reported an error: \(message)."
        case .invalidResponse: return "The exchange-rate response could not be understood."
        case .network(let message): return "A network error occurred: \(message)"
        }
    }
}

/// Currencies shown first in the picker.
enum CurrencyCatalog {
    static let popularCodes = ["INR", "USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CNY", "AED", "SGD"]

    /// Human readable name from the device's locale data, falling back to the code itself.
    static func name(for code: String, locale: Locale = .current) -> String {
        locale.localizedString(forCurrencyCode: code) ?? code
    }
}
