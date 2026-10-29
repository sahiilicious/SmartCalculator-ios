import Foundation

/// Describes *which* exchange-rate API is used. Change this struct (or `AppConfiguration`)
/// to switch provider — no other code needs to change.
///
/// `urlTemplate` may contain two placeholders:
/// * `{base}` – the base currency code, e.g. USD
/// * `{key}`  – your API key (only for providers that need one)
struct CurrencyAPIConfiguration {
    var urlTemplate: String
    var apiKey: String?
    var timeout: TimeInterval = 15

    /// ExchangeRate-API "Open Access" endpoint: no key, ~160 currencies, updated once a day.
    /// Requires attribution (shown in the app) and is rate limited.
    static let openAccess = CurrencyAPIConfiguration(
        urlTemplate: "https://open.er-api.com/v6/latest/{base}",
        apiKey: nil
    )

    /// ExchangeRate-API v6 with your own (free) API key from https://www.exchangerate-api.com
    static func keyed(_ apiKey: String) -> CurrencyAPIConfiguration {
        CurrencyAPIConfiguration(
            urlTemplate: "https://v6.exchangerate-api.com/v6/{key}/latest/{base}",
            apiKey: apiKey
        )
    }

    func url(forBase base: String) throws -> URL {
        var text = urlTemplate.replacingOccurrences(of: "{base}", with: base)
        if text.contains("{key}") {
            guard let key = apiKey, !key.isEmpty else { throw CurrencyServiceError.missingAPIKey }
            text = text.replacingOccurrences(of: "{key}", with: key)
        }
        guard let url = URL(string: text), url.scheme == "https" else {
            throw CurrencyServiceError.invalidURL
        }
        return url
    }
}

/// Anything that can download exchange rates (the real service, or a fake one in tests).
protocol CurrencyServiceProtocol {
    func fetchRates(base: String) async throws -> ExchangeRates
}

/// Downloads rates with `URLSession` and `async/await`.
struct CurrencyService: CurrencyServiceProtocol {
    let configuration: CurrencyAPIConfiguration
    let session: URLSession

    init(configuration: CurrencyAPIConfiguration = AppConfiguration.currencyAPI,
         session: URLSession? = nil) {
        self.configuration = configuration
        if let session = session {
            self.session = session
        } else {
            let sessionConfiguration = URLSessionConfiguration.ephemeral
            sessionConfiguration.timeoutIntervalForRequest = configuration.timeout
            sessionConfiguration.timeoutIntervalForResource = configuration.timeout * 2
            sessionConfiguration.waitsForConnectivity = false
            self.session = URLSession(configuration: sessionConfiguration)
        }
    }

    func fetchRates(base: String) async throws -> ExchangeRates {
        let url = try configuration.url(forBase: base)
        var request = URLRequest(url: url,
                                 cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: configuration.timeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw CurrencyServiceError.invalidResponse
            }
            switch http.statusCode {
            case 200..<300: break
            case 429: throw CurrencyServiceError.rateLimited
            default: throw CurrencyServiceError.badStatus(http.statusCode)
            }
            return try Self.parse(data: data, requestedBase: base)
        } catch let serviceError as CurrencyServiceError {
            throw serviceError
        } catch let urlError as URLError {
            throw Self.map(urlError)
        } catch is CancellationError {
            throw CurrencyServiceError.cancelled
        } catch {
            throw CurrencyServiceError.network(error.localizedDescription)
        }
    }

    // MARK: - Parsing (static so it can be tested without a network)

    /// Shape of the JSON. Works for both the open endpoint ("rates") and the keyed v6
    /// endpoint ("conversion_rates").
    private struct Response: Decodable {
        let result: String?
        let errorType: String?
        let timeLastUpdateUnix: TimeInterval?
        let baseCode: String?
        let rates: [String: Double]?
        let conversionRates: [String: Double]?

        enum CodingKeys: String, CodingKey {
            case result
            case errorType = "error-type"
            case timeLastUpdateUnix = "time_last_update_unix"
            case baseCode = "base_code"
            case rates
            case conversionRates = "conversion_rates"
        }
    }

    static func parse(data: Data, requestedBase: String, now: Date = Date()) throws -> ExchangeRates {
        let response: Response
        do {
            response = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw CurrencyServiceError.invalidResponse
        }

        if let result = response.result, result != "success" {
            throw CurrencyServiceError.apiError(response.errorType ?? result)
        }

        guard let table = response.rates ?? response.conversionRates else {
            throw CurrencyServiceError.invalidResponse
        }

        // Keep only sensible numbers (positive and finite).
        var cleaned: [String: Double] = [:]
        for (code, value) in table where value.isFinite && value > 0 {
            cleaned[code] = value
        }
        guard !cleaned.isEmpty else { throw CurrencyServiceError.invalidResponse }

        let base = response.baseCode ?? requestedBase
        if cleaned[base] == nil { cleaned[base] = 1 }

        let updated = response.timeLastUpdateUnix.map { Date(timeIntervalSince1970: $0) }
        return ExchangeRates(base: base, rates: cleaned, providerUpdated: updated, fetchedAt: now)
    }

    private static func map(_ error: URLError) -> CurrencyServiceError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
             .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .internationalRoamingOff:
            return .noConnection
        case .timedOut:
            return .timedOut
        case .cancelled:
            return .cancelled
        default:
            return .network(error.localizedDescription)
        }
    }
}
