#if DEBUG
import SwiftUI
import WebKit

/// Ephemeral Design Lab state. Never connected to settings or the user's city.
final class CityWorldPreviewSession: ObservableObject {
    enum World: String, CaseIterable, Identifiable {
        case urban = "Urban", medieval = "Medieval"
        var id: String { rawValue }
        var resourceName: String { self == .urban ? "diorama" : "diorama_medieval" }
    }

    @Published private(set) var world: World = .urban
    @Published private(set) var loadID = UUID()
    @Published private(set) var isLoading = true
    @Published private(set) var error: String?
    @Published var district: String?
    @Published var building: DistrictBuildingInfo?
    private weak var webView: WKWebView?
    private var cameraJSON: String?
    private var loadingTimeout: DispatchWorkItem?

    func attach(_ webView: WKWebView) {
        self.webView = webView
        loadingTimeout?.cancel()
        let timeout = DispatchWorkItem { [weak self, weak webView] in
            guard let self, let webView, self.webView === webView, self.isLoading else { return }
            self.fail("The world took too long to load. Try reloading the preview.")
        }
        loadingTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
    }

    func switchWorld(to next: World) {
        guard next != world, !isLoading else { return }
        isLoading = true
        error = nil
        // Snapshot the actual interpolated camera, not only its destination.
        let capture = """
        (() => {
            const s = window.__diorama.state();
            return JSON.stringify({mode: s.mode, cam: s.cam});
        })()
        """
        guard let webView else { reload(world: next); return }
        webView.evaluateJavaScript(capture) { [weak self] value, _ in
            guard let self else { return }
            self.cameraJSON = value as? String
            if let json = self.cameraJSON?.data(using: .utf8),
               let snapshot = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
               let mode = snapshot["mode"] as? String {
                self.district = mode == "city" ? nil : mode
            }
            self.reload(world: next)
        }
    }

    func reload(world: World? = nil) {
        loadingTimeout?.cancel()
        error = nil
        isLoading = true
        if let world { self.world = world }
        loadID = UUID()
    }

    func finishLoading(_ webView: WKWebView) {
        guard self.webView === webView else { return }
        let restore = """
        (() => {
            if (!window.__diorama) throw new Error('The city renderer did not initialize.');
            const saved = \(cameraJSON ?? "null");
            if (saved) {
                window.setDistrict(saved.mode === 'city' ? null : saved.mode, true);
                const s = window.__diorama.state();
                Object.assign(s.cam, saved.cam);
                Object.assign(s.target, saved.cam);
            }
            return true;
        })()
        """
        webView.evaluateJavaScript(restore) { [weak self, weak webView] _, error in
            guard let self, let webView, self.webView === webView else { return }
            self.loadingTimeout?.cancel()
            if let error { self.fail(error.localizedDescription); return }
            self.isLoading = false
        }
    }

    func fail(_ message: String) {
        // Resource failures can occur during makeUIView; publish on the next turn.
        DispatchQueue.main.async { [weak self] in
            self?.loadingTimeout?.cancel()
            self?.error = message
            self?.isLoading = false
        }
    }

    func clearCamera() { cameraJSON = nil }
    deinit { loadingTimeout?.cancel() }
}

/// One deterministic fixture goes through the production payload encoder for both HTMLs.
private enum CityWorldDemo {
    static let buildings: [String: Double] = [
        "food_bistro": 1420, "food_super": 2380, "food_coffee": 510, "food_wolt": 1240,
        "shop_boutique": 960, "shop_tech": 1210, "shop_travel": 1690, "shop_arcade": 460,
        "house_tower": 4300, "house_util": 700, "house_subs": 300,
        "trans_station": 840, "health_pharmacy": 410, "finance_bank": 280,
        "museum_curiosities": 390, "city_sorting_hub": 180
    ]
    static let categories: [SpendingCategory: Double] = [
        .food: 5550, .shopping: 3860, .entertainment: 460, .housing: 5000,
        .subscriptions: 300, .transport: 840, .health: 410, .finance: 280,
        .miscellaneous: 390, .other: 180
    ]
    static let total = buildings.values.reduce(0, +)
    static let venues: [CityVenueState] = CityLifeEngine.venueIDs.enumerated().map { index, id in
        let amount = buildings[id] ?? 0
        return CityVenueState(
            id: id, amount: amount, share: amount / total,
            purchaseCount: 6 + index % 15, activeDays: 5 + index % 12,
            merchantCount: 1 + index % 3, activity: 0.55 + Double(index % 4) * 0.1,
            presence: 0.5 + Double(index % 4) * 0.12, additionalPlaces: 0
        )
    }
    static let habits = BehavioralHabits(
        woltDeliveryCount: 12, woltActiveDays: 9, woltTotalSpend: 1240,
        coffeeCount: 18, onlinePackagesCount: 6, hasTravelOrFlight: true,
        activeSubscriptionsCount: 6, totalGroceryBags: 8
    )
}

