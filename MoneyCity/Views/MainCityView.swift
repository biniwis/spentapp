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
    
    @AppStorage("monthly_budget") private var userMonthlyBudget: Double = 0

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
    /// The city judges the month against the user's spending plan, not against their income —
    /// see `BudgetService.monthlySpendingBudget`. Zero here means no plan was set, and the
    /// engine falls back to what this user's own past months cost.
    private var effectiveMonthlyBudget: Double {
        BudgetService.monthlySpendingBudget(
            categoryBudgets: categoryBudgets,
            overallBudget: userMonthlyBudget
        )
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
    /// Bumped on every press of the city tab. The map watches it and puts the camera back to
    /// the view the app opens on — the district alone is not enough, because rotating and
    /// panning happen inside city mode and leave nothing for a district change to undo.
    @State private var cityViewResetToken: Int = 0
    
    public init() {}
    
    private var displayTransactions: [Transaction] {
        currentMonthTransactions
    }
    
    private var currentCity: MonthlyCity {
        var hasher = Hasher()
        hasher.combine(transactionsDigest)
        hasher.combine(currentDate.timeIntervalSinceReferenceDate)
        hasher.combine(effectiveMonthlyBudget)
        hasher.combine(typicalMonthlySpend)
        hasher.combine(typicalEverydaySpend)
        hasher.combine(typicalCommittedSpend)
        hasher.combine(everydayBudget)
        hasher.combine(budgetedEverydayCategories.count)
        return derived.city(key: hasher.finalize()) {
            CitySimulationEngine.shared.generateCity(
                for: currentDate,
                transactions: displayTransactions,
                estimatedMonthlyBudget: effectiveMonthlyBudget,
                typicalMonthlySpend: typicalMonthlySpend,
                typicalEverydaySpend: typicalEverydaySpend,
                typicalCommittedSpend: typicalCommittedSpend,
                everydayBudget: everydayBudget,
                budgetedEverydayCategories: budgetedEverydayCategories
            )
        }
    }

    /// The everyday categories the user set a ceiling on. Empty when they set a single
    /// overall figure or nothing at all, which is the signal to count everything.
    private var budgetedEverydayCategories: Set<SpendingCategory> {
        var set: Set<SpendingCategory> = []
        for b in categoryBudgets where b.monthlyLimit > 0 {
            let key = b.category.canonical
            if CitySimulationEngine.isEverydaySpending(key) { set.insert(key) }
        }
        return set
    }

    /// What the user has to spend on day-to-day things — see
    /// `BudgetService.everydaySpendingBudget` for why this cannot be derived from the
    /// headline budget alone.
    private var everydayBudget: Double {
        BudgetService.everydaySpendingBudget(
            categoryBudgets: categoryBudgets,
            overallBudget: userMonthlyBudget,
            typicalCommittedSpend: typicalCommittedSpend,
            typicalEverydaySpend: typicalEverydaySpend
        )
    }

    /// What a normal month costs this user, averaged over the months they have completed.
    /// Defined as the two halves of `typicalSplit` added back together, rather than a second
    /// pass over the same transactions — one loop, so the whole and its parts cannot drift.
    private var typicalMonthlySpend: Double { typicalSplit.everyday + typicalSplit.committed }

    /// The same average as `typicalMonthlySpend`, split the way the garden reads it: what a
    /// normal month costs this person in day-to-day money, and what their fixed costs come to.
    /// Averaging them separately matters — a month where the rent was paid late would
    /// otherwise drag the everyday figure around for no reason.
    private var typicalEverydaySpend: Double { typicalSplit.everyday }
    private var typicalCommittedSpend: Double { typicalSplit.committed }

    private var typicalSplit: (everyday: Double, committed: Double) {
        let cal = Calendar.current
        let thisMonth = cal.dateComponents([.year, .month], from: Date())
        var everydayByMonth: [DateComponents: Double] = [:]
        var committedByMonth: [DateComponents: Double] = [:]
        for tx in allTransactions where tx.category.canonical != .savings && tx.amount > 0 {
            let c = cal.dateComponents([.year, .month], from: tx.timestamp)
            if c.year == thisMonth.year && c.month == thisMonth.month { continue }
            if CitySimulationEngine.isEverydaySpending(tx.category) {
                everydayByMonth[c, default: 0] += tx.amount
            } else {
                committedByMonth[c, default: 0] += tx.amount
            }
        }
        func mean(_ d: [DateComponents: Double]) -> Double {
            let vals = d.values.filter { $0 > 0 }
            guard !vals.isEmpty else { return 0 }
            return vals.reduce(0, +) / Double(vals.count)
        }
        return (mean(everydayByMonth), mean(committedByMonth))
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
                    savingsTarget: currentCity.savingsTarget,
                    parkHealth: currentCity.parkHealth,
                    viewResetToken: cityViewResetToken,
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
                    districtSelectorRow
                        .padding(.top, 2)
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
                .frame(maxHeight: .infinity, alignment: .top)
            }

            // ── Unified Floating Bottom Cards & Navigation Bar (Zero Overlap & Zero Dead Space) ──
            if !isZenMode {
                VStack(spacing: 8) {
                    Spacer()
                    if activeTab == "city" {
                        if let b = inspectedBuilding, b.id == "savings_sanctuary" {
                            // The reserve is the one place in the city that measures what was
                            // NOT spent, so the spend-shaped card — amount, item count, trend —
                            // had nothing true to put in any of its three slots.
                            ReserveModalView(snapshot: reserveSnapshot, onClose: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    inspectedBuilding = nil
                                }
                            }, onShowFeed: { showFeed = true })
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else if let b = inspectedBuilding {
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
                        onQuickAdd: { showQuickAdd = true },
                        // The city tab is the way back to the whole city. Leaving the camera
                        // inside a district meant the button appeared to do nothing whenever
                        // you were already on the city tab, and the only way out was the
                        // "back to city" button on a card that is not always on screen.
                        onTabTapped: { tab in
                            guard tab == "city" else { return }
                            handleSelectDistrict(nil)
                            // Rotation, tilt, zoom and pan all live inside city mode, so
                            // clearing the district cannot undo them. This asks the map for
                            // the opening view back.
                            cityViewResetToken &+= 1
                        }
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
            QuickAddSheet(initialOpenScan: quickAddInitialScan) { amount, cat, note, origAmount, origCurrency, exchangeRate, buildingId in
                let finalBuildingId = buildingId ?? CategorizationEngine.shared.mapToBuildingId(category: cat, merchant: note)
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
                    buildingId: finalBuildingId,
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
            .environmentObject(l10n)
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingWizardView(
                onComplete: {
                    hasCompletedOnboarding = true
                    showOnboarding = false
                },
                onTriggerSampleTransaction: {
                    // Deliberately empty. This used to write a real ₪14 "ארומה קפה" expense into
                    // the ledger on first launch, so every user's first history entry, first
                    // building total and first recap contained a purchase they never made.
                    // The city starts empty and fills with the user's own spending.
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
    
    /// Everything the reserve's card needs, taken from the same city model the 3D scene draws,
    /// so the card and the land can never disagree.
    private var reserveSnapshot: ReserveSnapshot {
        let city = currentCity
        let elapsed = CitySimulationEngine.budgetAccruedFraction(for: currentDate, now: Date())
        return ReserveSnapshot(
            savedThisMonth: city.totalSavings,
            health: city.parkHealth,
            monthElapsed: elapsed,
            spentThisMonth: city.everydaySpent,
            plannedSpending: city.everydayBaseline,
            budgetedCategoryCount: budgetedEverydayCategories.count
        )
    }

    private func handleSelectBuilding(_ building: DistrictBuildingInfo) {
        // The 3D scene carries a `visits` count and a trend string baked into each mesh — they
        // were authored as design placeholders and nothing ever updates them, so tapping the
        // coffee shop always claimed "12 עסקאות • ‎+20%" whatever the user actually spent.
        // Everything shown here is recomputed from the user's own transactions.
        let real = DistrictBuildingInfo(
            id: building.id,
            districtId: building.districtId,
            name: building.name,
            amount: currentCity.buildingTotals[building.id] ?? 0,
            visitCount: buildingVisitCount(for: building.id),
            trendText: buildingTrendText(for: building.id)
        )
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            inspectedBuilding = real
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
                        
                        Text("סה״כ \(l10n.format(amount: districtTotal(for: dist))) החודש")
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
                                        
                                        Text(l10n.format(amount: pill.amount))
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
                        
                        Text(l10n.format(amount: currentCity.totalSpent))
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                    }
                    
                    Spacer()
                    
                    // Mint Green Savings Park Badge
                    HStack(spacing: 5) {
                        DistrictParkVectorIcon(color: Color.themeMint)
                            .frame(width: 14, height: 14)
                            .scaleEffect(0.65)
                        // "in Park" named a place, not the number. It is what the user tagged
                        // as savings or investment, so it takes that category's name.
                        Text("\(l10n.format(amount: currentCity.totalSavings)) \(SpendingCategory.savings.displayName(for: l10n.language))")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
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
                        
                        Text("-\(l10n.format(amount: progressReport.savedAmount)) \(l10n.language == .hebrew ? "השבוע" : "this week")")
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
                
                Text(l10n.format(amount: amount))
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
    
    private var localizedBuildingTitle: String {
        let isHe = l10n.language == .hebrew
        switch info.id {
        case "food_bistro": return isHe ? "ביסטרו ומסעדות" : "Bistro & Dining"
        case "food_super": return isHe ? "סופרמרקט ומזון" : "Supermarket & Food"
        case "food_coffee": return isHe ? "אספרסו בר" : "Espresso Bar"
        case "food_wolt": return isHe ? "וולט ומשלוחי אוכל" : "Food Delivery"
        case "shop_boutique": return isHe ? "בוטיק אופנה" : "Fashion Boutique"
        case "shop_tech": return isHe ? "חנות אלקטרוניקה" : "Electronics Store"
        case "shop_travel": return isHe ? "סוכנות נסיעות" : "Travel Agency"
        case "shop_arcade": return isHe ? "מתחם ארקייד" : "Arcade Complex"
        case "house_tower": return isHe ? "מגדל מגורים" : "Residential Tower"
        case "house_util": return isHe ? "חשמל ומים" : "Power & Water"
        case "house_subs": return isHe ? "מנויים וסטרימינג" : "Subscriptions & Streaming"
        case "savings_sanctuary": return isHe ? "שמורת הטבע והחיסכון" : "Nature & Savings Park"
        case "trans_station": return isHe ? "תחבורה וחניה" : "Transit & Parking"
        case "city_sorting_hub": return isHe ? "מרכז המיון והדואר" : "City Sorting Hub"
        default:
            return info.name
        }
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
                Text(localizedBuildingTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                if isSortingHub {
                    if info.amount > 0 {
                        Text("\(l10n.format(amount: info.amount)) \(l10n.language == .hebrew ? "שונות למיון" : "to triage") • \(info.visitCount) \(l10n.language == .hebrew ? "חבילות" : "packages")")
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
                    Text("\(l10n.format(amount: info.amount)) \(l10n.language == .hebrew ? "החודש" : "this month") • \(info.visitCount) \(l10n.language == .hebrew ? "פעולות" : "items")")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.primaryBlue)
                } else {
                    Text(l10n.language == .hebrew ? "מגרש פנוי • \(l10n.format(amount: 0)) החודש" : "Vacant Lot • \(l10n.baseCurrency.symbol)0")
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


/// What the nature reserve knows about itself.
struct ReserveSnapshot {
    let savedThisMonth: Double
    let health: Double
    let monthElapsed: Double
    let spentThisMonth: Double
    let plannedSpending: Double
    /// How many everyday categories the user put a ceiling on. Zero means the plan covers
    /// the whole month, so the card can say so rather than implying a narrower scope.
    let budgetedCategoryCount: Int
}

/// The reserve's own card.
///
/// Every other building answers "how much did I spend here". The reserve answers the exact
/// opposite — what stayed put — and it is the only thing in the city that carries over between
/// months. Handing it the spending card meant three fields that were either meaningless
/// (a visit count for a park) or actively wrong (a "trend" on money that was never spent).
struct ReserveModalView: View {
    let snapshot: ReserveSnapshot
    let onClose: () -> Void
    let onShowFeed: () -> Void
    @EnvironmentObject private var l10n: LocalizationManager

    private var isHebrew: Bool { l10n.language == .hebrew }
    private let reserveGreen = Color(red: 16/255, green: 185/255, blue: 129/255)

    /// The condition of the land, in words. The number itself means nothing to anyone.
    private var conditionText: String {
        switch snapshot.health {
        case 0.95...:     return isHebrew ? "פורחת" : "Flourishing"
        case 0.80..<0.95: return isHebrew ? "משגשגת" : "Thriving"
        case 0.68..<0.80: return isHebrew ? "מטופחת" : "Well kept"
        case 0.45..<0.68: return isHebrew ? "מתחילה להתייבש" : "Drying out"
        default:          return isHebrew ? "יבשה" : "Parched"
        }
    }

    private var conditionColor: Color {
        if snapshot.health >= 0.78 { return reserveGreen }
        if snapshot.health >= 0.55 { return Color.themeYellow }
        return Color.red
    }

    /// The number is now one thing: money the user recorded moving into savings this month.
    /// It used to add "budget you have not spent" on top, which is not money anyone holds and
    /// is why nobody could tell what the figure meant.
    private var basisText: String {
        if snapshot.savedThisMonth > 0 {
            return isHebrew
                ? "מה שסימנת החודש כחיסכון או השקעה"
                : "what you tagged as savings or investment this month"
        }
        // An empty figure should say how to fill it, not just that it is empty.
        return isHebrew
            ? "אין החודש. סמן הפקדה או השקעה בקטגוריה הזו והיא תופיע כאן."
            : "None this month. Tag a deposit or investment with this category and it appears here."
    }

    /// Straight-line projection, and only once enough of the month has gone by to mean anything.
    private var projection: Double? {
        guard snapshot.monthElapsed >= 0.20, snapshot.savedThisMonth > 0 else { return nil }
        return snapshot.savedThisMonth / snapshot.monthElapsed
    }

    /// The two numbers being compared, each said out loud.
    ///
    /// The old card gave one sentence with a single figure in it and no label, so there was
    /// no way to tell whether it meant "you spent this" or "you are this much over" — and if
    /// the verdict looked wrong there was nothing to check it against. Both sides are now
    /// shown: what was spent, and what the target was by today.
    private var targetSoFar: Double { snapshot.plannedSpending * snapshot.monthElapsed }
    private var overUnder: Double { snapshot.spentThisMonth - targetSoFar }

    private var hasComparison: Bool { snapshot.plannedSpending > 0 && snapshot.monthElapsed > 0 }

    private var verdictLine: String {
        guard hasComparison else {
            return isHebrew
                ? "מוקדם מדי בחודש בשביל מסקנה — השמורה מחכה לנתונים."
                : "Too early in the month to judge — the reserve is waiting for data."
        }
        let d = overUnder.rounded()
        if d > 0 {
            return isHebrew
                ? "\(l10n.format(amount: d)) מעל הקצב"
                : "\(l10n.format(amount: d)) ahead of pace"
        }
        return isHebrew
            ? "\(l10n.format(amount: -d)) מתחת לקצב"
            : "\(l10n.format(amount: -d)) under pace"
    }

    /// What is actually being counted, which depends on how the user set their plan.
    private var scopeTitle: String {
        if snapshot.budgetedCategoryCount > 0 {
            return isHebrew ? "הקטגוריות שתקצבת, החודש" : "The categories you budgeted, this month"
        }
        return isHebrew ? "הוצאות יומיומיות החודש" : "Everyday spending this month"
    }

    private var scopeNote: String {
        if snapshot.budgetedCategoryCount > 0 {
            return isHebrew
                ? "נמדד מול התקרות שהגדרת בעמוד התקציב, ורק עליהן. שכירות, חשבונות ומנויים לא נספרים."
                : "Measured against the ceilings you set on the budget screen, and only those. Rent, bills and subscriptions are not counted."
        }
        return isHebrew
            ? "שכירות, חשבונות בית ומנויים לא נספרים כאן — הם קבועים ולא תלויים בהחלטות היומיות שלך."
            : "Rent, household bills and subscriptions are not counted here — they are fixed, not daily decisions."
    }

    private var comparisonRow: some View {
        let pct = Int((snapshot.monthElapsed * 100).rounded())
        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(scopeTitle)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                Spacer()
                Text(isHebrew ? "\(pct)% מהחודש עבר" : "\(pct)% of the month gone")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textMuted)
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(l10n.format(amount: snapshot.spentThisMonth.rounded()))")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if hasComparison {
                    Text(isHebrew
                         ? "מתוך \(l10n.format(amount: targetSoFar.rounded())) שתכננת עד היום"
                         : "of the \(l10n.format(amount: targetSoFar.rounded())) you planned by today")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if hasComparison {
                GeometryReader { geo in
                    ZStack(alignment: isHebrew ? .trailing : .leading) {
                        Capsule().fill(Color.appBackground).frame(height: 6)
                        Capsule()
                            .fill(conditionColor)
                            .frame(width: max(4, geo.size.width * CGFloat(min(1.35, snapshot.spentThisMonth / max(targetSoFar, 1)) / 1.35)),
                                   height: 6)
                    }
                }
                .frame(height: 6)

                HStack(spacing: 6) {
                    Text(verdictLine)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(conditionColor)
                    Spacer()
                    Text(isHebrew ? "התקציב היומיומי: \(l10n.format(amount: snapshot.plannedSpending.rounded())) לחודש"
                                  : "Everyday budget: \(l10n.format(amount: snapshot.plannedSpending.rounded())) a month")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Text(scopeNote)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(Color.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(11)
        .background(Color.appBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            figuresRow
            comparisonRow

            Divider().background(Color(red: 243/255, green: 244/255, blue: 246/255))
            footerRow
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color(red: 243/255, green: 244/255, blue: 246/255), lineWidth: 1.5))
        .shadow(color: Color.black.opacity(0.08), radius: 16, y: 6)
        .padding(.horizontal, 20)
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(reserveGreen.opacity(0.12))
                    .frame(width: 46, height: 46)
                CategoryVectorIcon(category: .savings, size: 24)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(isHebrew ? "שמורת הטבע והחיסכון" : "Nature & Savings Reserve")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                // This used to carry a running total "put aside since you started". It summed
                // deposits together with budget the user simply had not spent, which is not
                // money anyone has — it went on something else, or never existed. A figure
                // that looks like a balance and is not one has no business on this card.
                Text(isHebrew ? "מצב החודש הזה" : "How this month is going")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textMuted)
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

    private var figuresRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                // The category's own name, so the number on the card and the label the user
                // picks when recording the expense are visibly the same thing.
                Text(SpendingCategory.savings.displayName(for: l10n.language))
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                Text("\(l10n.format(amount: snapshot.savedThisMonth.rounded()))")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(basisText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().frame(height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(isHebrew ? "מצב השמורה" : "Condition")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                Text(conditionText)
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundColor(conditionColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(isHebrew ? "מתאפס בכל חודש — הקרקע נשארת" : "Resets each month — the land stays")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footerRow: some View {
        HStack(spacing: 8) {
            if let projected = projection {
                Text(isHebrew ? "בקצב הזה:" : "At this rate:")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                Text(isHebrew
                     ? "\(l10n.format(amount: projected.rounded())) עד סוף החודש"
                     : "\(l10n.format(amount: projected.rounded())) by month end")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(reserveGreen)
                    .lineLimit(1)
            } else {
                Text(isHebrew ? "כל שקל שלא יוצא נשאר כאן" : "Every shekel that stays put lands here")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onShowFeed) {
                HStack(spacing: 5) {
                    Text(isHebrew ? "הפקדות" : "Deposits")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Text(verbatim: isHebrew ? "‹" : "›")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(reserveGreen)
                .clipShape(Capsule())
                .shadow(color: reserveGreen.opacity(0.25), radius: 6, y: 2)
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
