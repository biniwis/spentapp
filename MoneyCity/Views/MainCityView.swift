import SwiftUI
import SwiftData

/// Remembers the derived values the main view reads over and over within a single render.
///
/// `currentCity`, `progressReport` and the month filter are computed properties, and SwiftUI
/// runs a computed property on every access — not once per render. `body` reaches for them
/// seven to thirteen times depending on what is expanded, and each run rebuilt the month
/// filter (one `Calendar.dateComponents` per transaction) and then the entire city
/// simulation (a `lowercased()` plus roughly twenty-five substring searches per transaction).
/// At a few hundred transactions that is tens of thousands of string operations per frame,
/// sitting directly on top of a live WebGL canvas — and it got worse as history grew.
///
/// Keyed on a cheap digest of the inputs rather than a change notification, so an edit that
/// leaves the transaction count the same still invalidates it.
/// Deliberately not marked `@MainActor`: it is only ever touched from `body`, which already
/// runs there, and annotating it would make the `@State` initialiser cross an isolation
/// boundary for no benefit.
private final class CityDerivedCache {
    private var monthKey: Int?
    private var monthRows: [Transaction]?
    private var cityKey: Int?
    private var cachedCity: MonthlyCity?
    private var reportKey: Int?
    private var cachedReport: WeeklyProgressReport?

    func monthTransactions(key: Int, build: () -> [Transaction]) -> [Transaction] {
        if monthKey == key, let monthRows { return monthRows }
        let value = build()
        monthKey = key
        monthRows = value
        return value
    }

    func city(key: Int, build: () -> MonthlyCity) -> MonthlyCity {
        if cityKey == key, let cachedCity { return cachedCity }
        let value = build()
        cityKey = key
        cachedCity = value
        return value
    }

    func report(key: Int, build: () -> WeeklyProgressReport) -> WeeklyProgressReport {
        if reportKey == key, let cachedReport { return cachedReport }
        let value = build()
        reportKey = key
        cachedReport = value
        return value
    }
}

