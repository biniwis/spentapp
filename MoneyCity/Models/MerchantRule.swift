import Foundation
import SwiftData

/// A category the user chose for a merchant, remembered so the app stops repeating a mistake.
///
/// The keyword engine is a guess. Before this existed, correcting a transaction fixed that
/// one row and nothing else — the next charge from the same merchant fell into the same
/// wrong category, forever.
@Model
public final class MerchantRule: Identifiable {
    public var id: UUID = UUID()

    /// Normalised merchant text — lowercased, trimmed, whitespace collapsed.
    public var merchantKey: String = ""

    /// What the user displayed it as, kept for the settings list.
    public var displayName: String = ""

    public var categoryRawValue: String = SpendingCategory.other.rawValue
    public var buildingIdRaw: String? = nil

    /// How many later transactions this rule has classified — lets the UI show which
    /// corrections are actually earning their keep.
    public var hitCount: Int = 0
    public var createdAt: Date = Date()

    public var category: SpendingCategory {
        get { SpendingCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        merchantKey: String,
        displayName: String,
        category: SpendingCategory,
        buildingId: String? = nil,
        hitCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.merchantKey = InputSanitizer.sanitizeSingleLine(merchantKey, maxLength: InputSanitizer.maxMerchantLength)
        self.displayName = InputSanitizer.sanitizeSingleLine(displayName, maxLength: InputSanitizer.maxMerchantLength)
        self.categoryRawValue = category.canonical.rawValue
        self.buildingIdRaw = buildingId.map { InputSanitizer.sanitizeIdentifier($0) }
        self.hitCount = max(0, hitCount)
        self.createdAt = createdAt
    }
}
