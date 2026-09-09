import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

public struct WalletIngestResult: Sendable {
    public let message: String
    public let succeeded: Bool
}

/// A synchronous main-actor transition owns validation, duplicate checking and commit.
/// No suspension is allowed between the duplicate check and save.
@MainActor
public final class IngestStateMachine {
    public enum State: String { case received, normalized, pending, finalized, duplicate, rejected, failed }
    public private(set) var states: [State] = [.received]
    public private(set) var ingestID = UUID()
    public enum Failure: Error { case pendingUnavailable, storageUnavailable }
    public enum Outcome {
        case finalized(Transaction)
        case pending(PendingWalletIngest, isNew: Bool)
        case duplicate
    }
    private let context: ModelContext
    private let pendingStore: PendingWalletStore
    private let commit: (ModelContext) throws -> Void

    public init(context: ModelContext, pendingStore: PendingWalletStore = .shared,
                commit: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.context = context
        self.pendingStore = pendingStore
        self.commit = commit
    }

    public func receive(amount: Double?, amountText: String?, merchant: String?, currency: String?,
                        date: Date?, source: String, pendingID: String? = nil) throws -> Outcome {
        states = [.received]
        guard !DatabaseService.shared.isEphemeral else {
            states.append(.failed)
            throw Failure.storageUnavailable
        }
        ingestID = pendingID.flatMap(UUID.init(uuidString:)) ?? UUID()
        let pending = pendingID.flatMap { pendingStore.get(id: $0) }
        // A repeated notification response after completion must not create a new expense.
        if pendingID != nil && pending == nil {
            let identity = ingestID
            do {
                if try context.fetchCount(FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == identity })) > 0 {
                    states.append(.duplicate)
                    return .duplicate
                }
            } catch {
                states.append(.failed)
                throw error
            }
            states.append(.rejected)
            throw Failure.pendingUnavailable
        }
        let resolvedDate = pending?.timestamp ?? TransactionIngest.sanitizedDate(date) ?? Date()
        let resolvedCurrency = pending?.currency ?? TransactionIngest.sanitizedCurrency(currency)
            ?? LocalizationManager.shared.baseCurrency.symbol
        let salvaged = TransactionIngest.salvage(amount: amount, amountText: amountText,
                                                 merchant: pending?.merchant ?? merchant)
        states.append(.normalized)
        do {
            let start = resolvedDate.addingTimeInterval(-TransactionIngest.duplicateWindow)
            let end = resolvedDate.addingTimeInterval(TransactionIngest.duplicateWindow)
            let recent = try context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate {
                $0.timestamp >= start && $0.timestamp <= end
            }))
            let rules = try context.fetch(FetchDescriptor<MerchantRule>())
            let transaction = try TransactionIngest.makeTransaction(
                amount: salvaged.amount, amountText: amountText, merchant: salvaged.merchant,
                currency: resolvedCurrency, date: resolvedDate, existing: recent,
                isRefundHint: salvaged.isRefund, rules: rules)
            transaction.id = ingestID
            // Stable identity protects completion retries even if a saved transaction was edited.
            let identity = ingestID
            if try context.fetchCount(FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == identity })) > 0 {
                if let pending { pendingStore.remove(id: pending.id) }
                states.append(.duplicate)
                return .duplicate
            }
            context.insert(transaction)
            do { try commit(context) }
            catch {
                // This context is dedicated to ingest; never roll back unrelated UI edits.
                context.rollback()
                throw error
            }
            if let pending { pendingStore.remove(id: pending.id) }
            states.append(.finalized)
            return .finalized(transaction)
        } catch TransactionIngestError.duplicate {
            if let pending { pendingStore.remove(id: pending.id) }
            states.append(.duplicate)
            return .duplicate
        } catch TransactionIngestError.missingAmount {
            let name = salvaged.merchant ?? "תשלום Apple Pay"
            let rules = try context.fetch(FetchDescriptor<MerchantRule>())
            let classification = MerchantRuleService.classify(merchant: name, amount: 0, rules: rules)
            let registration = pendingStore.findOrRegister(merchant: name, currency: resolvedCurrency,
                categoryRawValue: classification.category.rawValue, buildingId: classification.buildingId,
                date: resolvedDate, source: source, id: ingestID.uuidString)
            ingestID = UUID(uuidString: registration.ingest.id) ?? ingestID
            states.append(.pending)
            return .pending(registration.ingest, isNew: registration.isNew)
        } catch let error as TransactionIngestError {
            states.append(.rejected)
            throw error
        } catch {
            states.append(.failed)
            throw error
        }
    }
}

