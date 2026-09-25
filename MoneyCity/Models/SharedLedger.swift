import Foundation
import SwiftData

/// Shared values never hold a reference to a personal SwiftData model.
struct SharedSpace: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var currencyCode: String
    var timeZoneID: String
    var mapStyle: String
    var createdAt: Date
    /// The space's own monthly spending target, in minor units of `currencyCode`.
    ///
    /// Optional on purpose. Spaces that existed before targets did simply have no such
    /// field in their payload, and the synthesized decoder turns that into `nil` rather
    /// than failing — an old space keeps working and reports no target instead of being
    /// given an invented number. This is the space's target, never the personal
    /// `monthly_budget`, and the two must stay independent.
    ///
    /// TODO before release: decoding is backward compatible, but *encoding* is not. A
    /// client on an older build that re-encodes a `SharedSpace` will drop this field and
    /// silently clear the target. Shared Mode is unreleased, so that path cannot happen
    /// yet. Once it can, the target has to survive a write from an old client — either
    /// by refusing to overwrite a field an old client cannot see, or by versioning the
    /// payload. The CloudKit schema does not need changing for it: the payload is opaque
    /// `Data`.
    var monthlyBudgetMinor: Int64?
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func progress(spentMinor: Int64) -> SharedBudgetProgress {
        SharedBudgetProgress(spentMinor: spentMinor, targetMinor: monthlyBudgetMinor)
    }
}

/// How a space's month stands against its target.
///
/// Pure arithmetic in the space's own currency, so every surface that reports a shared
/// target — city, profile, analytics, recap — reads the same numbers instead of
/// recomputing them its own way. A space with no target reports `hasTarget == false` and
/// no numbers at all, rather than a zero that would look like a finished month.
struct SharedBudgetProgress: Equatable {
    let spentMinor: Int64
    let targetMinor: Int64?

    var hasTarget: Bool { (targetMinor ?? 0) > 0 }

    var remainingMinor: Int64? {
        guard let targetMinor, hasTarget else { return nil }
        return targetMinor - spentMinor
    }

    /// Share of the target already spent, uncapped: going over the target is information
    /// the product needs, not something to hide by clamping to 1.
    var fraction: Double? {
        guard let targetMinor, targetMinor > 0 else { return nil }
        return Double(spentMinor) / Double(targetMinor)
    }

    var isOverTarget: Bool { (remainingMinor ?? 0) < 0 }
}

struct SharedMember: Codable, Identifiable, Equatable {
    var id: String
    var spaceID: UUID
    var name: String
    var colorHex: String
    var isActive: Bool
}

struct SharedExpense: Codable, Identifiable, Equatable {
    var id: UUID
    var spaceID: UUID
    var amountMinor: Int64
    var currencyCode: String
    var merchant: String
    var category: SpendingCategory
    var buildingID: String
    var date: Date
    var note: String
    var paidBy: String
    var createdBy: String
    var updatedBy: String
    var originalAmount: String?
    var originalCurrency: String?
    var exchangeRate: String?
    var exchangeRateDate: Date?

    var amount: Double { SharedMoney.major(amountMinor, currency: currencyCode) }
}

struct SharedExpenseConflict: Identifiable, Equatable {
    var id: String { recordKey }
    let recordKey: String
    let spaceID: UUID
    let serverExpense: SharedExpense
    let localExpense: SharedExpense
}

enum SharedMoney {
    static func digits(_ currency: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.maximumFractionDigits
    }

