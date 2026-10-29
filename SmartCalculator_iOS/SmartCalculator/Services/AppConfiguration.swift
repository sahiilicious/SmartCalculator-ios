import Foundation

/// Central place for settings you may want to change.
enum AppConfiguration {
    /// Which exchange-rate API the currency converter uses.
    ///
    /// Default: ExchangeRate-API Open Access (no API key needed).
    /// To use your own key instead, replace it with:
    ///     CurrencyAPIConfiguration.keyed("YOUR_API_KEY")
    /// (See README.md → "Currency API setup".)
    static let currencyAPI: CurrencyAPIConfiguration = .openAccess

    /// Currency all provider rates are requested in. One request returns every pair.
    static let currencyBase = "USD"

    /// Rates fetched less than this long ago are not downloaded again automatically
    /// (the provider only publishes new rates once per day).
    static let ratesFreshnessInterval: TimeInterval = 60 * 60

    /// Manual refresh is ignored if the last download is more recent than this
    /// (protects against the provider's rate limit).
    static let minimumRefreshInterval: TimeInterval = 5 * 60

    static let attributionText = "Rates By Exchange Rate API"
    static let attributionURL = "https://www.exchangerate-api.com"
}
