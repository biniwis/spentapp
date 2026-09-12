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

/// Root route states for top-level application presentation
enum RootRoute {
    case resolving
    case onboarding
    case main
}

/// Root view determining top-level application presentation:
/// - Latched explicit route state resolved once on app startup
/// - New user: Full-screen OnboardingWizardView
/// - Returning / legacy user: MainCityView
struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("hasStartedOnboardingV2") private var hasStartedOnboardingV2: Bool = false
    @AppStorage("didMigrateLegacyMonthlyTargetIncome") private var didMigrateLegacyMonthlyTargetIncome: Bool = false
    @Environment(\.modelContext) private var modelContext
    @Query private var allTransactions: [Transaction]

    @State private var route: RootRoute = .resolving
    @State private var justCompletedOnboarding: Bool = false

    var body: some View {
        ZStack {
            switch route {
            case .resolving:
                Color.appBackground
                    .ignoresSafeArea()

            case .onboarding:
                OnboardingWizardView(
                    canDismiss: false,
                    onComplete: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasCompletedOnboarding = true
                            justCompletedOnboarding = true
                            route = .main
                        }
                    },
                    onTriggerSampleTransaction: {}
                )
                .transition(.opacity)

            case .main:
                MainCityView(skipBrandSplash: justCompletedOnboarding)
                    .overlay(alignment: .top) {
                        if DatabaseService.shared.storageMode != .persistent {
                            StorageHealthBanner(mode: DatabaseService.shared.storageMode)
                        }
                    }
                    .transition(.opacity)
            }
        }
        .onAppear {
            migrateLegacyMonthlyTargetIncomeIfNeeded()
            resolveInitialRoute()
        }
    }

    private func resolveInitialRoute() {
        guard route == .resolving else { return }

        if hasCompletedOnboarding {
            route = .main
        } else if hasStartedOnboardingV2 {
            // Once Onboarding V2 has started, background transactions must never cause it to be skipped as a legacy user
            route = .onboarding
        } else if !allTransactions.isEmpty {
            // Legacy user from older version before Onboarding V2 existed
            hasCompletedOnboarding = true
            route = .main
        } else {
            // New user starting Onboarding V2
            hasStartedOnboardingV2 = true
            route = .onboarding
        }
    }

    private func migrateLegacyMonthlyTargetIncomeIfNeeded() {
        guard !didMigrateLegacyMonthlyTargetIncome else { return }
        do {
            _ = try LegacyTargetIncomeMigration.migrate(in: modelContext)
            didMigrateLegacyMonthlyTargetIncome = true
        } catch {
            print("[Migration] Failed to migrate legacy income sources: \(error)")
        }
    }
}

enum LegacyTargetIncomeMigration {
    @discardableResult
    static func migrate(in context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<IncomeSource>()
        let items = try context.fetch(descriptor)
        var didDelete = false
        for item in items where item.name == "יעד חודשי" || item.name == "Monthly Target" {
            context.delete(item)
            didDelete = true
        }
        if didDelete {
            try context.save()
        }
        return didDelete
    }
}

@main
struct MoneyCityApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var l10n = LocalizationManager.shared

    var body: some Scene {
        WindowGroup {
            AppRootView()
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
