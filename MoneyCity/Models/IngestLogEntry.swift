import Foundation
import SwiftData

/// A record of exactly what the Shortcuts automation handed the app, before any parsing.
///
/// The Wallet trigger is documented to deliver an empty merchant or a 0.0 amount to custom
/// App Intents, and when it does the only evidence is a generic "automation failed" banner.
/// This log turns that into a fact: it stores every raw parameter, whether or not the
/// transaction could be built, so a failure can be diagnosed instead of guessed at.
@Model
public final class IngestLogEntry: Identifiable {
    public var id: UUID = UUID()
    public var receivedAt: Date = Date()

    /// The parameters exactly as they arrived. Stored as text so "nothing arrived" and
    /// "an empty string arrived" stay distinguishable.
    public var rawAmount: String = "—"
    public var rawAmountText: String = "—"
    public var rawMerchant: String = "—"
    public var rawCurrency: String = "—"
    public var rawDate: String = "—"

    /// "saved", "duplicate", "placeholder", or the error that stopped it.
    public var outcome: String = ""
    public var resolvedAmount: Double? = nil
    public var resolvedMerchant: String? = nil

    public init(
        id: UUID = UUID(),
        receivedAt: Date = Date(),
        rawAmount: String,
        rawAmountText: String,
        rawMerchant: String,
        rawCurrency: String,
        rawDate: String,
        outcome: String = "",
        resolvedAmount: Double? = nil,
        resolvedMerchant: String? = nil
    ) {
        self.id = id
        self.receivedAt = receivedAt
        self.rawAmount = rawAmount
        self.rawAmountText = rawAmountText
        self.rawMerchant = rawMerchant
        self.rawCurrency = rawCurrency
        self.rawDate = rawDate
        self.outcome = outcome
        self.resolvedAmount = resolvedAmount
        self.resolvedMerchant = resolvedMerchant
    }

    /// Renders an optional parameter so an absent value and an empty one look different.
    public static func describe(_ value: Any?) -> String {
        guard let value else { return "nil (לא הועבר)" }
        if let text = value as? String {
            return text.isEmpty ? "\"\" (מחרוזת ריקה)" : "\"\(text)\""
        }
        if let number = value as? Double {
            return String(format: "%g", number)
        }
        if let date = value as? Date {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd HH:mm"
            return f.string(from: date)
        }
        return "\(value)"
    }
}
