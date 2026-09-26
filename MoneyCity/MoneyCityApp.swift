#if !SWIFT_PACKAGE
import SwiftUI
import SwiftData
#if canImport(UserNotifications)
import UserNotifications
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SharedSpaceSceneDelegate.self
        return configuration
    }
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if canImport(UserNotifications)
        NotificationService.setupDelegate()
        #endif
        // Registers the device with APNs so CloudKit can wake the app when a shared space
        // changes on another device.
        //
        // Deliberately *not* a notification authorization request. There is no
        // `requestAuthorization` anywhere near this call and there is no permission prompt:
        // this is the silent, background delivery CloudKit uses to tell CKSyncEngine to
        // fetch, and it carries nothing for the user to see. SPENT's own notification
        // preferences (NotificationService) are a separate, user-controlled feature and
        // stay exactly as they were.
        //
        // No backend is involved. The token CloudKit needs is exchanged between the system
        // and Apple's CloudKit infrastructure, so there is nowhere to upload it and nothing
        // to upload it to. Losing the token costs freshness, not correctness: the
        // foreground refresh in the scene-phase handler still converges local state, which
        // is why this is registered best-effort and never treated as a launch condition.
        application.registerForRemoteNotifications()
        return true
    }

    /// APNs registration failed. Logged, never surfaced: shared sync falls back to the
    /// foreground refresh, and personal money is entirely local, so there is nothing the
    /// user could do about this and nothing that is broken for them.
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        let reason = (error as NSError).code
        print("[SPENT] APNs registration unavailable (code \(reason)); shared sync will rely on foreground refresh")
    }
}

/// Root route states for top-level application presentation
enum RootRoute: Equatable {
    case resolving
    case checkingCloud
    case restorePrompt(CloudBackupDescriptor)
    case onboarding
    case main
}

struct CloudCheckingView: View {
    let onContinueWithoutRestore: () -> Void
    @EnvironmentObject private var l10n: LocalizationManager
    private var isHebrew: Bool { l10n.language == .hebrew }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(Color.primaryBlue)
                    .padding(.bottom, 8)

                Text(isHebrew ? "בודק גיבויים ב־iCloud…" : "Checking for iCloud backup…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(MoneyCityTheme.textSecondary)

                Button(action: onContinueWithoutRestore) {
                    Text(isHebrew ? "המשך ללא שחזור" : "Continue without restore")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.primaryBlue)
                        .padding(.top, 12)
                }
            }
            .padding(24)
        }
    }
}

struct CloudRestorePromptView: View {
    let descriptor: CloudBackupDescriptor
    let isRestoring: Bool
    let onRestore: () -> Void
    let onStartFresh: () -> Void