struct CityWorldsLabView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager
    @StateObject private var session = CityWorldPreviewSession()
    @State private var resetToken = 0
    @State private var night = false
    private var isHe: Bool { l10n.language == .hebrew }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("World", selection: Binding(
                    get: { session.world }, set: { session.switchWorld(to: $0) }
                )) {
                    ForEach(CityWorldPreviewSession.World.allCases) { world in
                        Text(world.rawValue).tag(world)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(session.isLoading)
                .padding(.horizontal)

                ZStack {
                    preview
                        .id(session.loadID)
                    if session.isLoading {
                        Color.appBackground
                        ProgressView(isHe ? "טוען עולם…" : "Loading world…")
                    } else if let error = session.error {
                        Color.appBackground
                        VStack(spacing: 12) {
                            Text(isHe ? "התצוגה לא נטענה" : "Preview could not load").font(.headline)
                            Text(error).font(.caption).multilineTextAlignment(.center)
                            Button(isHe ? "טען מחדש" : "Reload preview") { session.reload() }
                        }
                        .padding()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                VStack(alignment: .leading, spacing: 10) {
                    if let building = session.building {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(building.name).font(.headline)
                                Text(building.id).font(.caption.monospaced())
                                Text("\(l10n.format(amount: CityWorldDemo.buildings[building.id] ?? building.amount)) · \(CityWorldDemo.venues.first(where: { $0.id == building.id })?.purchaseCount ?? 0) \(isHe ? "ביקורים לדוגמה" : "demo visits")")
                                    .font(.caption)
                            }
                            Spacer()
                            Button { session.building = nil } label: {
                                Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                            }
                            .accessibilityLabel(isHe ? "סגור פרטי מבנה" : "Close building details")
                        }
                    }
                    HStack {
                        Button {
                            session.district = nil
                            session.building = nil
                            session.clearCamera()
                            resetToken &+= 1
                        } label: {
                            Label(isHe ? "איפוס מצלמה" : "Reset camera", systemImage: "arrow.counterclockwise")
                        }
                        Spacer()
                        Toggle(isHe ? "לילה" : "Night", isOn: $night).fixedSize()
                    }
                    .disabled(session.isLoading || session.error != nil)
                    Text(isHe
                         ? "גרירה לסיבוב · צביטה לזום · הקשה לבחינת מבנה"
                         : "Drag to rotate · Pinch to zoom · Tap to inspect")
                        .font(.caption)
                    Text(isHe
                         ? "מעבדה פנימית בלבד · אותם נתוני דוגמה בשני העולמות · הבחירה לא נשמרת"
                         : "Internal lab · Same demo data in both worlds · Selection is not saved")
                        .font(.caption2)
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
            .background(Color.appBackground)
            .navigationTitle("City Worlds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isHe ? "סגור" : "Close") { dismiss() }
                }
            }
        }
        .environment(\.layoutDirection, isHe ? .rightToLeft : .leftToRight)
    }

    private var preview: some View {
        ThreeDioramaView(
            totalSpent: CityWorldDemo.total, totalSavings: 3200, savingsTarget: 4000,
            parkHealth: 0.85, viewResetToken: resetToken,
            categoryTotals: CityWorldDemo.categories, buildingTotals: CityWorldDemo.buildings,
            districtStates: CitySimulationEngine.districtStates(for: CityWorldDemo.categories),
            venueStates: CityWorldDemo.venues, habits: CityWorldDemo.habits,
            selectedDistrict: session.district, selectedBuildingId: session.building?.id,
            language: isHe ? "he" : "en", timeOfDayOverride: night ? 22 : 14,
            onSelectDistrict: { session.district = $0 },
            onBuildingSelected: { session.building = $0 }
        )
        .worldPreview(session)
    }
}
#endif
