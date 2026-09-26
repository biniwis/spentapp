import Foundation
import SwiftData
import CloudKit

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

/// The plain reading of how much of a shared month's target has been used.
///
/// A tier describes pace, not worth: none of these are good or bad outcomes, they are where
/// this month happens to sit. `noTarget` is a real state rather than an absent value, so a
/// space that never set a target cannot end up drawn as though it had used none of one —
/// zero spent against a target nobody chose is not an achievement.
enum SharedParkTier: String, Equatable, Sendable {
    case noTarget
    case early
    case comfortable
    case even
    case close
    case over

    init(fraction: Double?) {
        guard let fraction else { self = .noTarget; return }
        switch fraction {
        case ..<0.25: self = .early
        case ..<0.5: self = .comfortable
        case ..<0.75: self = .even
        case ...1.0: self = .close
        default: self = .over
        }
    }
}

/// What a shared month has done to its target, and what the park should say about it.
///
/// One number, one meaning. The same ratio always lands in the same tier, and because the
/// ratio is read from the month the summary describes, a state can never be carried over
/// from a month that has already ended — the city resets with the calendar.
///
/// The tier exists for people; the renderer reads health. Both come from the same
/// fraction so the wording and the garden can never drift apart.
struct SharedParkState: Equatable, Sendable {
    /// Share of the target spent, uncapped and floored at zero: a month whose refunds
    /// outweigh its spending has used none of its target, whatever the signs work out to.
    /// `nil` when the space has not set a target.
    let fraction: Double?
    let tier: SharedParkTier

    init(fraction: Double?) {
        guard let fraction, fraction.isFinite else {
            self.fraction = nil
            self.tier = .noTarget
            return
        }
        let used = max(0, fraction)
        self.fraction = used
        self.tier = SharedParkTier(fraction: used)
    }

    /// The health the diorama renders, or `nil` when the space has no target to read.
    ///
    /// The range is the renderer's own: 0 is parched, 1 is lush, and a normally-run month
    /// sits near 0.78. A month that has barely touched its target opens at the calm end and
    /// the target itself lands in the "active" band, so the garden's usual resting look
    /// corresponds to a month a little over half way through its plan. Past the target it
    /// settles toward a floor well clear of parched, because spending more than planned is
    /// something the residents should be able to see rather than a punishment to render.
    var parkHealth: Double? {
        guard let fraction else { return nil }
        let span = 1.25
        return 0.95 - 0.62 * (min(fraction, span) / span)
    }

    /// What the renderer should be told when there is no number to send.
    ///
    /// nil in every month with a real reading, so the renderer's existing graded path is
    /// untouched; `.neutral` only for a space that has set no target, where the honest
    /// answer is a park that says nothing rather than a number that claims something.
    var rendererMode: CityParkMode? {
        parkHealth == nil ? .neutral : nil
    }
}

/// Who paid at each venue, drawn as accents on buildings the space already has.
///
/// One pass over the month, grouped by venue and payer. The per-venue, per-member form of
/// this walked the whole month again for every pair, and that cost is paid on every render;
/// the numbers came out the same, so nothing about the picture depends on it.
///
/// Unresolved foreign records carry no honest value in the space's currency yet, so they
/// are left out of the weighting entirely rather than counted at face value. Refunds stay
/// signed while they are summed, so a refund comes off whoever paid it, and only the
/// finished weight is floored: somebody refunded past what they spent is not drawn as
/// having contributed a little, and not drawn as having contributed at all. When nobody
/// has a positive weight the venue simply carries no member colours, rather than splitting
/// a share between people who are not in it.
enum SharedCityMemberShares {
    static func applying(to venues: [CityVenueState],
                         members: [SharedMemberTotal],
                         expenses: [ExpenseSnapshot]) -> [CityVenueState] {
        let memberIDs = Set(members.map(\.memberID))
        var paidByVenue: [String: [String: Double]] = [:]
        if !memberIDs.isEmpty {
            for expense in expenses {
                guard !expense.isUnresolvedForeign, let payer = expense.paidBy,
                      memberIDs.contains(payer) else { continue }
                paidByVenue[expense.buildingId, default: [:]][payer, default: 0] += expense.amount
            }
        }
        return venues.map { venue in
            var result = venue
            let paid = paidByVenue[venue.id] ?? [:]
            let weights = members.compactMap { member -> (member: SharedMemberTotal, weight: Double)? in
                let net = paid[member.memberID] ?? 0
                guard net > 0, net.isFinite else { return nil }
                return (member, net)
            }
            let total = weights.reduce(0) { $0 + $1.weight }
            guard total > 0 else {
                result.memberShares = nil
                return result
            }
            result.memberShares = weights.map {
                CityMemberShare(memberID: $0.member.memberID, color: $0.member.colorHex, share: $0.weight / total)
            }
            return result
        }
    }
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

