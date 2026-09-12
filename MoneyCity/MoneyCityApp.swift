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

    #if DEBUG
    @State private var qaRecap: MonthlyRecap? = nil
    @State private var qaShowDesignLab = false
    #endif

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
            #if DEBUG
            configureDebugLaunchRoute()
            #endif
        }
        #if DEBUG
        .fullScreenCover(item: $qaRecap) { recap in
            MonthlyRecapSheet(recap: recap, onNavigateToCity: nil)
                .environmentObject(LocalizationManager.shared)
        }
        .sheet(isPresented: $qaShowDesignLab) {
            DesignLabView()
                .environmentObject(LocalizationManager.shared)
        }
        #endif
    }

    #if DEBUG
    private func configureDebugLaunchRoute() {
        let args = ProcessInfo.processInfo.arguments
        for arg in args where arg.hasPrefix("-openRecapQA=") {
            guard let kind = RecapLabKind(rawValue: String(arg.dropFirst("-openRecapQA=".count))) else { continue }
            let recap = RecapPreviewData.recap(kind: kind)
            DispatchQueue.main.async {
                qaRecap = recap
            }
            return
        }
        if args.contains("-openDesignLab") {
            DispatchQueue.main.async {
                qaShowDesignLab = true
            }
        }
    }
    #endif

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
                    performAppMaintenance()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        performAppMaintenance()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
                    Task {
                        await WalletIngestCoordinator.drainPendingBackgroundCompletions()
                    }
                }
                .onOpenURL { url in
                    guard let scheme = url.scheme?.lowercased(),
                          scheme == "spentapp" || scheme == "moneycity" else { return }
                    // Deep links must never silently inject financial transactions into the ledger.
                    // Legitimate navigation deep links can be handled safely without silent financial writes.
                }
        }
        .modelContainer(DatabaseService.shared.container)
    }

    private func performAppMaintenance() {
        // Background fetch latest currency exchange rates
        Task {
            await FXService.shared.fetchLatestRatesIfNeeded()
        }

        // Age out stale raw payloads even if no new one has arrived.
        DatabaseService.shared.pruneIngestLog()

        // Post any fixed expenses that came due while the app was closed/backgrounded.
        RecurringExpenseService.materializeDue(context: DatabaseService.shared.context)

        // Post any installment charges that came due while the app was closed/backgrounded.
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
    
    private func syncPendingWidgetTransactions() {
        Task {
            await WidgetTransactionQueue.drain()
        }
    }
}

// MARK: - Durable Widget Transaction Queue

public enum WidgetTransactionQueue {
    public static let key = "pending_widget_transactions"

    /// Migrates any legacy entries missing an "id" field by assigning a stable UUID.
    /// Filters out irrecoverably malformed items (missing both amount and merchant, or invalid structure)
    /// so they do not poison the queue.
    public static func sanitizeAndMigrate(raw: [[String: Any]]) -> (valid: [[String: Any]], malformedCount: Int) {
        var valid: [[String: Any]] = []
        var malformed = 0

        for var item in raw {
            let amount = item["amount"] as? Double
            let merchant = item["merchant"] as? String

            // An item is irrecoverably malformed if it has neither amount nor merchant
            guard amount != nil || (merchant != nil && !merchant!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) else {
                malformed += 1
                continue
            }

            // Assign stable ID if missing from legacy formats
            if (item["id"] as? String)?.isEmpty ?? true {
                item["id"] = UUID().uuidString
            }
            valid.append(item)
        }

        return (valid, malformed)
    }

    @MainActor
    public static func drain(
        defaults: UserDefaults = UserDefaults(suiteName: "group.com.moneycity.app") ?? .standard,
        ingestHandler: ((_ amount: Double?, _ merchant: String?, _ timestamp: Date) async -> Bool)? = nil
    ) async {
        #if canImport(UIKit)
        guard UIApplication.shared.isProtectedDataAvailable else { return }
        #endif

        if ingestHandler == nil {
            guard !DatabaseService.shared.isEphemeral else { return }
        }

        guard let raw = defaults.array(forKey: key) as? [[String: Any]], !raw.isEmpty else { return }

        let (migrated, malformedCount) = sanitizeAndMigrate(raw: raw)
        if malformedCount > 0 || migrated.count != raw.count || raw.contains(where: { ($0["id"] as? String) == nil }) {
            defaults.set(migrated, forKey: key)
        }

        guard !migrated.isEmpty else { return }

        var remaining = migrated
        for item in migrated {
            guard let itemId = item["id"] as? String else { continue }
            let amount = item["amount"] as? Double
            let merchant = item["merchant"] as? String
            let timestamp = (item["date"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) } ?? Date()

            let succeeded: Bool
            if let customHandler = ingestHandler {
                succeeded = await customHandler(amount, merchant, timestamp)
            } else {
                let result = await WalletIngestCoordinator.run(
                    amount: amount,
                    amountText: nil,
                    merchant: merchant,
                    currency: nil,
                    transactionDate: timestamp,
                    intentName: "QuickExpenseWidgetIntent"
                )
                succeeded = result.succeeded
            }

            if succeeded {
                remaining.removeAll(where: { ($0["id"] as? String) == itemId })
                defaults.set(remaining, forKey: key)
            } else {
                // Preserve this item and all remaining items for the next cycle
                break
            }
        }
    }
}
#endif
