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
            let formattedAmount = formatCurrency(amount)
            return CurrencyResult(
                formattedValue: "\(formattedAmount) \(toCode)",
                peekText: "\(formattedAmount) \(fromCode) = \(formattedAmount) \(toCode)",
                courtesyText: "Same Currency"
            )
        }

        // Check cache first
        if let cached = getCachedRates(for: fromCode), let rate = cached.rates[toCode] {
            let isFresh = Date().timeIntervalSince(cached.timestamp) < cacheFreshnessTTL
            if isFresh {
                return buildSuccessResult(
                    amount: amount, from: fromCode, to: toCode, rate: rate, dateStr: cached.date,
                    isCached: false)
            }
        }

        // Fetch from API
        do {
            let fetched = try await fetchRates(base: fromCode, target: toCode)
            if let rate = fetched.rates[toCode] {
                // Save to cache
                setCachedRates(fetched)
                return buildSuccessResult(
                    amount: amount, from: fromCode, to: toCode, rate: rate, dateStr: fetched.date,
                    isCached: false)
            }
        } catch {
            // Fall back to stale cache if available
            if let cached = getCachedRates(for: fromCode), let rate = cached.rates[toCode] {
                return buildSuccessResult(
                    amount: amount, from: fromCode, to: toCode, rate: rate, dateStr: cached.date,
                    isCached: true)
            }

            // Return offline error
            return CurrencyResult(
                formattedValue: "Offline or Rate Unavailable",
                peekText:
                    "Unable to fetch exchange rate for \(fromCode) to \(toCode).\nPlease check your internet connection.",
                subtitle: "Currency Conversion Failed",
                courtesyText: "Network Error",
                isError: true
            )
        }

        return nil
    }

    // MARK: - API Fetching

    private func fetchRates(base: String, target: String) async throws -> CachedRates {
        let urlStr = "https://api.frankfurter.dev/v1/latest?base=\(base)&symbols=\(target)"
        guard let url = URL(string: urlStr) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2.5  // Short timeout to ensure responsive search UI

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rates = json["rates"] as? [String: Double]
        else {
            throw URLError(.cannotParseResponse)
        }

        let date = (json["date"] as? String) ?? ""
        return CachedRates(base: base, date: date, timestamp: Date(), rates: rates)
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
        let formattedAmount = formatCurrency(amount)
        let formattedConverted = formatCurrency(converted)
        let formattedRate = formatRate(rate)

        let resultTitle = "\(formattedConverted) \(to)"
        let peekText =
            "\(formattedAmount) \(from) = \(formattedConverted) \(to)\nRate: 1 \(from) = \(formattedRate) \(to)"

        let courtesy: String
        if isCached && !dateStr.isEmpty {
            courtesy = "Cached rate from \(dateStr) (Frankfurter ECB)"
        } else if !dateStr.isEmpty {
            courtesy = "European Central Bank (\(dateStr))"
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
