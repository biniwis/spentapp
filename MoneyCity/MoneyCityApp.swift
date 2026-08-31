#if !SWIFT_PACKAGE
import SwiftUI
import SwiftData

@main
struct MoneyCityApp: App {
    @StateObject private var l10n = LocalizationManager.shared

    var body: some Scene {
        WindowGroup {
            MainCityView()
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

                    // Post any fixed expenses that came due while the app was closed.
                    RecurringExpenseService.materializeDue(context: DatabaseService.shared.context)

                    NotificationService.sync(
                        enabled: NotificationService.isEnabled,
                        isHebrew: l10n.language == .hebrew
                    )
                }
        }
        .modelContainer(DatabaseService.shared.container)
    }
}
#endif
