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

    /// The space's monthly target, or `nil` when it has none.
    ///
    /// The single place a shared target is read from, so no view can reach for the personal
    /// `monthly_budget` while looking at a space. A stored zero or negative is treated as
    /// "no target" rather than a target of zero, which would render as an instantly
    /// over-spent month.
    var monthlyTarget: Int64? {
        guard let minor = monthlyBudgetMinor, minor > 0 else { return nil }
        return minor
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

    /// Whether this record is still waiting on a currency conversion.
    ///
    /// Mirrors `Transaction.isUnresolvedForeign`, but measures against the *space's*
    /// currency instead of the personal base: shared money is never converted into the
    /// personal one. An amount typed in a foreign currency with no rate applied has no
    /// honest value in the space's currency, so counting it as spend would quietly
    /// invent a conversion.
    ///
    /// Needed here rather than read off `ExpenseSnapshot`, which hardcodes
    /// `isUnresolvedForeign = false` for shared records and therefore cannot see it.
    var isUnresolvedForeign: Bool {
        guard let original = originalCurrency, !original.isEmpty else { return false }
        let spaceCode = currencyCode.uppercased()
        let originalCode = (CurrencyResolutionService.normalizeToISOCode(original) ?? original).uppercased()
        guard originalCode != spaceCode else { return false }
        let rate = exchangeRate.flatMap { Double($0) }
        return rate == nil || rate == 0
    }
}

/// One member's signed share of a space's month.
struct SharedMemberTotal: Identifiable, Equatable {
    let memberID: String
    let name: String
    let colorHex: String
    /// Net paid, signed: a refund to this member comes straight off it, so the value can
    /// be zero or negative. Deliberately never clamped — Profile reports the ledger, and
    /// turning a real negative into a zero would misstate what happened.
    let amountMinor: Int64

    var id: String { memberID }
}

/// A space's month, read once so every surface reports the same numbers.
///
/// The rules that matter, in one place so a view cannot get them subtly wrong:
///
/// * Only the given space. Another space's spending is never mixed in.
/// * The month is the space's own calendar and time zone, not `Calendar.current`, so a
///   record on the last night of the month belongs to the month the residents would name.
/// * Refunds stay signed and reduce the month's spend and the member who paid them.
/// * Unresolved foreign records are counted but not summed: the count keeps reflecting the
///   record, the money stays out until there is a rate.
/// * A member with no spending still appears, at zero.
/// * Spend paid by someone who is not a current member counts toward the month but is
///   attributed to nobody, so a shared payer arriving later cannot shrink the total.
struct SharedMonthlySummary: Equatable {
    let spaceID: UUID
    let spentMinor: Int64
    let transactionCount: Int
    let unresolvedCount: Int
    let memberTotals: [SharedMemberTotal]
    let unattributedMinor: Int64
    let progress: SharedBudgetProgress
    /// Money set aside under the savings category this month.
    ///
    /// Reported rather than derived, because the space's month is the ledger's month: this
    /// money really did leave the account and the target covers it. A category breakdown,
    /// on the other hand, only breaks down what was spent and leaves savings out. A screen
    /// showing both needs to be able to name the reason instead of leaving two totals that
    /// do not match.
    let savingsMinor: Int64

    /// The sum actually attributed to members. Lower than `spentMinor` when something was
    /// paid by a non-member.
    var attributedMinor: Int64 {
        memberTotals.reduce(0) { $0 + $1.amountMinor }
    }

    /// Whether member spending can honestly be drawn as shares of the month.
    ///
    /// A share answers "what part of the whole is this?", and the whole has to be a real
    /// whole for the answer to mean anything. It is not when the month's net is not
    /// positive, when a refund has pushed someone below zero — a negative share of a
    /// positive total reads as a smaller contribution, not as money coming back — or when
    /// part of the month was paid by somebody outside the member list, because the visible
    /// bars would not add up to the month they sit under.
    ///
    /// Amounts are always safe to show. These are not, so callers fall back to amounts.
    var canShowMemberShares: Bool {
        guard spentMinor > 0, unattributedMinor == 0 else { return false }
        return memberTotals.allSatisfy { $0.amountMinor >= 0 }
    }

    static func month(of space: SharedSpace,
                      expenses: [SharedExpense],
                      members: [SharedMember],
                      now: Date = Date()) -> SharedMonthlySummary {
        let calendar = space.calendar
        let inMonth = expenses.filter {
            $0.spaceID == space.id && calendar.isDate($0.date, equalTo: now, toGranularity: .month)
        }
        let resolvable = inMonth.filter { !$0.isUnresolvedForeign }
        let activeMembers = members.filter { $0.spaceID == space.id && $0.isActive }
        let memberIDs = Set(activeMembers.map(\.id))

        var totals: [String: Int64] = [:]
        var unattributed: Int64 = 0
        for expense in resolvable {
            if memberIDs.contains(expense.paidBy) {
                totals[expense.paidBy, default: 0] += expense.amountMinor
            } else {
                unattributed += expense.amountMinor
            }
        }

        let memberTotals = activeMembers.map { member in
            SharedMemberTotal(memberID: member.id,
                              name: member.name,
                              colorHex: member.colorHex,
                              amountMinor: totals[member.id] ?? 0)
        }
        let spent = resolvable.reduce(Int64(0)) { $0 + $1.amountMinor }
        let savings = resolvable.filter { $0.category.canonical == .savings }
            .reduce(Int64(0)) { $0 + $1.amountMinor }

        return SharedMonthlySummary(spaceID: space.id,
                                    spentMinor: spent,
                                    transactionCount: inMonth.count,
                                    unresolvedCount: inMonth.count - resolvable.count,
                                    memberTotals: memberTotals,
                                    unattributedMinor: unattributed,
                                    progress: space.progress(spentMinor: spent),
                                    savingsMinor: savings)
    }
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

    /// Starting points offered when a space sets its monthly target.
    ///
    /// Chosen as whole currency units and converted through `minor`, which is the only
    /// part that has to know the currency. Holding them as raw minor units instead was
    /// wrong: a minor unit *is* a whole unit in a zero-decimal currency, so ¥500,000
    /// would have been offered as a monthly target.
    private static let presetUnits: [Int64] = [5_000, 8_000, 12_000, 15_000]

    static func monthlyTargetPresets(currency: String) -> [Int64] {
        presetUnits.compactMap { try? minor(String($0), currency: currency) }
    }

    /// The currency's symbol for display beside an amount, e.g. "₪" or "$".
    static func symbol(_ currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.currencySymbol ?? currency
    }

    /// Groups the major amount for reading — "8,000", not "8000". Digits still come from
    /// the currency, so a zero-decimal currency is not given phantom decimals.
    static func formattedMajor(_ minor: Int64, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = digits(currency)
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: major(minor, currency: currency)))
            ?? String(Int64(major(minor, currency: currency)))
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