/// The main edge-to-edge view showcasing the real-time 3D living diorama with Multi-Building Neighborhood Deep-Dive and Spatial Inspection.
public struct MainCityView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager
    @Query(sort: \Transaction.timestamp, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \CityEnrichment.unlockedDate, order: .reverse) private var allEnrichments: [CityEnrichment]
    
    @AppStorage("monthly_budget") private var userMonthlyBudget: Double = 8000.0

    @Query private var incomeSources: [IncomeSource]
    @Query private var categoryBudgets: [CategoryBudget]

    @State private var derived = CityDerivedCache()

    /// A cheap fingerprint of everything the derived values depend on.
    ///
    /// Counting rows is not enough — editing an amount or a category leaves the count
    /// untouched — so the fields that actually feed the simulation are folded in. Four hash
    /// combines per transaction, against the twenty-five substring searches per transaction
    /// this saves.
    private var transactionsDigest: Int {
        var hasher = Hasher()
        hasher.combine(allTransactions.count)
        for tx in allTransactions {
            hasher.combine(tx.id)
            hasher.combine(tx.amount)
            hasher.combine(tx.timestamp)
            hasher.combine(tx.categoryRawValue)
        }
        return hasher.finalize()
    }

    /// Real income wins over the stored fallback. The 8,000 default was a number the app
    /// invented for the user, and the whole savings figure was derived from it.
    private var effectiveMonthlyBudget: Double {
        let income = BudgetService.expectedMonthlyIncome(incomeSources)
        return income > 0 ? income : userMonthlyBudget
    }
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    
    @State private var currentDate: Date = Date()
    @State private var showQuickAdd = false
    @State private var quickAddInitialScan = false
    @State private var showFeed = false
    @State private var showProgressSheet = false
    @State private var showOnboarding = false
    @State private var showSlotCustomizer = false
    @State private var customizerSelectedSlotId: String? = nil
    @State private var isZenMode = false
    @State private var isDetailsExpanded = false
    @State private var newlyUnlockedEnrichmentId: String? = nil
    @State private var selectedDistrict: String? = nil
    @State private var inspectedBuilding: DistrictBuildingInfo? = nil
    @State private var showSortingHubSheet = false
    @State private var activeTab: String = "city"
    
    public init() {}
    
    private var displayTransactions: [Transaction] {
        currentMonthTransactions
    }
    
    private var currentCity: MonthlyCity {
        var hasher = Hasher()
        hasher.combine(transactionsDigest)
        hasher.combine(currentDate.timeIntervalSinceReferenceDate)
        hasher.combine(effectiveMonthlyBudget)
        return derived.city(key: hasher.finalize()) {
            CitySimulationEngine.shared.generateCity(
                for: currentDate,
                transactions: displayTransactions,
                estimatedMonthlyBudget: effectiveMonthlyBudget
            )
        }
    }
    
    private var progressReport: WeeklyProgressReport {
        var hasher = Hasher()
        hasher.combine(transactionsDigest)
        hasher.combine(allEnrichments.count)
        return derived.report(key: hasher.finalize()) {
            let unlockedIds = Set(allEnrichments.map { $0.itemId })
            // The engine does its own 7/14-day windowing, so it needs the full history —
            // month-filtered rows leave the previous week empty for the first half of a month.
            return CityProgressEngine.shared.evaluateProgress(
                transactions: allTransactions,
                unlockedItemIds: unlockedIds,
                referenceDate: Date()
            )
        }
    }
    
    private var activeEnrichmentIds: [String] {
        allEnrichments.filter { $0.isApplied }.map { $0.itemId }
    }
    
    private var currentSlotPlacements: [String: String] {
        var dict: [String: String] = [:]
        for e in allEnrichments where e.isApplied {
            if let s = e.placedSlotId, !s.isEmpty {
                dict[s] = e.itemId
            }
        }
        return dict
    }
    
    public var body: some View {
        ZStack {
            Color(red: 248/255, green: 250/255, blue: 252/255).ignoresSafeArea()

            // ── City Tab (Kept persistent in background so 3D WebGL context is never destroyed on tab switch) ──
            ZStack(alignment: .top) {
                // 1. 3D Living Diorama Island (Edge-to-edge full canvas)
                DioramaReadyWrapper(
                    totalSpent: currentCity.totalSpent,
                    totalSavings: currentCity.totalSavings,
                    categoryTotals: currentCity.categoryTotals,
                    buildingTotals: currentCity.buildingTotals,
                    habits: currentCity.habits,
                    enrichmentIds: activeEnrichmentIds,
                    newlyUnlockedEnrichmentId: newlyUnlockedEnrichmentId,
                    slotPlacements: currentSlotPlacements,
                    selectedDistrict: selectedDistrict,
                    language: l10n.language == .hebrew ? "he" : "en",
                    isPaused: (activeTab != "city"),
                    onSelectDistrict: handleSelectDistrict,
                    onBuildingSelected: handleSelectBuilding,
                    onSlotTapped: handleSlotTapped
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 2. Top Category Circles (Fixed at Top, hidden in Map Only mode)
                if !isZenMode {
                    VStack(spacing: 0) {
                        districtSelectorRow
                            .padding(.top, 2)
                        Spacer()
                    }
                }
            }
            .opacity(activeTab == "city" ? 1.0 : 0.0)
            .allowsHitTesting(activeTab == "city")

            // ── Other Tabs ──
            if activeTab == "analytics" {
                AnalyticsView()
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
            } else if activeTab == "history" {
                HistoryView()
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
            } else if activeTab == "profile" {
                ProfileView()
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
            }

            // Zen mode expand/collapse button (city only)
            if activeTab == "city" {
                VStack {
                    HStack {
                        if isZenMode {
                            HStack(spacing: 5) {
                                Circle().fill(Color(red: 16/255, green: 185/255, blue: 129/255)).frame(width: 7, height: 7)
                                Text(l10n.language == .hebrew ? "תצוגת מפה מלאה" : "Full Map View")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.92))
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.10), radius: 6, y: 2)
                            .padding(.leading, 16)
                            .transition(.opacity)
                        }
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                                isZenMode.toggle()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.92))
                                    .frame(width: 42, height: 42)
                                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                DioramaExpandVectorIcon(isExpanded: isZenMode, color: Color.deepNavy)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                    }
                    .padding(.top, isZenMode ? 56 : 94)
                    Spacer()
                }
            }

            // ── Unified Floating Bottom Cards & Navigation Bar (Zero Overlap & Zero Dead Space) ──
            if !isZenMode {
                VStack(spacing: 8) {
                    Spacer()
                    if activeTab == "city" {
                        if let b = inspectedBuilding {
                            InspectorModalView(info: b, onClose: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    inspectedBuilding = nil
                                    if selectedDistrict == "civic" {
                                        selectedDistrict = nil
                                    }
                                }
                            }, onShowFeed: {
                                if b.id == "city_sorting_hub" {
                                    showSortingHubSheet = true
                                } else {
                                    showFeed = true
                                }
                            })
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else if let dist = selectedDistrict {
                            DistrictDeepDiveCard(districtId: dist) {
                                withAnimation { selectedDistrict = nil; inspectedBuilding = nil }
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            spendingCard
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }

                    FloatingBottomBar(
                        activeTab: $activeTab,
                        onQuickAdd: { showQuickAdd = true }
                    )
                }
                .padding(.bottom, 6)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            
        }

        .onAppear {
            if !hasCompletedOnboarding && allTransactions.isEmpty {
                showOnboarding = true
            }
        }
        .onOpenURL { url in
            let scheme = url.scheme?.lowercased() ?? ""
            let host = url.host?.lowercased() ?? ""
            let path = url.path.lowercased()
            
            if scheme == "spentapp" || scheme == "moneycity" {
                if host == "scan" || path.contains("scan") {
                    activeTab = "city"
                    quickAddInitialScan = true
                    showQuickAdd = true
                } else if host == "quick-add" || path.contains("quick-add") {
                    activeTab = "city"
                    quickAddInitialScan = false
                    showQuickAdd = true
                }
            }
        }
        .sheet(isPresented: $showQuickAdd, onDismiss: { quickAddInitialScan = false }) {
            QuickAddSheet(initialOpenScan: quickAddInitialScan) { amount, cat, note, origAmount, origCurrency, exchangeRate in
                // The user picked the category, so the building must follow that choice —
                // not the engine's guess about the note text.
                let tx = Transaction(
                    amount: amount,
                    currency: l10n.baseCurrency.symbol,
                    merchant: note,
                    category: cat,
                    timestamp: Date(),
                    confidenceScore: 1.0,
                    isManual: true,
                    isConfirmed: true,
                    note: nil,
                    buildingId: CategorizationEngine.shared.mapToBuildingId(category: cat, merchant: note),
                    originalAmount: origAmount,
                    originalCurrency: origCurrency,
                    exchangeRate: exchangeRate
                )
                modelContext.insert(tx)
                try? modelContext.save()
            }
        }
        .sheet(isPresented: $showFeed) {
            TransactionFeedSheet(
                title: feedSheetTitle,
                transactions: feedFilteredTransactions,
                onUpdateCategory: { tx, newCat in
                    // Remember it, so the next charge from this merchant lands correctly.
                    DatabaseService.shared.rememberCorrection(merchant: tx.merchant, category: newCat)
                    tx.category = newCat
                    tx.buildingIdRaw = CategorizationEngine.shared.mapToBuildingId(category: newCat, merchant: tx.merchant)
                    // The user just told us the answer, so it is no longer a guess.
                    tx.isConfirmed = true
                    tx.confidenceScore = 1.0
                    try? modelContext.save()
                }
            )
        }
        .sheet(isPresented: $showProgressSheet) {
            CityProgressSheet(
                report: progressReport,
                unlockedEnrichments: allEnrichments,
                onSelectOption: { opt in
                    let newEnrichment = CityEnrichment(
                        itemId: opt.id,
                        name: opt.title,
                        subtitle: opt.subtitle,
                        icon: opt.icon,
                        type: opt.type,
                        tier: opt.tier,
                        savedAmount: progressReport.savedAmount,
                        districtId: opt.districtId
                    )
                    modelContext.insert(newEnrichment)
                    try? modelContext.save()
                    
                    Haptics.notify(.success)
                    Haptics.impact(.heavy)
                    
                    newlyUnlockedEnrichmentId = opt.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        if newlyUnlockedEnrichmentId == opt.id {
                            newlyUnlockedEnrichmentId = nil
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingWizardView(
                onComplete: {
                    hasCompletedOnboarding = true
                    showOnboarding = false
                },
                onTriggerSampleTransaction: {
                    let seed = Transaction(
                        amount: 14.0,
                        merchant: "ארומה קפה",
                        category: .food,
                        timestamp: Date(),
                        buildingId: "food_coffee"
                    )
                    modelContext.insert(seed)
                    try? modelContext.save()
                }
            )
        }
        .sheet(isPresented: $showSlotCustomizer) {
            CitySlotCustomizerSheet(
                initialSlotId: customizerSelectedSlotId,
                unlockedEnrichments: allEnrichments,
                currentPlacements: currentSlotPlacements,
                onAssignSlot: handleAssignSlot
            )
        }
        .sheet(isPresented: $showSortingHubSheet) {
            CitySortingHubSheet(
                transactions: currentMonthTransactions.filter { $0.category == .other },
                onUpdateCategory: { tx, newCat in
                    tx.category = newCat
                    tx.buildingIdRaw = CategorizationEngine.shared.mapToBuildingId(category: newCat, merchant: tx.merchant)
                    tx.isConfirmed = true
                    try? modelContext.save()
                }
            )
        }
    }
    
    private func handleSlotTapped(slotId: String, currentItem: String?) {
        customizerSelectedSlotId = slotId
        showSlotCustomizer = true
    }
    
    private func handleAssignSlot(slotId: String, itemId: String?) {
        for e in allEnrichments {
            if e.placedSlotId == slotId {
                e.placedSlotId = nil
            }
        }
        if let id = itemId, let enrichment = allEnrichments.first(where: { $0.itemId == id }) {
            enrichment.placedSlotId = slotId
            enrichment.isApplied = true
            newlyUnlockedEnrichmentId = id
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if newlyUnlockedEnrichmentId == id {
                    newlyUnlockedEnrichmentId = nil
                }
            }
        }
        try? modelContext.save()
        Haptics.impact(.medium)
    }
    
    private func handleSelectDistrict(_ dist: String?) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            selectedDistrict = dist
            if dist == nil {
                inspectedBuilding = nil
            }
        }
    }
    
    private func handleSelectBuilding(_ building: DistrictBuildingInfo) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            inspectedBuilding = building
        }
    }
    

    
    private var districtSelectorRow: some View {
        HStack(spacing: 0) {
            topDistrictPill(
                id: nil,
                title: l10n.language == .hebrew ? "כל העיר" : "All City"
            ) { isSelected in
                DistrictSkylineVectorIcon(color: isSelected ? .white : Color.deepNavy)
            }
            topDistrictPill(
                id: "food",
                title: l10n.language == .hebrew ? "אוכל" : "Food"
            ) { isSelected in
                DistrictBistroVectorIcon(color: isSelected ? .white : Color(red: 217/255, green: 119/255, blue: 6/255))
            }
            topDistrictPill(
                id: "shopping",
                title: l10n.language == .hebrew ? "קניות" : "Shopping"
            ) { isSelected in
                DistrictBoutiqueVectorIcon(color: isSelected ? .white : Color(red: 99/255, green: 102/255, blue: 241/255))
            }
            topDistrictPill(
                id: "housing",
                title: l10n.language == .hebrew ? "מגורים" : "Housing"
            ) { isSelected in
                DistrictHousingVectorIcon(color: isSelected ? .white : Color(red: 59/255, green: 130/255, blue: 246/255))
            }
            topDistrictPill(
                id: "savings",
                title: l10n.language == .hebrew ? "חיסכון" : "Savings"
            ) { isSelected in
                DistrictParkVectorIcon(color: isSelected ? .white : Color(red: 16/255, green: 185/255, blue: 129/255))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private func topDistrictPill<V: View>(
        id: String?,
        title: String,
        @ViewBuilder icon: (Bool) -> V
    ) -> some View {
        let isSelected = (id == nil && selectedDistrict == nil) || (id != nil && selectedDistrict == id)
        return Button(action: {
            handleSelectDistrict(id)
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(red: 15/255, green: 23/255, blue: 42/255) : Color(red: 246/255, green: 247/255, blue: 250/255))
                        .frame(width: 46, height: 46)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color(red: 15/255, green: 23/255, blue: 42/255) : Color(red: 226/255, green: 232/255, blue: 240/255), lineWidth: 1.2)
                        )
                        .shadow(color: isSelected ? Color.black.opacity(0.12) : Color.black.opacity(0.02), radius: 4, y: 2)
                    
                    icon(isSelected)
                }
                
                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? Color(red: 15/255, green: 23/255, blue: 42/255) : Color(red: 100/255, green: 116/255, blue: 139/255))
                
                // Crisp Minimal Selection Indicator
                if isSelected {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(red: 15/255, green: 23/255, blue: 42/255))
                        .frame(width: 14, height: 2.5)
                } else {
                    Color.clear.frame(width: 14, height: 2.5)
                }
            }
            .contentShape(Rectangle())
        }
        .bouncyPress(scale: 0.90)
        .frame(maxWidth: .infinity)
    }
    
    private struct BuildingPillItem: Identifiable {
        let id: String
        let title: String
        let amount: Double
        let info: DistrictBuildingInfo
    }
    
    private func districtName(for dist: String) -> String {
        let isHebrew = l10n.language == .hebrew
        switch dist {
        case "food": return isHebrew ? "רובע האוכל והמסעדות" : "Food & Dining District"
        case "shopping": return isHebrew ? "שדרת הקניות והאופנה" : "Shopping & Fashion Avenue"
        case "housing": return isHebrew ? "מתחם המגורים והחשבונות" : "Housing & Bills Quarter"
        case "transport": return isHebrew ? "מרכז התחבורה והרכב" : "Mobility & Transport Hub"
        case "savings": return isHebrew ? "שמורת הטבע והחיסכון" : "Nature & Savings Park"
        default: return isHebrew ? "רובע בעיר" : "City District"
        }
    }
    
    private func districtTotal(for dist: String) -> Double {
        switch dist {
        case "food":
            let r = currentCity.categoryTotals[.food] ?? 0
            let g = currentCity.categoryTotals[.groceries] ?? 0
            let c = currentCity.categoryTotals[.coffee] ?? 0
            return r + g + c
        case "shopping":
            let s = currentCity.categoryTotals[.shopping] ?? 0
            let e = currentCity.categoryTotals[.entertainment] ?? 0
            return s + e
        case "housing":
            let h = currentCity.categoryTotals[.housing] ?? 0
            let subs = currentCity.categoryTotals[.subscriptions] ?? 0
            return h + subs
        case "transport":
            return currentCity.categoryTotals[.transport] ?? 0
        case "savings":
            return currentCity.totalSavings
        default:
            return 0
        }
    }
    
    private func buildingVisitCount(for bId: String) -> Int {
        displayTransactions.filter { $0.buildingId == bId }.count
    }
    
    private func buildingTrendText(for bId: String) -> String {
        let count = buildingVisitCount(for: bId)
        if count == 0 {
            return l10n.language == .hebrew ? "טרם נרשמו עסקאות החודש" : "No visits this month"
        } else {
            return l10n.language == .hebrew ? "\(count) עסקאות החודש" : "\(count) visits this month"
        }
    }
    
    private func districtBuildingPills(for dist: String) -> [BuildingPillItem] {
        let isHe = l10n.language == .hebrew
        switch dist {
        case "food":
            let r = currentCity.buildingTotals["food_bistro"] ?? 0
            let g = currentCity.buildingTotals["food_super"] ?? 0
            let c = currentCity.buildingTotals["food_coffee"] ?? 0
            let d = currentCity.buildingTotals["food_wolt"] ?? 0
            return [
                BuildingPillItem(id: "food_bistro", title: isHe ? "מסעדות" : "Dining", amount: r, info: DistrictBuildingInfo(id: "food_bistro", districtId: "food", name: isHe ? "ביסטרו ומסעדות" : "Bistro & Dining", amount: r, visitCount: buildingVisitCount(for: "food_bistro"), trendText: buildingTrendText(for: "food_bistro"))),
                BuildingPillItem(id: "food_super", title: isHe ? "סופרמרקט" : "Groceries", amount: g, info: DistrictBuildingInfo(id: "food_super", districtId: "food", name: isHe ? "סופרמרקט ומזון" : "Supermarket & Food", amount: g, visitCount: buildingVisitCount(for: "food_super"), trendText: buildingTrendText(for: "food_super"))),
                BuildingPillItem(id: "food_coffee", title: isHe ? "קפה" : "Coffee", amount: c, info: DistrictBuildingInfo(id: "food_coffee", districtId: "food", name: isHe ? "אספרסו בר" : "Espresso Bar", amount: c, visitCount: buildingVisitCount(for: "food_coffee"), trendText: buildingTrendText(for: "food_coffee"))),
                BuildingPillItem(id: "food_wolt", title: isHe ? "משלוחים" : "Delivery", amount: d, info: DistrictBuildingInfo(id: "food_wolt", districtId: "food", name: isHe ? "משלוחי אוכל" : "Food Delivery", amount: d, visitCount: buildingVisitCount(for: "food_wolt"), trendText: buildingTrendText(for: "food_wolt")))
            ]
        case "shopping":
            let f = currentCity.buildingTotals["shop_boutique"] ?? 0
            let t = currentCity.buildingTotals["shop_tech"] ?? 0
            let tr = currentCity.buildingTotals["shop_travel"] ?? 0
            let a = currentCity.buildingTotals["shop_arcade"] ?? 0
            return [
                BuildingPillItem(id: "shop_boutique", title: isHe ? "ביגוד" : "Fashion", amount: f, info: DistrictBuildingInfo(id: "shop_boutique", districtId: "shopping", name: isHe ? "בוטיק אופנה" : "Fashion Boutique", amount: f, visitCount: buildingVisitCount(for: "shop_boutique"), trendText: buildingTrendText(for: "shop_boutique"))),
                BuildingPillItem(id: "shop_tech", title: isHe ? "טכנולוגיה" : "Tech", amount: t, info: DistrictBuildingInfo(id: "shop_tech", districtId: "shopping", name: isHe ? "חנות אלקטרוניקה" : "Electronics Store", amount: t, visitCount: buildingVisitCount(for: "shop_tech"), trendText: buildingTrendText(for: "shop_tech"))),
                BuildingPillItem(id: "shop_travel", title: isHe ? "חופשות" : "Travel", amount: tr, info: DistrictBuildingInfo(id: "shop_travel", districtId: "shopping", name: isHe ? "סוכנות נסיעות" : "Travel Agency", amount: tr, visitCount: buildingVisitCount(for: "shop_travel"), trendText: buildingTrendText(for: "shop_travel"))),
                BuildingPillItem(id: "shop_arcade", title: isHe ? "פנאי ובידור" : "Arcade", amount: a, info: DistrictBuildingInfo(id: "shop_arcade", districtId: "shopping", name: isHe ? "מתחם ארקייד" : "Arcade Complex", amount: a, visitCount: buildingVisitCount(for: "shop_arcade"), trendText: buildingTrendText(for: "shop_arcade")))
            ]
        case "housing":
            let rent = currentCity.buildingTotals["house_tower"] ?? 0
            let util = currentCity.buildingTotals["house_util"] ?? 0
            let subs = currentCity.buildingTotals["house_subs"] ?? 0
            return [
                BuildingPillItem(id: "house_tower", title: isHe ? "שכירות" : "Rent", amount: rent, info: DistrictBuildingInfo(id: "house_tower", districtId: "housing", name: isHe ? "מגדל מגורים" : "Residential Tower", amount: rent, visitCount: buildingVisitCount(for: "house_tower"), trendText: buildingTrendText(for: "house_tower"))),
                BuildingPillItem(id: "house_util", title: isHe ? "חשבונות" : "Utilities", amount: util, info: DistrictBuildingInfo(id: "house_util", districtId: "housing", name: isHe ? "חשמל ומים" : "Power & Water", amount: util, visitCount: buildingVisitCount(for: "house_util"), trendText: buildingTrendText(for: "house_util"))),
                BuildingPillItem(id: "house_subs", title: isHe ? "מנויים" : "Subscriptions", amount: subs, info: DistrictBuildingInfo(id: "house_subs", districtId: "housing", name: isHe ? "שירותי סטרימינג" : "Streaming & Subs", amount: subs, visitCount: buildingVisitCount(for: "house_subs"), trendText: buildingTrendText(for: "house_subs")))
            ]
        case "savings":
            let sav = currentCity.totalSavings
            let savVisits = displayTransactions.filter { $0.category == .savings }.count
            return [
                BuildingPillItem(id: "savings_sanctuary", title: isHe ? "שמורת החיסכון" : "Savings Park", amount: sav, info: DistrictBuildingInfo(id: "savings_sanctuary", districtId: "savings", name: isHe ? "שמורת הטבע והחיסכון" : "Nature & Savings Park", amount: sav, visitCount: savVisits, trendText: sav > 0 ? (isHe ? "צמיחה ירוקה החודש" : "Growing green this month") : (isHe ? "התחל לחסוך כדי להצמיח את השמורה" : "Start saving to grow the park")))
            ]
        default:
            let tr = currentCity.categoryTotals[.transport] ?? 0
            let transVisits = displayTransactions.filter { $0.category == .transport }.count
            return [
                BuildingPillItem(id: "trans_station", title: isHe ? "תחבורה ודלק" : "Transit & Fuel", amount: tr, info: DistrictBuildingInfo(id: "trans_station", districtId: "transport", name: isHe ? "תחבורה וחניה" : "Transit & Parking", amount: tr, visitCount: transVisits, trendText: transVisits == 0 ? (isHe ? "טרם נרשמו עסקאות החודש" : "No visits this month") : (isHe ? "\(transVisits) עסקאות החודש" : "\(transVisits) visits this month")))
            ]
        }
    }
    
    @ViewBuilder
    private var topDistrictSummaryHeader: some View {
        if let dist = selectedDistrict {
            VStack(spacing: 8) {
                // Main District Title & Total Bar
                HStack {
                    // Close / Back button
                    Button(action: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            selectedDistrict = nil
                            inspectedBuilding = nil
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                            Text(l10n.language == .hebrew ? "חזרה לעיר" : "Back to City")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.appBackground)
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // District Title & Total
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(districtName(for: dist))
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        
                        Text("סה״כ ₪\(Int(districtTotal(for: dist))) החודש")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color.primaryBlue)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                
                // Horizontal Quick Building Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(districtBuildingPills(for: dist)) { pill in
                            Button(action: {
                                handleSelectBuilding(pill.info)
                            }) {
                                HStack(spacing: 6) {
                                    CategoryVectorIcon(category: districtToCategory(dist), size: 15)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(pill.title)
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(Color.textSecondary)
                                        
                                        Text("₪\(Int(pill.amount))")
                                            .font(.system(size: 12, weight: .black, design: .rounded))
                                            .foregroundColor(Color.deepNavy)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(inspectedBuilding?.id == pill.id ? Color.themeLavenderSoft.opacity(0.5) : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(inspectedBuilding?.id == pill.id ? Color.primaryBlue : Color.borderSubtle, lineWidth: 1.2)
                                )
                                .shadow(color: Color.deepNavy.opacity(0.04), radius: 4, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                }
            }
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(red: 226/255, green: 232/255, blue: 240/255), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    
    private var spendingCard: some View {
        VStack(spacing: 8) {
            // Header Row: Total Monthly Spending (Tappable -> Expands/Collapses District Breakdown)
            Button(action: {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    isDetailsExpanded.toggle()
                }
            }) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(l10n.language == .hebrew ? "סה״כ הוצאות החודש" : "Total Monthly Spending")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(red: 107/255, green: 114/255, blue: 128/255))
                            
                            Text(verbatim: isDetailsExpanded ? "▲" : "▼")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(Color.textMuted)
                        }
                        
                        Text("\(l10n.baseCurrency.symbol)\(Int(currentCity.totalSpent))")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                    }
                    
                    Spacer()
                    
                    // Mint Green Savings Park Badge
                    HStack(spacing: 5) {
                        DistrictParkVectorIcon(color: Color.themeMint)
                            .frame(width: 14, height: 14)
                            .scaleEffect(0.65)
                        Text("\(l10n.baseCurrency.symbol)\(Int(currentCity.totalSavings)) \(l10n.language == .hebrew ? "בפארק" : "in Park")")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color.themeMint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.themeMintSoft)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.themeMint.opacity(0.25), lineWidth: 1))
                }
            }
            .buttonStyle(.plain)

            // Contextual Month Milestone
            if displayTransactions.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color.themeMint)
                    Text(l10n.language == .hebrew ? "עיר חדשה מתחילה לצמוח" : "A new city is growing")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.top, 1)
            } else if displayTransactions.count == 1 {
                HStack(spacing: 6) {
                    Image(systemName: "building.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color.primaryBlue)
                    Text(l10n.language == .hebrew ? "המבנה הראשון שלך לחודש זה" : "Your first building of the month")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.top, 1)
            }
            
            // Clean, integrated upgrade notification (inside spendingCard)
            if progressReport.hasPositiveProgress && !progressReport.availableOptions.isEmpty {
                Button(action: { showProgressSheet = true }) {
                    HStack(spacing: 8) {
                        DistrictSkylineVectorIcon(color: Color.themeYellow)
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                        
                        Text(l10n.language == .hebrew ? "שדרוג לעיר זמין" : "City Upgrade Ready")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        
                        Spacer()
                        
                        Text("-\(l10n.baseCurrency.symbol)\(Int(progressReport.savedAmount)) \(l10n.language == .hebrew ? "השבוע" : "this week")")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color.themeMint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.themeMintSoft)
                            .clipShape(Capsule())
                        
                        Text(verbatim: l10n.language == .hebrew ? "‹" : "›")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color.textMuted)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderSubtle, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            
            // District Details (Expanded only on tap!)
            if isDetailsExpanded {
                Divider().background(Color.borderSubtle)
                
                let foodAmt = (currentCity.categoryTotals[.food] ?? 0) + (currentCity.categoryTotals[.groceries] ?? 0)
                let shopAmt = currentCity.categoryTotals[.shopping] ?? 0
                let houseAmt = currentCity.categoryTotals[.housing] ?? 0
                let displayTotal = max(currentCity.totalSpent, 1.0)
                
                if currentCity.totalSpent <= 0 {
                    HStack(spacing: 8) {
                        DistrictSkylineVectorIcon(color: Color.textMuted)
                            .frame(width: 18, height: 18)
                            .scaleEffect(0.75)
                        Text(l10n.language == .hebrew ? "טרם נרשמו הוצאות החודש" : "No expenses recorded this month")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.textSecondary)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .transition(.opacity)
                } else {
                    VStack(spacing: 4) {
                        districtRow(
                            bgColor: Color.themeTurquoiseSoft,
                            title: l10n.language == .hebrew ? "רובע האוכל" : "Food District",
                            amount: foodAmt,
                            percentage: Int(round((foodAmt / displayTotal) * 100)),
                            icon: { DistrictBistroVectorIcon(color: Color.themeTurquoise).scaleEffect(0.65) }
                        ) {
                            handleSelectDistrict("food")
                        }
                        
                        Divider().background(Color.borderSubtle)
                        
                        districtRow(
                            bgColor: Color.themeLavenderSoft,
                            title: l10n.language == .hebrew ? "שדרת הקניות" : "Shopping Street",
                            amount: shopAmt,
                            percentage: Int(round((shopAmt / displayTotal) * 100)),
                            icon: { DistrictBoutiqueVectorIcon(color: Color.themeLavender).scaleEffect(0.65) }
                        ) {
                            handleSelectDistrict("shopping")
                        }
                        
                        Divider().background(Color.borderSubtle)
                        
                        districtRow(
                            bgColor: Color(red: 238/255, green: 237/255, blue: 254/255),
                            title: l10n.language == .hebrew ? "מתחם המגורים" : "Housing Quarter",
                            amount: houseAmt,
                            percentage: Int(round((houseAmt / displayTotal) * 100)),
                            icon: { DistrictHousingVectorIcon(color: Color.primaryBlue).scaleEffect(0.65) }
                        ) {
                            handleSelectDistrict("housing")
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.borderSubtle, lineWidth: 1.5))
        .shadow(color: Color.deepNavy.opacity(0.06), radius: 14, y: 4)
        .padding(.horizontal, 16)
    }
    
    private func districtRow<V: View>(
        bgColor: Color,
        title: String,
        amount: Double,
        percentage: Int,
        @ViewBuilder icon: () -> V,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Soft colored rounded square icon tile
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(bgColor)
                        .frame(width: 32, height: 32)
                    
                    icon()
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                
                Spacer()
                
                Text("₪\(Int(amount))")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                
                Text("\(percentage)%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .frame(width: 34, alignment: .trailing)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: currentDate)
    }
    
    private func changeMonth(by delta: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: delta, to: currentDate) {
            currentDate = newDate
        }
    }
    
    private var currentMonthTransactions: [Transaction] {
        var hasher = Hasher()
        hasher.combine(transactionsDigest)
        hasher.combine(currentDate.timeIntervalSinceReferenceDate)
        return derived.monthTransactions(key: hasher.finalize()) {
            let calendar = Calendar.current
            let comps = calendar.dateComponents([.year, .month], from: currentDate)
            return allTransactions.filter { tx in
                let txComps = calendar.dateComponents([.year, .month], from: tx.timestamp)
                return txComps.year == comps.year && txComps.month == comps.month
            }
        }
    }

    private var feedFilteredTransactions: [Transaction] {
        if let building = inspectedBuilding {
            return currentMonthTransactions.filter { tx in
                if tx.buildingIdRaw == building.id { return true }
                switch building.id {
                case "house_subs":
                    return tx.category == .subscriptions || tx.merchant.lowercased().contains("net") || tx.merchant.lowercased().contains("spot") || tx.merchant.lowercased().contains("apple") || tx.merchant.contains("מנוי")
                case "house_tower":
                    return tx.category == .housing && (tx.merchant.contains("שכירות") || tx.merchant.contains("משכנתא") || tx.merchant.contains("בית") || !tx.merchant.contains("חשמל"))
                case "house_util":
                    return tx.category == .housing && (tx.merchant.contains("חשמל") || tx.merchant.contains("מים") || tx.merchant.contains("גז") || tx.merchant.contains("ארנונה") || tx.merchant.contains("ועד"))
                case "food_bistro":
                    return tx.category == .food && !tx.merchant.contains("קפה") && !tx.merchant.contains("סופר") && !tx.merchant.contains("וולט")
                case "food_super":
                    return tx.category == .groceries || (tx.category == .food && (tx.merchant.contains("סופר") || tx.merchant.contains("שופרסל") || tx.merchant.contains("רמי לוי") || tx.merchant.contains("מכולת") || tx.merchant.contains("אושר עד") || tx.merchant.contains("יוחננוף")))
                case "food_coffee":
                    return tx.category == .coffee || (tx.category == .food && (tx.merchant.contains("קפה") || tx.merchant.contains("ארומה") || tx.merchant.contains("ארקפה") || tx.merchant.contains("סטארבקס")))
                case "food_wolt":
                    return tx.category == .food && (tx.merchant.contains("וולט") || tx.merchant.contains("wolt") || tx.merchant.contains("משלוח") || tx.merchant.contains("תן ביס"))
                case "shop_boutique":
                    return tx.category == .shopping && (tx.merchant.contains("זארה") || tx.merchant.contains("h&m") || tx.merchant.contains("בגד") || tx.merchant.contains("קסטרו") || tx.merchant.contains("פוקס"))
                case "shop_tech":
                    return tx.category == .shopping && (tx.merchant.contains("ksp") || tx.merchant.contains("באג") || tx.merchant.contains("אייבורי") || tx.merchant.contains("מחשב"))
                case "shop_travel":
                    return (tx.category == .transport || tx.category == .shopping) && (tx.merchant.contains("טיסה") || tx.merchant.contains("מלון") || tx.merchant.contains("booking") || tx.merchant.contains("אל על"))
                case "shop_arcade":
                    return tx.category == .entertainment
                case "savings_sanctuary":
                    return tx.category == .savings
                case "trans_station":
                    return tx.category == .transport
                case "city_sorting_hub":
                    return tx.category == .other || tx.buildingIdRaw == "city_sorting_hub"
                default:
                    return tx.buildingIdRaw == building.id
                }
            }
        } else if let dist = selectedDistrict {
            return currentMonthTransactions.filter { tx in
                switch dist {
                case "food": return tx.category == .food || tx.category == .groceries || tx.category == .coffee
                case "shopping": return tx.category == .shopping || tx.category == .entertainment
                case "housing": return tx.category == .housing || tx.category == .subscriptions
                case "savings": return tx.category == .savings
                case "transport": return tx.category == .transport
                default: return true
                }
            }
        }
        return displayTransactions
    }

    private var feedSheetTitle: String {
        if let b = inspectedBuilding {
            return b.name
        }
        if let d = selectedDistrict {
            return districtName(for: d)
        }
        return l10n.language == .hebrew ? "יומן עסקאות החודש" : "Monthly Transactions"
    }
}

/// District deep-dive bottom bar

struct DistrictDeepDiveCard: View {
    let districtId: String
    let onBack: () -> Void
    @EnvironmentObject private var l10n: LocalizationManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(districtTitle.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 156/255, green: 163/255, blue: 175/255))
                    .tracking(0.6)
                
                HStack(spacing: 5) {
                    CategoryVectorIcon(category: districtCategory, size: 14)
                    Text(l10n.language == .hebrew ? "לחץ על מבנה לצפייה בעסקאות" : "Tap building for details")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 15/255, green: 13/255, blue: 23/255))
                }
            }
            
            Spacer()
            
            Button(action: onBack) {
                HStack(spacing: 6) {
                    DistrictSkylineVectorIcon(color: .white)
                        .frame(width: 14, height: 14)
                        .scaleEffect(0.85)
                    Text(l10n.language == .hebrew ? "חזרה לעיר" : "Back to City")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.obsidianBlack)
                .clipShape(Capsule())
                .shadow(color: Color.obsidianBlack.opacity(0.25), radius: 6, y: 3)
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color(red: 243/255, green: 244/255, blue: 246/255), lineWidth: 1.5))
        .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)
        .padding(.horizontal, 20)
    }
    
    private var districtTitle: String {
        let isHebrew = l10n.language == .hebrew
        switch districtId {
        case "food": return isHebrew ? "אוכל ומסעדות" : "Food & Dining"
        case "shopping": return isHebrew ? "קניות וביגוד" : "Shopping & Clothes"
        case "housing": return isHebrew ? "דיור וחשבונות בית" : "Housing & Bills"
        case "savings": return isHebrew ? "חיסכון והשקעות" : "Savings & Reserve"
        case "transport": return isHebrew ? "תחבורה ורכב" : "Mobility & Transport"
        default: return isHebrew ? "רובע בעיר" : "City District"
        }
    }
    
    private var districtCategory: SpendingCategory {
        districtToCategory(districtId)
    }
}

