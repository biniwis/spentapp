#if !SWIFT_PACKAGE
import SwiftUI
import SwiftData
#if canImport(UserNotifications)
import UserNotifications
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if canImport(UserNotifications)
        NotificationService.setupDelegate()
        #endif
        return true
    }
}

@main
struct MoneyCityApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var l10n = LocalizationManager.shared

    var body: some Scene {
        WindowGroup {
            MainCityView()
                // Sits over the city rather than in a settings screen: in the memory-only
                // case every second the user spends typing an expense is wasted, so the
                // warning has to be the first thing on screen, not something to go find.
                .overlay(alignment: .top) {
                    if DatabaseService.shared.storageMode != .persistent {
                        StorageHealthBanner(mode: DatabaseService.shared.storageMode)
                    }
                }
                .preferredColorScheme(.light)
                .moneyCityFont()
                .environment(\.layoutDirection, l10n.layoutDirection)
                .environment(\.locale, Locale(identifier: l10n.language.rawValue))
                .onChange(of: l10n.language) { _, language in
                    NotificationService.sync(enabled: NotificationService.isEnabled, isHebrew: language == .hebrew)
                }
                .environmentObject(l10n)
                .onAppear {
                    // Background fetch latest currency exchange rates
                    Task {
                        await FXService.shared.fetchLatestRatesIfNeeded()
                    }

                    // Age out stale raw payloads even if no new one has arrived.
                    DatabaseService.shared.pruneIngestLog()

                    // Post any fixed expenses that came due while the app was closed.
                    RecurringExpenseService.materializeDue(context: DatabaseService.shared.context)

                    // Post any installment charges that came due while the app was closed.
                    InstallmentService.materializeDue(context: DatabaseService.shared.context)

                    // Reconcile savings goals in background to ensure 100% parity with ledger.
                    SavingsGoalService.reconcileAll(context: DatabaseService.shared.context)

                    NotificationService.sync(
                        enabled: NotificationService.isEnabled,
                        isHebrew: l10n.language == .hebrew
                    )
                    
                    MoneyCityShortcuts.updateAppShortcutParameters()
                    syncPendingWidgetTransactions()
                    Task {
                        await WalletIngestCoordinator.drainPendingBackgroundCompletions()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        syncPendingWidgetTransactions()
                        Task {
                            await WalletIngestCoordinator.drainPendingBackgroundCompletions()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
                    Task {
                        await WalletIngestCoordinator.drainPendingBackgroundCompletions()
                    }
                }
                .onOpenURL { url in
                    Task {
                        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }
                        let amount = MoneyAmount.sanitized(components.queryItems?.first(where: { $0.name == "amount" })?.value.flatMap(Double.init))
                        let merchant = components.queryItems?.first(where: { $0.name == "merchant" })?.value
                        let currency = components.queryItems?.first(where: { $0.name == "currency" })?.value
                        if amount != nil || merchant != nil {
                            _ = await WalletIngestCoordinator.run(
                                amount: amount,
                                amountText: nil,
                                merchant: merchant,
                                currency: currency,
                                transactionDate: Date()
                            )
                        }
                    }
                }
        }
        .modelContainer(DatabaseService.shared.container)
    }
    
    private func syncPendingWidgetTransactions() {
        let defaults = UserDefaults(suiteName: "group.com.moneycity.app") ?? UserDefaults.standard
        guard let pending = defaults.array(forKey: "pending_widget_transactions") as? [[String: Any]], !pending.isEmpty else { return }
        defaults.removeObject(forKey: "pending_widget_transactions")
        Task {
            for item in pending {
                let amount = item["amount"] as? Double
                let merchant = item["merchant"] as? String
                let timestamp = (item["date"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) } ?? Date()
                if amount != nil || merchant != nil {
                    _ = await WalletIngestCoordinator.run(
                        amount: amount,
                        amountText: nil,
                        merchant: merchant,
                        currency: nil,
                        transactionDate: timestamp,
                        intentName: "QuickExpenseWidgetIntent"
                    )
                }
            }
        }
    }
}
#endif
