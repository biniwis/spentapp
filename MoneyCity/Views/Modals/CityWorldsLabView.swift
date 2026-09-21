#if DEBUG
import SwiftUI
import WebKit

/// Ephemeral Design Lab state. Never connected to settings or the user's city.
final class CityWorldPreviewSession: ObservableObject {
    enum World: String, CaseIterable, Identifiable {
        case urban = "Urban", medieval = "Medieval", arctic = "Arctic", israel = "Israel", future = "Future"
        var id: String { rawValue }
        var resourceName: String { self == .medieval ? "diorama_medieval" : "diorama" }
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
        guard next != world else { return }
        let wasLoading = isLoading
        isLoading = true
        error = nil
        // If the current renderer has not finished yet, there is no camera state
        // worth preserving. Reload the requested world immediately instead of
        // leaving the segmented control disabled forever.
        guard !wasLoading, webView != nil else {
            reload(world: next)
            return
        }
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
    @State private var activityLevel: Double = 0.60
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
                                Text("\(l10n.format(amount: CityWorldDemo.buildings[building.id] ?? building.amount)) · \(currentVenues.first(where: { $0.id == building.id })?.purchaseCount ?? 0) \(isHe ? "ביקורים לדוגמה" : "demo visits")")
                                    .font(.caption)
                            }
                            Spacer()
                            Button { session.building = nil } label: {
                                Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                            }
                            .accessibilityLabel(isHe ? "סגור פרטי מבנה" : "Close building details")
                        }
                    }

                    // ── Activity & People Test Controls ──
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            HStack(spacing: 5) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(MoneyCityTheme.jetBlack)
                                Text(isHe ? "רמת פעילות ואנשים" : "Activity & People")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(MoneyCityTheme.jetBlack)
                            }
                            Spacer()
                            Text("\(Int(round(activityLevel * 100)))%")
                                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundColor(MoneyCityTheme.violetBlue)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(MoneyCityTheme.babyBlue.opacity(0.55))
                                .clipShape(Capsule())
                        }

                        Slider(value: $activityLevel, in: 0.0...1.0, step: 0.01)
                            .tint(MoneyCityTheme.brandPrimary)

                        HStack(spacing: 5) {
                            ForEach([
                                (0.0, isHe ? "שקט 0%" : "0%"),
                                (0.20, isHe ? "סף 20%" : "20%"),
                                (0.50, isHe ? "בינוני 50%" : "50%"),
                                (0.75, isHe ? "שוקק 75%" : "75%"),
                                (1.0, isHe ? "מקס 100%" : "100%")
                            ], id: \.0) { val, label in
                                let isCurrent = abs(activityLevel - val) < 0.04
                                Button {
                                    Haptics.impact(.light)
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        activityLevel = val
                                    }
                                } label: {
                                    Text(label)
                                        .font(.system(size: 10.5, weight: isCurrent ? .bold : .medium, design: .rounded))
                                        .foregroundColor(isCurrent ? .white : MoneyCityTheme.jetBlack)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3.5)
                                        .background(isCurrent ? MoneyCityTheme.jetBlack : Color.black.opacity(0.06))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        HStack(spacing: 12) {
                            let coffeePatrons = activityLevel < 0.18 ? 0 : (activityLevel < 0.46 ? 1 : 2)
                            let bistroPatrons = activityLevel < 0.18 ? 0 : (activityLevel < 0.45 ? 1 : (activityLevel < 0.46 ? 2 : (activityLevel < 0.73 ? 3 : 4)))
                            let shopperPatrons = activityLevel < 0.15 ? 0 : 1

                            HStack(spacing: 3) {
                                Text("☕")
                                Text("\(coffeePatrons)/2")
                                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                                    .foregroundColor(coffeePatrons > 0 ? MoneyCityTheme.jetBlack : MoneyCityTheme.textSecondary)
                            }
                            HStack(spacing: 3) {
                                Text("🍷")
                                Text("\(bistroPatrons)/4")
                                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                                    .foregroundColor(bistroPatrons > 0 ? MoneyCityTheme.jetBlack : MoneyCityTheme.textSecondary)
                            }
                            HStack(spacing: 3) {
                                Text("🛍️")
                                Text("\(shopperPatrons)/1")
                                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                                    .foregroundColor(shopperPatrons > 0 ? MoneyCityTheme.jetBlack : MoneyCityTheme.textSecondary)
                            }
                            Spacer()
                            let walkersEst = activityLevel <= 0 ? 0 : max(1, Int(round(pow(activityLevel, 1.3) * 7.0)))
                            Text(isHe ? "הולכים: ~\(walkersEst)" : "Walkers: ~\(walkersEst)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundColor(MoneyCityTheme.textSecondary)
                        }
                    }
                    .padding(10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.black.opacity(0.025), radius: 4, y: 1)

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
                         ? "מעבדה פנימית בלבד · אותם נתוני דוגמה בכל העולמות · הבחירה לא נשמרת"
                         : "Internal lab · Same demo data in every world · Selection is not saved")
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

    private var currentVenues: [CityVenueState] {
        if activityLevel <= 0 {
            return CityLifeEngine.venueIDs.map { id in
                CityVenueState(
                    id: id, amount: 0, share: 0,
                    purchaseCount: 0, activeDays: 0,
                    merchantCount: 0, activity: 0,
                    presence: 0, additionalPlaces: 0
                )
            }
        }
        let total = CityWorldDemo.buildings.values.reduce(0, +)
        return CityLifeEngine.venueIDs.map { id in
            let baseAmount = CityWorldDemo.buildings[id] ?? 200
            let scaledAmount = baseAmount * max(0.08, activityLevel)
            let purchases = max(1, Int(round(Double(18) * activityLevel)))
            return CityVenueState(
                id: id,
                amount: scaledAmount,
                share: scaledAmount / total,
                purchaseCount: purchases,
                activeDays: max(1, Int(round(Double(14) * activityLevel))),
                merchantCount: max(1, Int(round(Double(3) * activityLevel))),
                activity: activityLevel,
                presence: activityLevel,
                additionalPlaces: activityLevel > 0.85 ? 1 : 0
            )
        }
    }

    private var currentHabits: BehavioralHabits {
        let wolt = Int(round(12.0 * activityLevel))
        let coffee = Int(round(20.0 * activityLevel))
        let totalSpend = Double(wolt) * 85.0
        let activeDays = max(0, Int(round(8.0 * activityLevel)))
        return BehavioralHabits(
            woltDeliveryCount: wolt,
            woltActiveDays: activeDays,
            woltTotalSpend: totalSpend,
            coffeeCount: coffee,
            onlinePackagesCount: Int(round(6.0 * activityLevel)),
            hasTravelOrFlight: activityLevel > 0.3,
            activeSubscriptionsCount: activityLevel > 0 ? 5 : 0,
            totalGroceryBags: Int(round(8.0 * activityLevel)),
            deliveryIntensity: DeliveryIntensityEngine.compute(
                orderCount: wolt, totalSpend: totalSpend,
                activeDays: activeDays, elapsedDays: 30
            )
        )
    }

    private var preview: some View {
        ThreeDioramaView(
            totalSpent: activityLevel <= 0 ? 0 : CityWorldDemo.total * max(0.1, activityLevel),
            totalSavings: 3200, savingsTarget: 4000,
            parkHealth: 0.85, viewResetToken: resetToken,
            categoryTotals: activityLevel <= 0 ? [:] : CityWorldDemo.categories,
            buildingTotals: activityLevel <= 0 ? [:] : CityWorldDemo.buildings,
            districtStates: CitySimulationEngine.districtStates(for: activityLevel <= 0 ? [:] : CityWorldDemo.categories),
            venueStates: currentVenues, habits: currentHabits,
            selectedDistrict: session.district, selectedBuildingId: session.building?.id,
            language: isHe ? "he" : "en", timeOfDayOverride: night ? 22 : 14,
            onSelectDistrict: { session.district = $0 },
            onBuildingSelected: { session.building = $0 }
        )
        .worldPreview(session)
    }
}
#endif