        // Who belongs to *this* month, which is not the same question as who is in the
        // space today.
        //
        // Somebody who paid in August and has since left the space is still one of the
        // people August happened to. Dropping them the moment they became inactive turned
        // their spending into money belonging to nobody: it vanished from the breakdown,
        // left the remaining members' shares adding up to less than the month, and could
        // silently switch the whole member breakdown off. So the list is everyone who is
        // here now, plus everyone who actually paid in the month being summarised, active
        // or not.
        //
        // This is history, not membership. Nothing here puts anybody back in the payer
        // list, the member list or anyone's permissions — those read `isActive` from the
        // store and are untouched by how a past month is reported. It is also why the
        // month being summarised is the only thing that decides: a member inactive today
        // who paid in a month Analytics is browsing still appears in that month.
        let spaceMembers = members.filter { $0.spaceID == space.id }
        let payersThisMonth = Set(inMonth.map(\.paidBy))
        var seen = Set<String>()
        let participants = spaceMembers.filter { member in
            // Deduplicated by ID: two records for one person are one person, and a month
            // that listed them twice would show their spending twice.
            guard seen.insert(member.id).inserted else { return false }
            return member.isActive || payersThisMonth.contains(member.id)
        }
        let memberIDs = Set(participants.map(\.id))

        var totals: [String: Int64] = [:]
        var unattributed: Int64 = 0
        for expense in resolvable {
            if memberIDs.contains(expense.paidBy) {
                totals[expense.paidBy, default: 0] += expense.amountMinor
            } else {
                // Only money whose payer cannot be resolved to somebody who was ever in
                // this space. Being inactive is not a reason to stop being a payer.
                unattributed += expense.amountMinor
            }
        }