    static func minor(_ text: String, currency: String) throws -> Int64 {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard normalized.range(of: "^-?[0-9]+(?:\\.[0-9]+)?$", options: .regularExpression) != nil,
              let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
              value != 0, abs(value) <= Decimal(100_000_000) else { throw SharedLedgerError.invalidAmount }
        var scaled = value * pow(Decimal(10), digits(currency))
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        guard rounded != 0 else { throw SharedLedgerError.invalidAmount }
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    static func major(_ amount: Int64, currency: String) -> Double {
        Double(amount) / pow(10, Double(digits(currency)))
    }
}

/// This envelope is the only Shared persistence schema. The typed payload above is versioned
/// independently, while record metadata and local revisions commit in the same SQLite save.
@Model
final class SharedStoredRecord {
    @Attribute(.unique) var key: String
    var spaceID: String
    var kind: String
    var payload: Data
    var zoneName: String
    var zoneOwner: String
    var databaseScope: Int
    var localRevision: String?
    var systemFields: Data?
    var isDeleted: Bool
    var recoveryPayload: Data?
    var schemaVersion: Int

    init(key: String, spaceID: String, kind: String, payload: Data,
         zoneName: String, zoneOwner: String, databaseScope: Int) {
        self.key = key; self.spaceID = spaceID; self.kind = kind; self.payload = payload
        self.zoneName = zoneName; self.zoneOwner = zoneOwner; self.databaseScope = databaseScope
        self.isDeleted = false; self.schemaVersion = 1
    }
}

@Model
final class SharedEngineState {
    @Attribute(.unique) var scope: Int
    var serialization: Data
    init(scope: Int, serialization: Data) { self.scope = scope; self.serialization = serialization }
}

enum SharedSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [SharedStoredRecord.self, SharedEngineState.self] }
}

@MainActor
final class SharedDatabaseService {
    let container: ModelContainer
    let context: ModelContext

    init(directory: URL?, inMemory: Bool = false) throws {
        let schema = Schema(versionedSchema: SharedSchemaV1.self)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            guard let directory else { throw SharedLedgerError.storageUnavailable }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            configuration = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("shared.store"), cloudKitDatabase: .none)
        }
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func records() throws -> [SharedStoredRecord] { try context.fetch(FetchDescriptor<SharedStoredRecord>()) }
    func record(_ key: String) throws -> SharedStoredRecord? {
        var descriptor = FetchDescriptor<SharedStoredRecord>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
    func save() throws {
        do { try context.save() } catch { context.rollback(); throw error }
    }
}

enum SharedLedgerError: LocalizedError {
    case invalidAmount, invalidInput, storageUnavailable, noAccount, noAccess, pendingChanges, unsupportedVersion, wrongInvitation

    /// True when the cause is something the user typed or chose, not a transport,
    /// account or storage fault. These are reported on the screen they came from.
    var isUserInput: Bool {
        switch self {
        case .invalidAmount, .invalidInput, .wrongInvitation: return true
        case .storageUnavailable, .noAccount, .noAccess, .pendingChanges, .unsupportedVersion: return false
        }
    }

    var errorDescription: String? {
        let he = AppLanguage.current == .hebrew
        switch self {
        case .invalidAmount: return he ? "יש להזין סכום תקין שאינו אפס." : "Enter a valid non-zero amount."
        case .invalidInput: return he ? "יש לבדוק את שם העסק, התאריך והמשלם." : "Check the merchant, date and payer."
        case .storageUnavailable: return he ? "המידע המשותף אינו זמין כרגע. הנתונים האישיים שמורים." : "Shared storage is unavailable. Personal data is preserved."
        case .noAccount: return he ? "יש להתחבר ל־iCloud כדי להפעיל שיתוף." : "Sign in to iCloud to enable sharing."
        case .noAccess: return he ? "אין הרשאת עריכה למרחב הזה." : "You do not have write access to this space."
        case .pendingChanges: return he ? "יש שינויים שטרם הסתנכרנו. יש לסנכרן לפני היציאה." : "Sync pending changes before leaving."
        case .unsupportedVersion: return he ? "נדרש עדכון לאפליקציה כדי לערוך מרחב זה." : "Update the app before editing this space."
        case .wrongInvitation: return he ? "ההזמנה אינה למרחב SPENT נתמך." : "This invitation is not for a supported SPENT space."
        }
    }
}
