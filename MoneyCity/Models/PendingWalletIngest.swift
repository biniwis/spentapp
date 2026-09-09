import Foundation

// MARK: - Amount Parser

public enum AmountParser {
    /// Parses an optional string into a validated `Decimal` rounded to 2 decimal places.
    /// Distinguishes thousands grouping separators from decimal separators:
    /// - `1,200` / `12,000` -> 1200 / 12000 (comma followed by exactly 3 digits is thousands separator)
    /// - `1,200.50` -> 1200.50 (comma is thousands, dot is decimal)
    /// - `1.200,50` -> 1200.50 (dot is thousands, comma is decimal)
    /// - `48,50` / `48.50` -> 48.50 (comma/dot followed by 1-2 digits is decimal)
    /// Rejects negatives, zero, empty, or non-numeric inputs.
    public static func parse(_ text: String?) -> Decimal? {
        guard let rawText = text?.trimmingCharacters(in: .whitespacesAndNewlines), !rawText.isEmpty else {
            return nil
        }

        // Strictly reject negative indicators
        if rawText.contains("-") || rawText.contains("\u{2212}") || rawText.contains("\u{2013}") || rawText.contains("(") {
            return nil
        }

        // Fold non-Latin digits (Arabic-Indic, full-width) onto ASCII
        var folded = ""
        for ch in rawText {
            if !ch.isASCII, ch.isNumber, let d = ch.wholeNumberValue, (0...9).contains(d) {
                folded.append(Character(String(d)))
            } else {
                folded.append(ch)
            }
        }

        // Clean out common currency symbols and noise words
        let noiseList = ["₪", "$", "€", "£", "ILS", "NIS", "ש״ח", "שח", "שקל", "שקלים", "בסך", "ע״ס"]
        var cleaned = folded
        for noise in noiseList {
            cleaned = cleaned.replacingOccurrences(of: noise, with: "", options: .caseInsensitive)
        }

        // Remove whitespace and non-breaking spaces
        cleaned = cleaned.replacingOccurrences(of: "\u{00A0}", with: "")
        cleaned = cleaned.replacingOccurrences(of: " ", with: "")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return nil }

        let hasDot = cleaned.contains(".")
        let hasComma = cleaned.contains(",")

        var normalized = cleaned

        if hasDot && hasComma {
            // Whichever appears last is the decimal separator; the earlier groups thousands.
            guard let lastDot = cleaned.lastIndex(of: "."),
                  let lastComma = cleaned.lastIndex(of: ",") else {
                return nil
            }
            if lastDot > lastComma {
                // e.g. 1,200.50 -> strip comma
                normalized = cleaned.replacingOccurrences(of: ",", with: "")
            } else {
                // e.g. 1.200,50 -> strip dot, convert comma to dot
                normalized = cleaned
                    .replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: ".")
            }
        } else if hasComma {
            let parts = cleaned.split(separator: ",", omittingEmptySubsequences: false)
            if parts.count > 2 {
                // Multiple commas e.g. 1,000,000 -> all are thousands separators
                normalized = cleaned.replacingOccurrences(of: ",", with: "")
            } else if parts.count == 2 {
                let left = parts[0]
                let right = parts[1]
                if (1...2).contains(right.count) || left == "0" {
                    // e.g. 48,50 or 0,5 -> decimal point
                    normalized = "\(left).\(right)"
                } else if right.count == 3 {
                    // e.g. 1,200 or 12,000 -> thousands separator
                    normalized = "\(left)\(right)"
                } else {
                    return nil
                }
            }
        } else if hasDot {
            let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
            if parts.count > 2 {
                // Multiple dots e.g. 1.000.000 -> all are thousands separators
                normalized = cleaned.replacingOccurrences(of: ".", with: "")
            } else if parts.count == 2 {
                let left = parts[0]
                let right = parts[1]
                if (1...2).contains(right.count) || left == "0" {
                    // e.g. 48.50 or 0.5 -> decimal point
                    normalized = "\(left).\(right)"
                } else if right.count == 3 {
                    // e.g. 1.850 -> thousands separator (EU convention)
                    normalized = "\(left)\(right)"
                } else {
                    return nil
                }
            }
        }

        guard let decimalVal = Decimal(string: normalized) else {
            return nil
        }

        var mutableVal = decimalVal
        var rounded = Decimal()
        NSDecimalRound(&rounded, &mutableVal, 2, .plain)

        guard rounded > 0 else {
            return nil
        }

        return rounded
    }
}