        let memberTotals = participants.map { member in
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

/// A join that has started but not finished, kept so a one-time invitation cannot be
/// spent without producing a member.
///
/// Accepting a share is irreversible and happens on CloudKit's side, while everything that
/// makes the user a *named* member happens locally afterwards. If the app dies between
/// those two points, the invitation is already consumed: the user holds a link that can
/// never work again, and the space lists them as a participant with no name, no colour and
/// no ability to be picked as a payer. Recording the intent before the irreversible call
/// means the second half can be finished on the next launch instead of being lost.
///
/// Deliberately holds no URL, token or share metadata. Resuming needs to know *which*
/// space and *what name*, never to be able to replay the invitation itself.
@Model
final class SharedPendingJoin {
    @Attribute(.unique) var spaceID: String
    var memberName: String
    /// Set once CloudKit has accepted, so a relaunch knows to go straight to finishing
    /// rather than trying to accept a share that is already accepted.
    var acceptedAt: Date?
    init(spaceID: String, memberName: String, acceptedAt: Date? = nil) {
        self.spaceID = spaceID
        self.memberName = memberName
        self.acceptedAt = acceptedAt
    }
}

/// The order a durable join has to happen in.
///
/// Accepting a share is the one irreversible step: it consumes a one-time invitation and
/// cannot be replayed. Everything the user actually gets out of it — a name, a colour, the
/// ability to be picked as a payer, an openable space — happens locally afterwards and can
/// fail on its own. Writing the intent down first is what makes the second half reachable
/// again, so the order matters and is pinned here rather than left to the call site.
enum SharedJoin {
    enum Step: Equatable {
        /// Nothing recorded yet: write the intent before touching CloudKit.
        case beginIntent
        /// The intent is on disk but CloudKit has not accepted yet.
        case accept
        /// CloudKit accepted; the local half still has to be finished.
        case finish
        /// Nothing left to do.
        case done
    }

    static func next(hasIntent: Bool, cloudAccepted: Bool) -> Step {
        if !hasIntent { return .beginIntent }
        return cloudAccepted ? .finish : .accept
    }

    /// Whether the user may be put into the space yet.
    ///
    /// A space that CloudKit has accepted but not yet materialised in this account's
    /// listing is not somewhere the app can send anybody, and a member row that does not
    /// exist is not somebody who can be chosen as a payer. So entering requires all three,
    /// and in particular the member: this is the state that used to be skipped, leaving a
    /// participant with no name and no way to assign spending to anybody.
    static func canActivate(materialized: Bool, canWrite: Bool, memberWritten: Bool) -> Bool {
        materialized && canWrite && memberWritten
    }
}

/// When returning to the foreground should trigger a shared sync pass.
///
/// Push is the fast path, but a push can be delayed, coalesced away, or never arrive at
/// all — offline when the edit happened, notification delivery declined, the device
/// rebooted. Coming back to the app is therefore the one moment every device is guaranteed
/// to reach, and it is where anything missed gets picked up.
///
/// The decision is kept here, away from SwiftUI and CloudKit, because the two ways of
/// getting it wrong are both easy and both invisible until they show up as a support
/// report: never refreshing, so a space silently goes stale; and refreshing on every
/// transition, so flicking between apps hammers CloudKit and burns battery.
enum SharedForegroundSync {
    /// Two activations closer together than this are treated as one. Long enough that
    /// switching apps does not re-fetch, short enough that a genuine return to the app
    /// still converges.
    static let minimumInterval: TimeInterval = 20

    static func shouldRefresh(hasSharedState: Bool, lastRefresh: Date?, now: Date,
                              interval: TimeInterval = minimumInterval) -> Bool {
        // A personal-only user pays nothing: no shared account means no round trip, no
        // wait, and no alert.
        guard hasSharedState else { return false }
        guard let lastRefresh else { return true }
        return now.timeIntervalSince(lastRefresh) >= interval
    }
}

enum SharedSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [SharedStoredRecord.self, SharedEngineState.self, SharedPendingJoin.self] }
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
    /// CloudKit saved the share but produced no URL to hand over. Never swallowed: a
    /// missing link is a failed invite, and the user has to hear it.
    case inviteLinkUnavailable
    /// One-time URL participants can be created from iOS 18, but reading the URL back
    /// out of the saved share is only exposed to Swift from iOS 26. On 17–25 there is no
    /// compliant way to produce a link for an arbitrary recipient, so the action is
    /// refused outright rather than falling back to a share URL that would not reach
    /// them, and the user is pointed at Apple's own sharing sheet instead.
    case inviteLinkUnsupported

    /// True when the cause is something the user typed or chose, not a transport,
    /// account or storage fault. These are reported on the screen they came from.
    var isUserInput: Bool {
        switch self {
        case .invalidAmount, .invalidInput, .wrongInvitation: return true
        case .storageUnavailable, .noAccount, .noAccess, .pendingChanges, .unsupportedVersion,
             .inviteLinkUnavailable, .inviteLinkUnsupported: return false
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
        case .inviteLinkUnavailable: return he ? "לא ניתן היה ליצור קישור הזמנה. נסו שוב." : "Could not create an invitation link. Try again."
        case .inviteLinkUnsupported: return he ? "קישורי הזמנה זמינים ב־iOS 26 ומעלה. אפשר להזמין דרך ניהול השיתוף של Apple." : "Invitation links need iOS 26 or later. You can still invite through Apple sharing management."
        }
    }
}

/// What it takes to hand somebody a link they can actually open.
///
/// The CloudKit round trip lives in `SharedWorkspaceStore`; the decisions live here so
/// they can be tested without an account, a network, or a shared zone.
enum SharedInvitation {
    /// Whether an invitation link may be produced at all.
    ///
    /// A demo space has no CloudKit share to invite anyone to, and a member of someone
    /// else's space does not get to widen it, so both are refused before any network
    /// call and before a participant is added to anything.
    static func validate(isDemo: Bool, isOwner: Bool, hasPendingLocalChanges: Bool) throws {
        if isDemo { throw SharedLedgerError.noAccount }
        guard isOwner else { throw SharedLedgerError.noAccess }
        // Adding a participant while local edits are still queued would leave the
        // invitation and the space disagreeing about what members can see.
        if hasPendingLocalChanges { throw SharedLedgerError.pendingChanges }
    }

    /// The share must stay private. Invitation links do not need a public share, and a
    /// public one would quietly open the space's expenses to anyone with the link.
    static func ensurePrivate(_ permission: CKShare.ParticipantPermission) throws {
        guard permission == .none else { throw SharedLedgerError.noAccess }
    }

