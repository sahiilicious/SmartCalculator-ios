import Foundation

/// Saves the last successful download so the converter can still work offline.
protocol RateCaching {
    func load() -> ExchangeRates?
    func save(_ rates: ExchangeRates)
}

struct UserDefaultsRateCache: RateCaching {
    private let defaults: UserDefaults
    private let key = "currency.cachedRates.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ExchangeRates? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ExchangeRates.self, from: data)
    }

    func save(_ rates: ExchangeRates) {
        guard let data = try? JSONEncoder().encode(rates) else { return }
        defaults.set(data, forKey: key)
    }
}
