import Foundation
import NerwAction
import NerwSearchBackend
import NerwUtils

public final class CurrencyConversionEngine {
    public static let shared = CurrencyConversionEngine()

    public struct CurrencyResult {
        public let formattedValue: String
        public let peekText: String
        public let subtitle: String
        public let courtesyText: String?
        public let isError: Bool

        public init(
            formattedValue: String,
            peekText: String,
            subtitle: String = "Currency Conversion",
            courtesyText: String? = "Powered by Frankfurter (ECB)",
            isError: Bool = false
        ) {
            self.formattedValue = formattedValue
            self.peekText = peekText
            self.subtitle = subtitle
            self.courtesyText = courtesyText
            self.isError = isError
        }
    }

    private struct CachedRates: Codable {
        let base: String
        let date: String
        let timestamp: Date
        let rates: [String: Double]
    }

    // In-memory cache for ultra-fast instant lookups
    private var memoryCache: [String: CachedRates] = [:]
    private let cacheLock = NSLock()

    // 12 hours TTL for cache freshness
    private let cacheFreshnessTTL: TimeInterval = 12 * 3600

    // Baseline ECB exchange rates relative to 1 EUR (fallback & instant offline response)
    private static let baselineEurRates: [String: Double] = [
        "EUR": 1.0,
        "USD": 1.085,
        "JPY": 165.0,
        "GBP": 0.855,
        "INR": 95.4,
        "CAD": 1.48,
        "AUD": 1.66,
        "CHF": 0.955,
        "CNY": 7.85,
        "KRW": 1490.0,
        "BRL": 5.95,
        "RUB": 98.0,
        "SEK": 11.45,
        "NOK": 11.65,
        "DKK": 7.46,
        "PLN": 4.30,
        "TRY": 48.1,
        "ILS": 4.05,
        "SGD": 1.44,
        "HKD": 8.48,
        "NZD": 1.82,
        "THB": 38.5,
        "MXN": 21.5,
        "ZAR": 19.8,
        "IDR": 17700.0,
        "MYR": 4.95,
        "PHP": 62.5,
        "CZK": 25.2,
        "HUF": 395.0,
        "RON": 4.97,
        "BGN": 1.9558,
        "ISK": 150.0,
    ]

    private init() {}

    // MARK: - Main Conversion Method

    public func convert(amount: Double, from fromCurrency: String, to toCurrency: String) async
        -> CurrencyResult?
    {
        guard let fromCode = MathConversionDetector.shared.resolveCurrencyCode(fromCurrency),
            let toCode = MathConversionDetector.shared.resolveCurrencyCode(toCurrency)
        else {
            return nil
        }

        // Same currency conversion: 100 USD to USD = 100 USD
        if fromCode == toCode {
            let formattedAmount = formatAmount(amount)
            return CurrencyResult(
                formattedValue: "\(formattedAmount) \(toCode)",
                peekText: "\(formattedAmount) \(fromCode) = \(formattedAmount) \(toCode)",
                courtesyText: "Same Currency"
            )
        }

        // 1. Check in-memory / disk cache
        if let cached = getCachedRates(for: fromCode), let rate = cached.rates[toCode] {
            let isFresh = Date().timeIntervalSince(cached.timestamp) < cacheFreshnessTTL
            if isFresh {
                return buildSuccessResult(
                    amount: amount, from: fromCode, to: toCode, rate: rate, dateStr: cached.date,
                    isCached: false)
            } else {
                // Stale cache: trigger background refresh and return immediately
                Task.detached { [weak self] in
                    _ = try? await self?.fetchRates(base: fromCode)
                }
                return buildSuccessResult(
                    amount: amount, from: fromCode, to: toCode, rate: rate, dateStr: cached.date,
                    isCached: true)
            }
        }

        // 2. Fetch fresh rates from Frankfurter API
        do {
            let fetched = try await fetchRates(base: fromCode)
            if let rate = fetched.rates[toCode] {
                setCachedRates(fetched)
                return buildSuccessResult(
                    amount: amount, from: fromCode, to: toCode, rate: rate, dateStr: fetched.date,
                    isCached: false)
            }
        } catch {
            // API failed or offline: fall back to baseline rates
        }

        // 3. Fallback to baseline calculation if network unavailable
        if let baselineRate = getBaselineRate(from: fromCode, to: toCode) {
            return buildSuccessResult(
                amount: amount, from: fromCode, to: toCode, rate: baselineRate,
                dateStr: "Baseline Rates",
                isCached: true)
        }

        // 4. Stale cache fallback for any base
        if let cached = getCachedRates(for: fromCode), let rate = cached.rates[toCode] {
            return buildSuccessResult(
                amount: amount, from: fromCode, to: toCode, rate: rate, dateStr: cached.date,
                isCached: true)
        }

        return nil
    }

