import XCTest
@testable import SmartCalculator

// MARK: - Test doubles

final class StubCurrencyService: CurrencyServiceProtocol {
    var result: Result<ExchangeRates, Error>
    private(set) var callCount = 0

    init(result: Result<ExchangeRates, Error>) { self.result = result }

    func fetchRates(base: String) async throws -> ExchangeRates {
        callCount += 1
        return try result.get()
    }
}

final class MemoryRateCache: RateCaching {
    var stored: ExchangeRates?
    init(_ stored: ExchangeRates? = nil) { self.stored = stored }
    func load() -> ExchangeRates? { stored }
    func save(_ rates: ExchangeRates) { stored = rates }
}

final class MemoryHistoryStore: HistoryStoring {
    var stored: [HistoryEntry] = []
    func load() -> [HistoryEntry] { stored }
    func save(_ entries: [HistoryEntry]) { stored = entries }
}

func makeDefaults() -> UserDefaults {
    let name = "SmartCalculatorTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name) ?? .standard
    defaults.removePersistentDomain(forName: name)
    return defaults
}

// MARK: - Parsing and math

final class CurrencyParsingTests: XCTestCase {
    private func data(_ json: String) -> Data { Data(json.utf8) }

    func testParsesOpenAccessResponse() throws {
        let json = """
        {"result":"success","provider":"https://www.exchangerate-api.com",
         "time_last_update_unix":1585872397,"base_code":"USD",
         "rates":{"USD":1,"INR":83.25,"EUR":0.92,"AED":3.6725}}
        """
        let rates = try CurrencyService.parse(data: data(json), requestedBase: "USD")
        XCTAssertEqual(rates.base, "USD")
        XCTAssertEqual(rates.rates["INR"], 83.25)
        XCTAssertEqual(rates.rates["AED"], 3.6725)
        XCTAssertEqual(rates.providerUpdated, Date(timeIntervalSince1970: 1585872397))
    }

    func testParsesKeyedResponse() throws {
        let json = #"{"result":"success","base_code":"USD","conversion_rates":{"USD":1,"JPY":150.5}}"#
        let rates = try CurrencyService.parse(data: data(json), requestedBase: "USD")
        XCTAssertEqual(rates.rates["JPY"], 150.5)
    }

    func testAddsBaseCurrencyIfMissing() throws {
        let json = #"{"result":"success","rates":{"INR":83}}"#
        let rates = try CurrencyService.parse(data: data(json), requestedBase: "USD")
        XCTAssertEqual(rates.rates["USD"], 1)
    }

    func testErrorResponseThrowsAPIError() {
        let json = #"{"result":"error","error-type":"unsupported-code"}"#
        XCTAssertThrowsError(try CurrencyService.parse(data: data(json), requestedBase: "XXX")) {
            XCTAssertEqual($0 as? CurrencyServiceError, .apiError("unsupported-code"))
        }
    }

    func testInvalidJSONThrows() {
        XCTAssertThrowsError(try CurrencyService.parse(data: data("not json"), requestedBase: "USD")) {
            XCTAssertEqual($0 as? CurrencyServiceError, .invalidResponse)
        }
    }

