import Foundation
import SwiftUI

/// Live Foreign Exchange (FX) Service.
/// Fetches real-time rates with offline caching and background auto-sync.
@MainActor
public final class FXService: ObservableObject {
    public static let shared = FXService()

    @AppStorage("fx_last_updated_ts") public var lastUpdatedTimestamp: Double = 0
    @AppStorage("fx_rate_usd_ils") public var usdRate: Double = 3.65
    @AppStorage("fx_rate_eur_ils") public var eurRate: Double = 3.95
    @AppStorage("fx_rate_gbp_ils") public var gbpRate: Double = 4.65

    @Published public var isUpdating: Bool = false
    @Published public var lastErrorMessage: String? = nil

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public static let defaultRatesToILS: [String: Double] = [
        "ILS": 1.00,
        "USD": 3.65,
        "EUR": 3.95,
        "GBP": 4.65
    ]

    private static let ratesCacheKey = "fx_rates_cache_dict"

    /// Rate relative to 1 ILS (Shekel) — how many shekels is 1 unit of foreign currency worth.
    /// Returns nil if no rate is known for this currency code.
    nonisolated public static func rateToILS(for currencyCode: String) -> Double? {
        let code = CurrencyResolutionService.normalizeToISOCode(currencyCode) ?? currencyCode.uppercased()
        if code == "ILS" { return 1.00 }

        let defaults = UserDefaults.standard
        if code == "USD" {
            let v = defaults.double(forKey: "fx_rate_usd_ils")
            if v > 0 { return v }
        } else if code == "EUR" {
            let v = defaults.double(forKey: "fx_rate_eur_ils")
            if v > 0 { return v }
        } else if code == "GBP" {
            let v = defaults.double(forKey: "fx_rate_gbp_ils")
            if v > 0 { return v }
        }

        if let dict = defaults.dictionary(forKey: ratesCacheKey) as? [String: Double],
           let r = dict[code], r > 0 {
            return r
        }

        return defaultRatesToILS[code]
    }

    /// Rate relative to 1 ILS for a given CurrencyType.
    nonisolated public static func rateToILS(for currency: CurrencyType) -> Double {
        rateToILS(for: currency.rawValue) ?? 1.00
    }

    /// Convert amount between any two currencies. Returns nil if conversion rate is unavailable.
    nonisolated public static func convert(amount: Double, from fromCurrency: String, to toCurrency: String) -> Double? {
        let fromCode = CurrencyResolutionService.normalizeToISOCode(fromCurrency) ?? fromCurrency.uppercased()
        let toCode = CurrencyResolutionService.normalizeToISOCode(toCurrency) ?? toCurrency.uppercased()
        if fromCode == toCode { return amount }

        guard let rateFrom = rateToILS(for: fromCode),
              let rateTo = rateToILS(for: toCode),
              rateTo > 0 else {
            return nil
        }
        let amountInILS = amount * rateFrom
        return amountInILS / rateTo
    }

    /// Convert amount between any two supported CurrencyTypes.
    ///
    /// Returns `nil` when no verified/cached/default rate exists. Never substitutes the
    /// original amount as a stand-in rate — a missing rate must be an explicit failure,
    /// not a silent 1:1 conversion.
    nonisolated public static func convert(amount: Double, from: CurrencyType, to: CurrencyType) -> Double? {
        if from == to { return amount }
        return convert(amount: amount, from: from.rawValue, to: to.rawValue)
    }

    /// Human-friendly last updated string
    public var lastUpdatedString: String {
        guard lastUpdatedTimestamp > 0 else {
            return "שערי ברירת מחדל"
        }
        let date = Date(timeIntervalSince1970: lastUpdatedTimestamp)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.dateFormat = "d.M.yy, HH:mm"
        return formatter.string(from: date)
    }

    /// Refresh rates from free public exchange rate API
    /// Startup uses a six-hour cache. Explicit user refreshes still fetch immediately.
    public func fetchLatestRatesIfNeeded(now: Date = Date()) async {
        let age = now.timeIntervalSince1970 - lastUpdatedTimestamp
        guard lastUpdatedTimestamp <= 0 || age < 0 || age >= 6 * 3600 else { return }
        await fetchLatestRates()
    }

    public func fetchLatestRates() async {
        guard !isUpdating else { return }
        isUpdating = true
        lastErrorMessage = nil

        defer { isUpdating = false }

        // Open ER API (free, reliable, HTTPS, no auth token required)
        guard let url = URL(string: "https://open.er-api.com/v6/latest/ILS") else { return }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8.0
            request.cachePolicy = .reloadIgnoringLocalCacheData

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                lastErrorMessage = "שגיאת תקשורת עם שרת השערים"
                return
            }

            struct ERResponse: Decodable {
                let result: String
                let rates: [String: Double]
            }

            let decoded = try JSONDecoder().decode(ERResponse.self, from: data)
            guard decoded.result == "success" else {
                lastErrorMessage = "תגובה לא תקינה"
                return
            }

            var newCache: [String: Double] = [:]
            for (curr, val) in decoded.rates where val > 0 {
                let rateInILS = (1.0 / val).rounded(to: 4)
                newCache[curr.uppercased()] = rateInILS
            }

            if let usd = newCache["USD"], usd > 0 {
                self.usdRate = usd
            }
            if let eur = newCache["EUR"], eur > 0 {
                self.eurRate = eur
            }
            if let gbp = newCache["GBP"], gbp > 0 {
                self.gbpRate = gbp
            }

            UserDefaults.standard.set(newCache, forKey: Self.ratesCacheKey)
            self.lastUpdatedTimestamp = Date().timeIntervalSince1970
            objectWillChange.send()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}

private extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