public func districtToCategory(_ dist: String) -> SpendingCategory {
    switch dist {
    case "food": return .food
    case "shopping": return .shopping
    case "housing": return .housing
    case "savings": return .savings
    case "transport": return .transport
    default: return .other
    }
}

/// Floating spatial building inspector modal
struct InspectorModalView: View {
    let info: DistrictBuildingInfo
    let onClose: () -> Void
    let onShowFeed: () -> Void
    @EnvironmentObject private var l10n: LocalizationManager
    
    private var isSortingHub: Bool {
        info.id == "city_sorting_hub"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            
            if isSortingHub {
                HStack(spacing: 8) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 234/255, green: 88/255, blue: 12/255))
                    Text(l10n.language == .hebrew ? "הוצאות שונות מצטברות כאן כחבילות. לחץ למיון מהיר ושיוך למבנים הנכונים בעיר." : "Uncategorized expenses gather here. Tap to triage and send funds to their buildings.")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 120/255, green: 53/255, blue: 15/255))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(Color(red: 254/255, green: 243/255, blue: 199/255).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            
            Divider().background(Color(red: 243/255, green: 244/255, blue: 246/255))
            trendRow
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color(red: 243/255, green: 244/255, blue: 246/255), lineWidth: 1.5))
        .shadow(color: Color.black.opacity(0.08), radius: 16, y: 6)
        .padding(.horizontal, 20)
        .contentShape(Rectangle())
        .onTapGesture {
            onShowFeed()
        }
    }
    
    private var headerRow: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSortingHub ? Color(red: 254/255, green: 243/255, blue: 199/255) : Color(red: 241/255, green: 245/255, blue: 249/255))
                    .frame(width: 46, height: 46)
                if isSortingHub {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(red: 234/255, green: 88/255, blue: 12/255))
                } else {
                    CategoryVectorIcon(category: districtToCategory(info.districtId), size: 24)
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(info.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                if isSortingHub {
                    if info.amount > 0 {
                        Text("\(l10n.baseCurrency.symbol)\(Int(info.amount)) \(l10n.language == .hebrew ? "שונות למיון" : "to triage") • \(info.visitCount) \(l10n.language == .hebrew ? "חבילות" : "packages")")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 234/255, green: 88/255, blue: 12/255))
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                            Text(l10n.language == .hebrew ? "הכל ממוין ומסודר!" : "All sorted & clean!")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        }
                    }
                } else if info.amount > 0 {
                    Text("\(l10n.baseCurrency.symbol)\(Int(info.amount)) \(l10n.language == .hebrew ? "החודש" : "this month") • \(info.visitCount) \(l10n.language == .hebrew ? "פעולות" : "items")")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.primaryBlue)
                } else {
                    Text(l10n.language == .hebrew ? "מגרש פנוי • ₪0 החודש" : "Vacant Lot • \(l10n.baseCurrency.symbol)0")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textMuted)
                }
            }
            
            Spacer()
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.textMuted)
                    .frame(width: 32, height: 32)
                    .background(Color.appBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
    
    private var trendRow: some View {
        HStack(spacing: 8) {
            Text(l10n.language == .hebrew ? "סטטוס:" : "Status:")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Color.textMuted)
            Text(isSortingHub ? (info.amount > 0 ? (l10n.language == .hebrew ? "ממתין למיון" : "Pending Triage") : (l10n.language == .hebrew ? "מרכז מיון נקי" : "Sorting Hub Clean")) : (info.amount > 0 ? info.trendText : (l10n.language == .hebrew ? "ממתין להוצאה ראשונה" : "Waiting for first expense")))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(info.amount > 0 ? (isSortingHub ? Color(red: 234/255, green: 88/255, blue: 12/255) : Color.themeMint) : Color.textMuted)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: onShowFeed) {
                HStack(spacing: 5) {
                    Text(isSortingHub ? (l10n.language == .hebrew ? "מיין חבילות" : "Triage") : (l10n.language == .hebrew ? "עסקאות" : "History"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Text(verbatim: l10n.language == .hebrew ? "‹" : "›")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSortingHub ? Color(red: 234/255, green: 88/255, blue: 12/255) : Color.primaryBlue)
                .clipShape(Capsule())
                .shadow(color: (isSortingHub ? Color(red: 234/255, green: 88/255, blue: 12/255) : Color.primaryBlue).opacity(0.25), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .bouncyPress(scale: 0.94)
        }
    }
}

#Preview {
    MainCityView()
        .preferredColorScheme(.light)
        .modelContainer(for: Transaction.self, inMemory: true)
}