/// Both App Intents and notification completion use the same transition and commit.
public enum WalletIngestCoordinator {
    @MainActor
    public static func run(amount: Double?, amountText: String?, merchant: String?, currency: String?,
                           transactionDate: Date?, intentName: String = "RecordTransactionIntent",
                           pendingID: String? = nil) async -> WalletIngestResult {
        let context = ModelContext(DatabaseService.shared.container)
        context.autosaveEnabled = false
        let machine = IngestStateMachine(context: context)
        let log = IngestLogEntry(receivedAt: Date(), rawAmount: IngestLogEntry.describe(amount),
            rawAmountText: IngestLogEntry.describe(amountText), rawMerchant: IngestLogEntry.describe(merchant),
            rawCurrency: IngestLogEntry.describe(currency), rawDate: IngestLogEntry.describe(transactionDate),
            intentName: intentName)
        DatabaseService.shared.record(log)
        defer {
            log.outcome += "\ningestID=\(machine.ingestID.uuidString); \(machine.states.map(\.rawValue).joined(separator: " → "))"
            DatabaseService.shared.persist()
        }
        do {
            let outcome = try machine.receive(amount: amount, amountText: amountText, merchant: merchant,
                currency: currency, date: transactionDate, source: intentName, pendingID: pendingID)
            switch outcome {
            case .duplicate:
                log.outcome = "כפילות — לא נשמר שוב"
                return WalletIngestResult(message: "העסקה הזו כבר טופלה.", succeeded: true)
            case .pending(let pending, let isNew):
                if isNew {
                    #if canImport(UserNotifications)
                    NotificationService.sendMissingAmountNotification(pending: pending)
                    #endif
                }
                log.outcome = "ממתין לסכום"
                log.resolvedMerchant = pending.merchant
                return WalletIngestResult(message: isNew
                    ? "זוהה תשלום ב-\(pending.merchant). נשלחה בקשה להזנת הסכום."
                    : "כבר קיימת בקשה להזנת סכום עבור התשלום הזה.", succeeded: true)
            case .finalized(let transaction):
                let refund = transaction.amount < 0
                log.resolvedAmount = transaction.amount
                log.resolvedMerchant = transaction.merchant
                log.categoryDetected = transaction.category.shortName
                log.outcome = transaction.isConfirmed ? "נשמר בהצלחה" : "נשמר — ממתין לאישור"
                if let rule = MerchantRuleService.rule(for: transaction.merchant,
                                                       in: DatabaseService.shared.fetchMerchantRules()) {
                    rule.hitCount += 1
                }
                #if canImport(UserNotifications)
                NotificationService.sendExpenseLoggedNotification(amount: abs(transaction.amount),
                    currency: transaction.currency, categoryName: transaction.category.shortName,
                    merchant: transaction.merchant, isRefund: refund)
                CityNarrativeEngine.shared.onApplePayTransactionIngested(transactionDate: transaction.timestamp,
                    category: transaction.category, amount: abs(transaction.amount), currency: transaction.currency)
                #endif
                if pendingID != nil {
                    ExpenseConfirmationCoordinator.shared.queuePendingConfirmation(amount: abs(transaction.amount),
                        merchant: transaction.merchant, isRefund: refund)
                } else {
                    ExpenseConfirmationCoordinator.shared.triggerConfirmation(amount: abs(transaction.amount),
                        merchant: transaction.merchant, isRefund: refund)
                }
                let formatted = String(format: "%.2f", abs(transaction.amount))
                let review = transaction.isConfirmed ? "" : " ממתין לבדיקתך בהיסטוריה."
                return WalletIngestResult(message: "\(refund ? "נרשם זיכוי" : "נרשמה עסקה") ע״ס \(transaction.currency)\(formatted) ב-\(transaction.merchant).\(review)", succeeded: true)
            }
        } catch {
            log.outcome = "הקליטה נכשלה"
            log.failureReason = String(describing: error)
            return WalletIngestResult(message: "לא ניתן לשמור את העסקה. פרטי התקלה נשמרו ביומן הקליטה; אפשר לנסות שוב.", succeeded: false)
        }
    }

    // MARK: - Lock-Screen Durable Background Queue

    private static let backgroundQueueKey = "pending_background_completions"

    public static func enqueueBackgroundCompletion(
        amount: Double,
        merchant: String,
        currency: String,
        transactionDate: Date,
        pendingID: String
    ) {
        let defaults = UserDefaults(suiteName: "group.com.moneycity.app") ?? .standard
        var queue = loadBackgroundQueue(defaults: defaults)
        let item = PendingBackgroundCompletion(
            amount: amount,
            merchant: merchant,
            currency: currency,
            transactionDate: transactionDate,
            pendingID: pendingID
        )
        queue.append(item)
        saveBackgroundQueue(queue, defaults: defaults)
    }

    @MainActor
    public static func drainPendingBackgroundCompletions() async {
        #if canImport(UIKit)
        guard UIApplication.shared.isProtectedDataAvailable else { return }
        #endif

        guard !DatabaseService.shared.isEphemeral else { return }

        let defaults = UserDefaults(suiteName: "group.com.moneycity.app") ?? .standard
        let queue = loadBackgroundQueue(defaults: defaults)
        guard !queue.isEmpty else { return }

        var remaining = queue
        for item in queue {
            let result = await run(
                amount: item.amount,
                amountText: nil,
                merchant: item.merchant,
                currency: item.currency,
                transactionDate: item.transactionDate,
                intentName: "NotificationAmountCompletion",
                pendingID: item.pendingID
            )
            if result.succeeded {
                remaining.removeAll(where: { $0.id == item.id })
                saveBackgroundQueue(remaining, defaults: defaults)
            } else {
                // If a transient failure occurs, preserve this item and remaining queue for next attempt.
                break
            }
        }
    }

    private static func loadBackgroundQueue(defaults: UserDefaults) -> [PendingBackgroundCompletion] {
        guard let data = defaults.data(forKey: backgroundQueueKey),
              let list = try? JSONDecoder().decode([PendingBackgroundCompletion].self, from: data) else {
            return []
        }
        return list
    }

    private static func saveBackgroundQueue(_ list: [PendingBackgroundCompletion], defaults: UserDefaults) {
        if let encoded = try? JSONEncoder().encode(list) {
            defaults.set(encoded, forKey: backgroundQueueKey)
        }
    }
}

// MARK: - Pending Background Completion Model

public struct PendingBackgroundCompletion: Codable, Sendable {
    public let id: String
    public let amount: Double
    public let merchant: String
    public let currency: String
    public let transactionDate: Date
    public let pendingID: String

    public init(
        id: String = UUID().uuidString,
        amount: Double,
        merchant: String,
        currency: String,
        transactionDate: Date,
        pendingID: String
    ) {
        self.id = id
        self.amount = amount
        self.merchant = merchant
        self.currency = currency
        self.transactionDate = transactionDate
        self.pendingID = pendingID
    }
}
