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

    /// Rate relative to 1 ILS (Shekel) — how many shekels is 1 unit of currency worth
    nonisolated public static func rateToILS(for currency: CurrencyType) -> Double {
        let defaults = UserDefaults.standard
        switch currency {
        case .ils: return 1.00
        case .usd:
            let v = defaults.double(forKey: "fx_rate_usd_ils")
            return v > 0 ? v : 3.65
        case .eur:
            let v = defaults.double(forKey: "fx_rate_eur_ils")
            return v > 0 ? v : 3.95
        case .gbp:
            let v = defaults.double(forKey: "fx_rate_gbp_ils")
            return v > 0 ? v : 4.65
        }
    }

    /// Convert amount between any two supported currencies
    nonisolated public static func convert(amount: Double, from: CurrencyType, to: CurrencyType) -> Double {
        if from == to { return amount }
        let amountInILS = amount * rateToILS(for: from)
        let targetRate = rateToILS(for: to)
        guard targetRate > 0 else { return amount }
        return amountInILS / targetRate
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

            // The API returns rates relative to base ILS (e.g. rates["USD"] = 0.273 -> 1 USD = 1/0.273 ILS)
            if let usd = decoded.rates["USD"], usd > 0 {
                self.usdRate = (1.0 / usd).rounded(to: 4)
            }
            if let eur = decoded.rates["EUR"], eur > 0 {
                self.eurRate = (1.0 / eur).rounded(to: 4)
            }
            if let gbp = decoded.rates["GBP"], gbp > 0 {
                self.gbpRate = (1.0 / gbp).rounded(to: 4)
            }

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