// MARK: - Pending Wallet Ingest Model

public struct PendingWalletIngest: Codable, Identifiable, Sendable {
    public let id: String
    public let merchant: String
    public let currency: String
    public let categoryRawValue: String
    public let buildingId: String?
    public let timestamp: Date
    public let source: String

    public init(
        id: String = UUID().uuidString,
        merchant: String,
        currency: String = "₪",
        categoryRawValue: String,
        buildingId: String?,
        timestamp: Date = Date(),
        source: String = "ApplePay"
    ) {
        self.id = id
        self.merchant = merchant
        self.currency = currency
        self.categoryRawValue = categoryRawValue
        self.buildingId = buildingId
        self.timestamp = timestamp
        self.source = source
    }


}

// MARK: - Pending Wallet Store

public final class PendingWalletStore: @unchecked Sendable {
    public static let shared = PendingWalletStore()

    private let lock = NSLock()
    private let storageKey = "moneycity_pending_wallet_ingests"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: "group.com.moneycity.app") ?? .standard) { self.defaults = defaults }

    /// Checks for an existing pending ingest matching the merchant, currency, and 90s window.
    /// If found, returns the existing record and `isNew: false`.
    /// Otherwise, creates and persists a new record and returns `isNew: true`.
    public func findOrRegister(
        merchant: String,
        currency: String,
        categoryRawValue: String,
        buildingId: String?,
        date: Date,
        source: String = "ApplePay",
        id: String = UUID().uuidString
    ) -> (ingest: PendingWalletIngest, isNew: Bool) {
        lock.lock()
        defer { lock.unlock() }

        var all = loadAllInternal()
        purgeStaleInternal(&all)

        let cleanedMerchant = (TransactionIngest.normalizedMerchant(merchant) ?? merchant).lowercased()

        // Deduplication check within a 90-second window
        if let existing = all.first(where: { item in
            let itemMerchant = (TransactionIngest.normalizedMerchant(item.merchant) ?? item.merchant).lowercased()
            let timeDiff = abs(item.timestamp.timeIntervalSince(date))
            return itemMerchant == cleanedMerchant && TransactionIngest.currencyKey(item.currency) == TransactionIngest.currencyKey(currency) && timeDiff <= TransactionIngest.duplicateWindow
        }) {
            return (existing, false)
        }

        let newIngest = PendingWalletIngest(
            id: id,
            merchant: merchant,
            currency: currency,
            categoryRawValue: categoryRawValue,
            buildingId: buildingId,
            timestamp: date,
            source: source
        )
        all.append(newIngest)
        saveAllInternal(all)
        return (newIngest, true)
    }

    public func get(id: String) -> PendingWalletIngest? {
        lock.lock()
        defer { lock.unlock() }
        let all = loadAllInternal()
        return all.first(where: { $0.id == id })
    }

    public func getAll() -> [PendingWalletIngest] {
        lock.lock()
        defer { lock.unlock() }
        var all = loadAllInternal()
        purgeStaleInternal(&all)
        return all
    }

    public func remove(id: String) {
        lock.lock()
        defer { lock.unlock() }
        var all = loadAllInternal()
        all.removeAll(where: { $0.id == id })
        saveAllInternal(all)
    }

    private func purgeStaleInternal(_ list: inout [PendingWalletIngest]) {
        // Keep pending items for up to 48 hours
        let cutoff = Date().addingTimeInterval(-48 * 3600)
        list.removeAll(where: { $0.timestamp < cutoff })
    }

    private func loadAllInternal() -> [PendingWalletIngest] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([PendingWalletIngest].self, from: data) else {
            return []
        }
        return decoded
    }

    private func saveAllInternal(_ list: [PendingWalletIngest]) {
        if let encoded = try? JSONEncoder().encode(list) {
            defaults.set(encoded, forKey: storageKey)
        }
    }
}