    func testMissingRatesThrows() {
        XCTAssertThrowsError(try CurrencyService.parse(data: data(#"{"result":"success"}"#), requestedBase: "USD")) {
            XCTAssertEqual($0 as? CurrencyServiceError, .invalidResponse)
        }
    }

    func testInvalidRateValuesAreDropped() throws {
        let json = #"{"result":"success","rates":{"USD":1,"BAD":-5,"ZERO":0,"INR":83}}"#
        let rates = try CurrencyService.parse(data: data(json), requestedBase: "USD")
        XCTAssertNil(rates.rates["BAD"])
        XCTAssertNil(rates.rates["ZERO"])
        XCTAssertEqual(rates.rates["INR"], 83)
    }

    func testAllRatesInvalidThrows() {
        let json = #"{"result":"success","rates":{"BAD":-1}}"#
        XCTAssertThrowsError(try CurrencyService.parse(data: data(json), requestedBase: "USD"))
    }

    func testURLBuilding() throws {
        let open = try CurrencyAPIConfiguration.openAccess.url(forBase: "USD")
        XCTAssertEqual(open.absoluteString, "https://open.er-api.com/v6/latest/USD")

        let keyed = try CurrencyAPIConfiguration.keyed("ABC123").url(forBase: "EUR")
        XCTAssertEqual(keyed.absoluteString, "https://v6.exchangerate-api.com/v6/ABC123/latest/EUR")
    }

    func testKeyedURLWithoutKeyThrows() {
        let config = CurrencyAPIConfiguration(urlTemplate: "https://example.com/{key}/{base}", apiKey: nil)
        XCTAssertThrowsError(try config.url(forBase: "USD")) {
            XCTAssertEqual($0 as? CurrencyServiceError, .missingAPIKey)
        }
    }

    func testNonHTTPSURLRejected() {
        let config = CurrencyAPIConfiguration(urlTemplate: "http://example.com/{base}", apiKey: nil)
        XCTAssertThrowsError(try config.url(forBase: "USD"))
    }
}

final class ExchangeRatesMathTests: XCTestCase {
    static let sample = ExchangeRates(base: "USD",
                                      rates: ["USD": 1, "INR": 83, "EUR": 0.9, "JPY": 150],
                                      providerUpdated: nil,
                                      fetchedAt: Date(timeIntervalSince1970: 1_700_000_000))

    func testBaseToOther() {
        XCTAssertEqual(Self.sample.convert(100, from: "USD", to: "INR") ?? 0, 8300, accuracy: 1e-9)
    }

    func testOtherToBase() {
        XCTAssertEqual(Self.sample.convert(8300, from: "INR", to: "USD") ?? 0, 100, accuracy: 1e-9)
    }

    func testCrossRate() {
        XCTAssertEqual(Self.sample.rate(from: "INR", to: "EUR") ?? 0, 0.9 / 83, accuracy: 1e-12)
    }

    func testSameCurrencyIsOne() {
        XCTAssertEqual(Self.sample.rate(from: "EUR", to: "EUR") ?? 0, 1, accuracy: 1e-12)
    }

    func testUnknownCurrencyReturnsNil() {
        XCTAssertNil(Self.sample.rate(from: "USD", to: "XYZ"))
        XCTAssertNil(Self.sample.convert(1, from: "XYZ", to: "USD"))
    }

    func testZeroAmount() {
        XCTAssertEqual(Self.sample.convert(0, from: "USD", to: "INR") ?? -1, 0, accuracy: 1e-12)
    }

    func testCodable() throws {
        let data = try JSONEncoder().encode(Self.sample)
        XCTAssertEqual(try JSONDecoder().decode(ExchangeRates.self, from: data), Self.sample)
    }

    func testRequiredCurrenciesAreInPopularList() {
        for code in ["INR", "USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CNY", "AED", "SGD"] {
            XCTAssertTrue(CurrencyCatalog.popularCodes.contains(code), code)
        }
    }

    func testUserDefaultsCacheRoundTrip() {
        let cache = UserDefaultsRateCache(defaults: makeDefaults())
        XCTAssertNil(cache.load())
        cache.save(Self.sample)
        XCTAssertEqual(cache.load(), Self.sample)
    }
}

// MARK: - View model

@MainActor
final class CurrencyViewModelTests: XCTestCase {
    private let us = Locale(identifier: "en_US")
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func rates(fetchedAgo seconds: TimeInterval) -> ExchangeRates {
        ExchangeRates(base: "USD",
                      rates: ["USD": 1, "INR": 83, "EUR": 0.9],
                      providerUpdated: nil,
                      fetchedAt: now.addingTimeInterval(-seconds))
    }

    private func makeViewModel(service: StubCurrencyService, cache: MemoryRateCache) -> CurrencyViewModel {
        CurrencyViewModel(service: service, cache: cache, defaults: makeDefaults(), locale: us, now: { self.now })
    }

    func testSuccessfulRefreshShowsLiveRatesAndSavesCache() async {
        let fresh = rates(fetchedAgo: 0)
        let service = StubCurrencyService(result: .success(fresh))
        let cache = MemoryRateCache()
        let vm = makeViewModel(service: service, cache: cache)

        XCTAssertEqual(vm.conversion, .waitingForRates)
        await vm.refresh()

        XCTAssertEqual(service.callCount, 1)
        XCTAssertEqual(vm.rates, fresh)
        XCTAssertFalse(vm.isShowingCachedRates)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(cache.stored, fresh)
    }

    func testFailureWithoutCacheLeavesNoRates() async {
        let service = StubCurrencyService(result: .failure(CurrencyServiceError.noConnection))
        let vm = makeViewModel(service: service, cache: MemoryRateCache())
        await vm.refresh()

        XCTAssertNil(vm.rates)
        XCTAssertFalse(vm.isShowingCachedRates)
        XCTAssertEqual(vm.errorMessage, CurrencyServiceError.noConnection.errorDescription)
        XCTAssertEqual(vm.conversion, .waitingForRates)
    }

    func testFailureWithOldCacheMarksRatesAsCached() async {
        let old = rates(fetchedAgo: 3 * 24 * 3600)
        let service = StubCurrencyService(result: .failure(CurrencyServiceError.timedOut))
        let vm = makeViewModel(service: service, cache: MemoryRateCache(old))

        XCTAssertTrue(vm.isShowingCachedRates, "Saved rates must be flagged as cached from the start")
        await vm.refresh()

        XCTAssertEqual(service.callCount, 1)
        XCTAssertTrue(vm.isShowingCachedRates)
        XCTAssertEqual(vm.rates, old)
        XCTAssertNotNil(vm.errorMessage)
    }

    func testRecentCacheIsNotDownloadedAgainAutomatically() async {
        let recent = rates(fetchedAgo: 20 * 60)
        let service = StubCurrencyService(result: .success(rates(fetchedAgo: 0)))
        let vm = makeViewModel(service: service, cache: MemoryRateCache(recent))
        await vm.refresh()

        XCTAssertEqual(service.callCount, 0)
        XCTAssertFalse(vm.isShowingCachedRates)
    }

    func testManualRefreshAfterAWhileDownloads() async {
        let recent = rates(fetchedAgo: 20 * 60)
        let service = StubCurrencyService(result: .success(rates(fetchedAgo: 0)))
        let vm = makeViewModel(service: service, cache: MemoryRateCache(recent))
        await vm.refresh(force: true)
        XCTAssertEqual(service.callCount, 1)
    }

    func testManualRefreshIsThrottledRightAfterADownload() async {
        let justNow = rates(fetchedAgo: 60)
        let service = StubCurrencyService(result: .success(rates(fetchedAgo: 0)))
        let vm = makeViewModel(service: service, cache: MemoryRateCache(justNow))
        await vm.refresh(force: true)

        XCTAssertEqual(service.callCount, 0)
        XCTAssertNotNil(vm.infoMessage)
    }

    func testConversionStates() async {
        let service = StubCurrencyService(result: .success(rates(fetchedAgo: 0)))
        let vm = makeViewModel(service: service, cache: MemoryRateCache())
        await vm.refresh()

        vm.fromCode = "USD"
        vm.toCode = "INR"
        vm.amountText = "100"
        XCTAssertEqual(vm.conversion, .ready(8300))
        XCTAssertEqual(vm.convertedText, "8,300.00")
        XCTAssertEqual(vm.rateLine, "1 USD = 83 INR")

        vm.amountText = ""
        XCTAssertEqual(vm.conversion, .empty)

        vm.amountText = "abc"
        if case .invalid = vm.conversion {} else { XCTFail("Expected invalid") }

        vm.amountText = "-5"
        if case .invalid = vm.conversion {} else { XCTFail("Expected invalid for negative") }

        vm.amountText = "1"
        vm.toCode = "XYZ"
        if case .invalid = vm.conversion {} else { XCTFail("Expected invalid for unknown currency") }
    }

    func testSwapCurrencies() {
        let vm = makeViewModel(service: StubCurrencyService(result: .failure(CurrencyServiceError.noConnection)),
                               cache: MemoryRateCache())
        vm.fromCode = "USD"
        vm.toCode = "INR"
        vm.swapCurrencies()
        XCTAssertEqual(vm.fromCode, "INR")
        XCTAssertEqual(vm.toCode, "USD")
    }
}
