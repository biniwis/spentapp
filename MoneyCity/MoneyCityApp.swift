#if !SWIFT_PACKAGE
import SwiftUI
import SwiftData

@main
struct MoneyCityApp: App {
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
                .environmentObject(l10n)
                .onAppear {
                    // Pre-warm 3D Diorama WebGL context for zero-latency presentation
                    ThreeDioramaView.warmUp()

                    // Background fetch latest currency exchange rates
                    Task {
                        await FXService.shared.fetchLatestRates()
                    }

                    // Age out stale raw payloads even if no new one has arrived.
                    DatabaseService.shared.pruneIngestLog()

                    // Post any fixed expenses that came due while the app was closed.
                    RecurringExpenseService.materializeDue(context: DatabaseService.shared.context)

                    NotificationService.sync(
                        enabled: NotificationService.isEnabled,
                        isHebrew: l10n.language == .hebrew
                    )
                }
                .onOpenURL { url in
                    Task {
                        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }
                        let amount = components.queryItems?.first(where: { $0.name == "amount" })?.value.flatMap(Double.init)
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
}
#endif