    @EnvironmentObject private var l10n: LocalizationManager
    private var isHebrew: Bool { l10n.language == .hebrew }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.primaryBlue.opacity(0.12))
                            .frame(width: 76, height: 76)
                        Image(systemName: "icloud.and.arrow.down.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(Color.primaryBlue)
                    }

                    VStack(spacing: 8) {
                        Text(isHebrew ? "מצאנו גיבוי של SPENT" : "SPENT Backup Found")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(MoneyCityTheme.textPrimary)

                        Text(isHebrew ? "מ־\(descriptor.displayDate)" : "From \(descriptor.displayDate)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.primaryBlue)

                        Text(isHebrew
                             ? "הגיבוי מכיל \(descriptor.recordCount) רשומות, הגדרות, יעדים והיסטוריית עיר שנשמרו ב־iCloud שלך."
                             : "Contains \(descriptor.recordCount) records, settings, goals, and city progress saved in your iCloud.")
                            .font(.system(size: 13))
                            .foregroundColor(MoneyCityTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.04), radius: 12, y: 4)
                )
                .padding(.horizontal, 20)

                Spacer()

                VStack(spacing: 12) {
                    Button(action: onRestore) {
                        HStack(spacing: 8) {
                            if isRestoring {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isHebrew ? "שחזר את הנתונים שלי" : "Restore My Data")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundColor(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.primaryBlue)
                        )
                    }
                    .disabled(isRestoring)

                    Button(action: onStartFresh) {
                        Text(isHebrew ? "התחל מחדש" : "Start Fresh")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(MoneyCityTheme.textSecondary)
                            .padding(.vertical, 10)
                    }
                    .disabled(isRestoring)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

/// Root view determining top-level application presentation:
/// - Latched explicit route state resolved once on app startup
/// - New user with iCloud backup: Guided restore offer
/// - Clean install without backup: Full-screen OnboardingWizardView
/// - Returning / legacy user: MainCityView
struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("hasStartedOnboardingV2") private var hasStartedOnboardingV2: Bool = false
    @AppStorage("didMigrateLegacyMonthlyTargetIncome") private var didMigrateLegacyMonthlyTargetIncome: Bool = false
    @Environment(\.modelContext) private var modelContext
    @Query private var allTransactions: [Transaction]
    @EnvironmentObject private var l10n: LocalizationManager

    @State private var route: RootRoute = .resolving
    @State private var justCompletedOnboarding: Bool = false
    @State private var isRestoringFromCloud: Bool = false
    @State private var restoreErrorMessage: String? = nil

    #if DEBUG
    @State private var qaRecap: MonthlyRecap? = nil
    @State private var qaShowDesignLab = false
    #endif

    private var isHebrew: Bool { l10n.language == .hebrew }

    var body: some View {
        ZStack {
            switch route {
            case .resolving:
                Color.appBackground
                    .ignoresSafeArea()

            case .checkingCloud:
                CloudCheckingView(onContinueWithoutRestore: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        hasStartedOnboardingV2 = true
                        route = .onboarding
                    }
                })
                .transition(.opacity)

            case .restorePrompt(let descriptor):
                CloudRestorePromptView(
                    descriptor: descriptor,
                    isRestoring: isRestoringFromCloud,
                    onRestore: handleRestoreFromCloud,
                    onStartFresh: {
                        // CRITICAL SAFETY GUARANTEE: "Start Fresh" NEVER deletes the existing iCloud backup.
                        // The previous backup remains safely preserved in the user's private iCloud container
                        // so that if tapped by mistake, the user can still manually restore it at any time
                        // from Settings -> Backup.
                        withAnimation(.easeInOut(duration: 0.25)) {
                            hasStartedOnboardingV2 = true
                            route = .onboarding
                        }
                    }
                )
                .transition(.opacity)
                .alert(
                    isHebrew ? "שגיאה בשחזור" : "Restore Failed",
                    isPresented: Binding(
                        get: { restoreErrorMessage != nil },
                        set: { if !$0 { restoreErrorMessage = nil } }
                    ),
                    actions: {
                        Button(isHebrew ? "נסה שוב" : "Retry", action: handleRestoreFromCloud)
                        Button(isHebrew ? "התחל מחדש" : "Start Fresh", role: .cancel) {
                            hasStartedOnboardingV2 = true
                            route = .onboarding
                        }
                    },
                    message: {
                        Text(restoreErrorMessage ?? "")
                    }
                )

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

    private func checkIsCleanInstall() -> Bool {
        !CloudBackupService.hasMeaningfulLocalState(
            context: modelContext,
            defaults: .standard,
            groupDefaults: UserDefaults(suiteName: "group.com.moneycity.app") ?? .standard
        )
    }

    private func resolveInitialRoute() {
        guard route == .resolving else { return }

        if !checkIsCleanInstall() {
            // Existing user installation: NEVER wipe or force restore
            if hasCompletedOnboarding {
                route = .main
            } else if hasStartedOnboardingV2 {
                route = .onboarding
            } else {
                // User has existing data (transactions, goals, streak, maps, username, or budget)
                // Mark onboarding completed and route straight to main
                hasCompletedOnboarding = true
                route = .main
            }
            Task {
                await CloudBackupService.shared.bootstrapFirstBackupIfNeeded(context: DatabaseService.shared.context)
            }
            return
        }

        // Clean installation: Check private iCloud container
        route = .checkingCloud
        Task {
            if let descriptor = await CloudBackupService.shared.discoverCleanInstallBackup() {
                withAnimation(.easeInOut(duration: 0.25)) {
                    route = .restorePrompt(descriptor)
                }
            } else {
                hasStartedOnboardingV2 = true
                withAnimation(.easeInOut(duration: 0.25)) {
                    route = .onboarding
                }
            }
        }
    }

    private func handleRestoreFromCloud() {
        isRestoringFromCloud = true
        Task {
            do {
                _ = try await CloudBackupService.shared.restoreLatestBackup(context: modelContext)
                hasCompletedOnboarding = true
                isRestoringFromCloud = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    route = .main
                }
            } catch {
                isRestoringFromCloud = false
                restoreErrorMessage = error.localizedDescription
            }
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
    @ObservedObject private var sharedWorkspace = SharedWorkspaceStore.shared
    #if DEBUG
    @ObservedObject private var sharedLab = SharedCloudLab.shared
    #endif

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .sheet(isPresented: $sharedWorkspace.showSetup) { SharedSpacesSetupView() }
                // Only for failures raised while nothing of ours is on screen. While the
                // setup sheet is up it carries its own alert, because an alert and a sheet
                // competing for the same presentation slot is what broke the first version.
                .alert(l10n.language == .hebrew ? "מרחב משותף" : "Shared space", isPresented: Binding(
                    get: { sharedWorkspace.errorMessage != nil && !sharedWorkspace.showSetup },
                    set: { if !$0 { sharedWorkspace.errorMessage = nil } })) {
                        Button(l10n.language == .hebrew ? "סגירה" : "Dismiss") { sharedWorkspace.errorMessage = nil }
                    } message: { Text(sharedWorkspace.errorMessage ?? "") }
                .task {
                    // Opportunistic only, and never a gate on discovery: the shared list
                    // fetches its own spaces when it is opened, so a device that has lost
                    // the flag still finds everything it owns. This keeps a returning
                    // shared user's list warm without making a personal user pay for a
                    // CloudKit round trip they never asked for. `discover` treats a missing
                    // iCloud account as an ordinary state, so it raises nothing here, and
                    // because this is async it cannot hold up the personal UI.
                    if UserDefaults.standard.bool(forKey: "shared_spaces_enabled") {
                        await sharedWorkspace.discover()
                    }
                }
                #if DEBUG
                .sheet(isPresented: $sharedLab.presentRequested) { SharedCloudLabView() }
                .onAppear {
                    if ProcessInfo.processInfo.arguments.contains("--shared-cloud-lab") {
                        sharedLab.presentRequested = true
                    }
                }
                #endif
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
                        // Safety net under CloudKit push. If a shared change was made while
                        // this app was away — offline, terminated, or on a device that never
                        // got the push — this is where it gets picked up. It is a no-op for a
                        // personal-only user, is debounced so switching apps does not re-fetch,
                        // and runs off the main actor's critical path so the personal UI is
                        // never waiting on CloudKit.
                        Task { await sharedWorkspace.refreshOnForeground() }
                    } else if newPhase == .background {
                        Task {
                            _ = try? await CloudBackupService.shared.performBackupIfNeeded(context: DatabaseService.shared.context, force: false)
                        }
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
            let timestampBefore = FXService.shared.lastUpdatedTimestamp
            await FXService.shared.fetchLatestRatesIfNeeded()
            // Only when a refresh actually landed: reconcile any unresolved foreign rows a
            // direct rate may now exist for. Rate-less rows are left untouched.
            if FXService.shared.lastUpdatedTimestamp > timestampBefore {
                CurrencyResolutionService.reconcileUnresolvedForeignIfRateNowAvailable(context: DatabaseService.shared.context)
            }
        }

        // Age out stale raw payloads even if no new one has arrived.
        DatabaseService.shared.pruneIngestLog()

        // Post any fixed expenses that came due while the app was closed/backgrounded.
        RecurringExpenseService.materializeDue(context: DatabaseService.shared.context)

        // Post any installment charges that came due while the app was closed/backgrounded.
        InstallmentService.materializeDue(context: DatabaseService.shared.context)

        // Post any one-time scheduled expenses that came due while the app was closed/backgrounded.
        ScheduledExpenseService.materializeDue(context: DatabaseService.shared.context)

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
        Task {
            await RemoteConfigService.shared.refreshIfNeeded()
        }
        Task {
            await CloudBackupService.shared.refreshStatus()
            await CloudBackupService.shared.bootstrapFirstBackupIfNeeded(context: DatabaseService.shared.context)
            _ = try? await CloudBackupService.shared.performBackupIfNeeded(context: DatabaseService.shared.context)
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
    public static let maxQueueSize = 100

    /// Migrates any legacy entries missing an "id" field by assigning a stable UUID.
    /// Filters out irrecoverably malformed items (missing both amount and merchant, or invalid structure)
    /// so they do not poison the queue. Enforces maxQueueSize limit and input sanitization.
    public static func sanitizeAndMigrate(raw: [[String: Any]]) -> (valid: [[String: Any]], malformedCount: Int) {
        var valid: [[String: Any]] = []
        var malformed = 0

        for var item in raw {
            if valid.count >= maxQueueSize {
                malformed += 1
                continue
            }
            let rawAmount = item["amount"] as? Double
            let validAmount = (rawAmount != nil && rawAmount!.isFinite) ? rawAmount : nil
            let rawMerchant = item["merchant"] as? String
            let sanitizedMerchant = rawMerchant.map { InputSanitizer.sanitizeSingleLine($0, maxLength: InputSanitizer.maxMerchantLength) }

            // An item is irrecoverably malformed if it has neither amount nor merchant
            guard validAmount != nil || (sanitizedMerchant != nil && !sanitizedMerchant!.isEmpty) else {
                malformed += 1
                continue
            }

            if let validAmount { item["amount"] = validAmount }
            if let sanitizedMerchant { item["merchant"] = sanitizedMerchant }

            // Assign stable ID if missing from legacy formats
            let rawId = item["id"] as? String
            if let rawId, !rawId.isEmpty {
                item["id"] = InputSanitizer.sanitizeIdentifier(rawId)
            } else {
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