    /// A link the user never receives is a failed invite, not a silent no-op.
    static func requireLink(_ url: URL?) throws -> URL {
        guard let url else { throw SharedLedgerError.inviteLinkUnavailable }
        return url
    }

    /// A pasted link with a trailing space or newline is a typo, not a broken
    /// invitation, and CloudKit rejects the untrimmed form.
    static func pastedURL(_ input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let link = URL(string: trimmed), link.scheme == "https",
              link.host?.isEmpty == false else { return nil }
        return link
    }
}

/// What a failed save means, and therefore what must be done to the queued change.
///
/// A transport or server problem is not a lost space. Treating every error other than
/// `zoneNotFound` as a revocation used to hide a user's own space and dequeue their
/// pending write on a single dropped connection, which is indistinguishable, from the
/// outside, from deleting their work. Only positive evidence that access is gone may
/// take a space away; everything else stays queued and waits for CloudKit to retry.
enum SharedSyncFailure {
    /// Keep the change queued and let CloudKit retry. Never revokes, never dequeues.
    case retryable
    /// The account is not usable right now. Local data and pending writes are kept; the
    /// space is not revoked, because signing back in must not require a new invitation.
    case accountRequired
    /// The account is out of room. The write is still worth keeping — the user can free
    /// space and it will upload — so this reports without revoking or dequeuing.
    case quotaExceeded
    /// The server copy is newer. The caller keeps both versions and asks the user.
    case conflict
    /// The zone is not in the listing. CloudKit's own listing can lag a zone it has just
    /// written, so this is counted and only believed once it repeats.
    case zoneMissing
    /// Positive evidence that this account can no longer reach the zone.
    case accessRevoked
    /// Not understood. Treated as retryable so an unrecognised fault can never destroy
    /// queued work; being wrong here costs a retry, being wrong the other way costs data.
    case unknown

    /// Whether a space may be taken away on the strength of this failure.
    var mayRevokeSpace: Bool { self == .accessRevoked }

    /// Whether the pending change must stay in the engine queue.
    ///
    /// Everything except a genuine access loss keeps its place, including quota and
    /// account faults: the write is still correct, and dropping it would silently discard
    /// an expense the user entered.
    var keepsPendingChange: Bool { self != .accessRevoked }

    /// A human-readable reason, or nil when there is nothing worth interrupting for.
    ///
    /// A conflict and a missing zone are already represented in the UI, and a plain
    /// retryable blip should not raise an alert, so neither speaks.
    var reportText: String? {
        let he = AppLanguage.current == .hebrew
        switch self {
        case .retryable, .zoneMissing, .conflict: return nil
        case .accountRequired: return he ? "יש להתחבר ל־iCloud כדי להמשיך לסנכרן. השינויים נשמרו." : "Sign in to iCloud to keep syncing. Your changes are saved."
        case .quotaExceeded: return he ? "אין מספיק מקום ב־iCloud. השינויים נשמרו ויישלחו לאחר פינוי מקום." : "iCloud storage is full. Your changes are saved and will upload once space is freed."
        case .accessRevoked: return he ? "הגישה למרחב הוסרה." : "Access to this space was removed."
        case .unknown: return he ? "סנכרון המרחב נכשל. השינויים נשמרו." : "Shared sync failed. Your changes are saved."
        }
    }
}

/// Decides what a failed CloudKit save means. Pure, so it can be tested without an
/// account, a network or a zone.
enum SharedSyncClassifier {
    static func classify(_ code: CKError.Code) -> SharedSyncFailure {
        switch code {
        // A zone CloudKit has just saved can answer `zoneNotFound` until its own listing
        // catches up, so this is counted rather than believed on sight.
        case .zoneNotFound:
            return .zoneMissing
        case .serverRecordChanged:
            return .conflict
        // No usable session. Signing back in has to be enough to carry on, so the space
        // and the queue are both left alone.
        case .notAuthenticated:
            return .accountRequired
        case .quotaExceeded, .limitExceeded:
            return .quotaExceeded
        // Positive evidence that this account can no longer reach the zone: a share the
        // owner deleted, a participant the owner removed, a zone the owner deleted, or a
        // permission CloudKit refuses outright.
        case .unknownItem, .userDeletedZone, .permissionFailure:
            return .accessRevoked
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited,
             .zoneBusy, .internalError, .partialFailure, .operationCancelled,
             .badContainer, .badDatabase, .serverRejectedRequest:
            return .retryable
        default:
            return .unknown
        }
    }
}