    // MARK: - Baseline Rates Calculation

    private func getBaselineRate(from: String, to: String) -> Double? {
        guard let fromEur = Self.baselineEurRates[from],
            let toEur = Self.baselineEurRates[to],
            fromEur > 0
        else {
            return nil
        }
        return toEur / fromEur
    }

    // MARK: - API Fetching

    @discardableResult
    private func fetchRates(base: String) async throws -> CachedRates {
        let urlStr = "https://api.frankfurter.dev/v1/latest?base=\(base)"
        guard let url = URL(string: urlStr) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0  // Short timeout to ensure responsive search UI

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rawRates = json["rates"] as? [String: Any]
        else {
            throw URLError(.cannotParseResponse)
        }

        var rates: [String: Double] = [:]
        for (k, v) in rawRates {
            if let d = v as? Double {
                rates[k] = d
            } else if let num = v as? NSNumber {
                rates[k] = num.doubleValue
            } else if let str = v as? String, let d = Double(str) {
                rates[k] = d
            }
        }
        rates[base] = 1.0

        let date = (json["date"] as? String) ?? ""
        let cached = CachedRates(base: base, date: date, timestamp: Date(), rates: rates)
        setCachedRates(cached)
        return cached
    }

    // MARK: - Cache Helpers

    private func getCachedRates(for base: String) -> CachedRates? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if let mem = memoryCache[base] {
            return mem
        }

        let cacheKey = "frankfurter_rates_\(base)"
        if let diskCached = CacheManager.shared.get(forKey: cacheKey, as: CachedRates.self) {
            memoryCache[base] = diskCached
            return diskCached
        }

        return nil
    }

    private func setCachedRates(_ rates: CachedRates) {
        cacheLock.lock()
        memoryCache[rates.base] = rates
        cacheLock.unlock()

        let cacheKey = "frankfurter_rates_\(rates.base)"
        CacheManager.shared.set(rates, forKey: cacheKey)
    }

    // MARK: - Result Building & Formatting

    private func buildSuccessResult(
        amount: Double, from: String, to: String,
        rate: Double, dateStr: String, isCached: Bool
    ) -> CurrencyResult {
        let converted = amount * rate
        let formattedAmount = formatAmount(amount)
        let formattedConverted = formatCurrency(converted)
        let formattedRate = formatRate(rate)

        let resultTitle = "\(formattedConverted) \(to)"
        let peekText =
            "\(formattedAmount) \(from) = \(formattedConverted) \(to)\nRate: 1 \(from) = \(formattedRate) \(to)"

        let courtesy: String
        if dateStr == "Baseline Rates" {
            courtesy = "Powered by Frankfurter (ECB baseline)"
        } else if isCached && !dateStr.isEmpty {
            courtesy = "Powered by Frankfurter (Cached • \(dateStr))"
        } else if !dateStr.isEmpty {
            courtesy = "Powered by Frankfurter (ECB • \(dateStr))"
        } else {
            courtesy = "Powered by Frankfurter"
        }

        return CurrencyResult(
            formattedValue: resultTitle,
            peekText: peekText,
            subtitle: "Currency Conversion",
            courtesyText: courtesy,
            isError: false
        )
    }

    private func formatAmount(_ value: Double) -> String {
        if value.isFinite && floor(value) == value && abs(value) < 1e12 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
        }
        return formatCurrency(value)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func formatRate(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.4f", value)
    }
}
