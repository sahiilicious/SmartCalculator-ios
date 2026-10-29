import Foundation
import SwiftUI

/// State for the currency converter.
@MainActor
final class CurrencyViewModel: ObservableObject {

    /// What the converter can show for the current input.
    enum ConversionState: Equatable {
        case waitingForRates
        case empty
        case invalid(String)
        case ready(Double)
    }

    @Published var amountText: String = "1"
    @Published var fromCode: String {
        didSet { defaults.set(fromCode, forKey: SettingsKeys.currencyFrom) }
    }
    @Published var toCode: String {
        didSet { defaults.set(toCode, forKey: SettingsKeys.currencyTo) }
    }

    @Published private(set) var rates: ExchangeRates?
    @Published private(set) var isLoading = false
    /// True when the numbers on screen come from the saved copy, not from a fresh download.
    @Published private(set) var isShowingCachedRates = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var infoMessage: String?

    private let service: CurrencyServiceProtocol
    private let cache: RateCaching
    private let defaults: UserDefaults
    private let locale: Locale
    private let now: () -> Date

    init(service: CurrencyServiceProtocol = CurrencyService(),
         cache: RateCaching = UserDefaultsRateCache(),
         defaults: UserDefaults = .standard,
         locale: Locale = .current,
         now: @escaping () -> Date = Date.init) {
        self.service = service
        self.cache = cache
        self.defaults = defaults
        self.locale = locale
        self.now = now

        self.fromCode = defaults.string(forKey: SettingsKeys.currencyFrom) ?? "USD"
        self.toCode = defaults.string(forKey: SettingsKeys.currencyTo) ?? "INR"

        if let saved = cache.load() {
            self.rates = saved
            self.isShowingCachedRates = true   // until a fresh download succeeds
        }
    }

    // MARK: - Loading rates

    /// Downloads rates unless a recent download already exists.
    /// - Parameter force: set by the refresh button. Even then, a download that happened only a
    ///   few minutes ago is reused, because the provider publishes new rates once a day and
    ///   rate-limits clients that ask too often.
    func refresh(force: Bool = false) async {
        guard !isLoading else { return }
        infoMessage = nil

        if let current = rates {
            let age = now().timeIntervalSince(current.fetchedAt)
            if age < AppConfiguration.minimumRefreshInterval {
                // Downloaded moments ago: nothing to do.
                isShowingCachedRates = false
                errorMessage = nil
                if force { infoMessage = "Rates were just updated. The provider publishes new rates once a day." }
                return
            }
            if !force && age < AppConfiguration.ratesFreshnessInterval {
                // Automatic refresh (screen opened): recent enough, skip the network call.
                isShowingCachedRates = false
                errorMessage = nil
                return
            }
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fresh = try await service.fetchRates(base: AppConfiguration.currencyBase)
            rates = fresh
            cache.save(fresh)
            isShowingCachedRates = false
            normaliseSelectedCurrencies()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            // Keep whatever we had, but make it clear it is not live.
            isShowingCachedRates = (rates != nil)
        }
    }

    // MARK: - Derived values

    /// Codes that can be picked. Falls back to the popular list while nothing is loaded.
    var availableCodes: [String] {
        rates?.availableCodes ?? CurrencyCatalog.popularCodes
    }

    var conversion: ConversionState {
        guard let rates = rates else { return .waitingForRates }
        switch InputParser.parse(amountText, locale: locale) {
        case .empty:
            return .empty
        case .invalid:
            return .invalid("Enter a valid amount.")
        case .valid(let decimal):
            let amount = decimal.doubleValue
            if amount < 0 { return .invalid("The amount cannot be negative.") }
            if amount > 1e12 { return .invalid("That amount is too large.") }
            guard let converted = rates.convert(amount, from: fromCode, to: toCode) else {
                return .invalid("No rate is available for \(fromCode) → \(toCode).")
            }
            return .ready(converted)
        }
    }

    var convertedText: String {
        if case .ready(let value) = conversion { return NumberFormatting.currencyAmount(value, locale: locale) }
        return "—"
    }

    var validationMessage: String? {
        if case .invalid(let message) = conversion { return message }
        return nil
    }

    /// "1 USD = 83.2 INR"
    var rateLine: String? {
        guard let rate = rates?.rate(from: fromCode, to: toCode) else { return nil }
        return "1 \(fromCode) = \(NumberFormatting.rateString(rate, locale: locale)) \(toCode)"
    }

    /// When the provider says the rates were produced (falls back to our download time).
    var lastUpdated: Date? {
        rates?.providerUpdated ?? rates?.fetchedAt
    }

    var lastUpdatedText: String? {
        guard let date = lastUpdated else { return nil }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: - Actions

    func swapCurrencies() {
        let oldFrom = fromCode
        fromCode = toCode
        toCode = oldFrom
    }

    func reset() {
        amountText = "1"
    }

    // MARK: - Private

    /// If a saved currency is not supported by the provider any more, pick safe defaults.
    private func normaliseSelectedCurrencies() {
        guard let rates = rates else { return }
        if rates.rate(from: fromCode, to: fromCode) == nil { fromCode = "USD" }
        if rates.rate(from: toCode, to: toCode) == nil { toCode = "INR" }
    }
}
