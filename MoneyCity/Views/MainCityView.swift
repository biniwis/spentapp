import SwiftUI
import SwiftData
import Combine

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

/// A single row in a district's building list — used both by the top pill strip
/// and the bottom DistrictDeepDiveCard.
struct BuildingPillItem: Identifiable {
    let id: String
    let title: String
    let amount: Double
    let info: DistrictBuildingInfo
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
    @Environment(\.scenePhase) private var companionScenePhase
    @AppStorage("cityCompanionsStartedAt") private var companionsStartedAt: Double = 0
    @State private var companionNow = Date()
    @State private var pendingCompanionWelcome: String? = nil
    @State private var isZenMode = false
    /// The month being looked back at, when the user opened one from the profile chart.
    ///
    /// This is its own mode rather than "the normal screen showing a different month". Showing
    /// history on the everyday screen means someone sees their own city with the wrong numbers
    /// in it and no idea why — so here the chrome goes, the camera pulls back, and the only
    /// controls are the month's name and the way out.
    @State private var monthSnapshot: Date? = nil
    @State private var isDetailsExpanded = false
    @State private var newlyUnlockedEnrichmentId: String? = nil
    @State private var selectedDistrict: String? = nil
    @State private var inspectedBuilding: DistrictBuildingInfo? = nil
    @State private var showSortingHubSheet = false
    @State private var showReserveSanctuarySheet = false
    @State private var activeTab: String = "city"
    /// Bumped on every press of the city tab. The map watches it and puts the camera back to
    /// the view the app opens on — the district alone is not enough, because rotating and
    /// panning happen inside city mode and leave nothing for a district change to undo.
    @State private var cityViewResetToken: Int = 0

    // ── Live Expense Confirmation & Rolling Amount ──
    @ObservedObject private var confirmationCoordinator = ExpenseConfirmationCoordinator.shared
    @State private var animatedSpentValue: Double? = nil
    @State private var visibleConfirmationBanner: PendingExpenseConfirmation? = nil
    
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
        hasher.combine(Int(companionNow.timeIntervalSince1970 / 60))
        return derived.report(key: hasher.finalize()) {
            let unlockedIds = Set(allEnrichments.map { $0.itemId })
            // The engine does its own 7/14-day windowing, so it needs the full history —
            // month-filtered rows leave the previous week empty for the first half of a month.
            return CityProgressEngine.shared.evaluateProgress(
                transactions: allTransactions,
                unlockedItemIds: unlockedIds,
                referenceDate: companionNow
            )
        }
    }
    
    private var activeEnrichmentIds: [String] {
        allEnrichments.filter { $0.isApplied }.map { $0.itemId }
    }
    
    private var companionFirstUse: Date { Date(timeIntervalSince1970: companionsStartedAt > 0 ? companionsStartedAt : companionNow.timeIntervalSince1970) }
    private var nextCompanionDate: Date {
        CityCompanions.nextDate(firstUse: companionFirstUse, lastReward: allEnrichments.map(\.unlockedDate).max())
    }
    
    private var weeklyRewardOptions: [ProgressRewardOption] {
        guard hasCompletedOnboarding, companionsStartedAt > 0, companionNow >= nextCompanionDate,
              progressReport.hasPositiveProgress else { return [] }
        let unlockedIds = Set(allEnrichments.map { $0.itemId })
        return CityProgressEngine.shared.availableWeeklyOptions(unlockedItemIds: unlockedIds)
    }
    
    private var currentCalendarWeekKey: String {
        let cal = Calendar.current
        let year = cal.component(.yearForWeekOfYear, from: Date())
        let week = cal.component(.weekOfYear, from: Date())
        return "\(year)-W\(week)"
    }
    
    private var currentSlotPlacements: [String: String] {
        CitySlot.resolvedPlacements(allEnrichments.filter { !CityCompanions.ids.contains($0.itemId) }.map {
            CityPlacement(itemId: $0.itemId, slotId: $0.placedSlotId, isApplied: $0.isApplied)
        })
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
                    isOverview: isSnapshotMode,
                    categoryTotals: currentCity.categoryTotals,
                    buildingTotals: currentCity.buildingTotals,
                    districtStates: currentCity.districtStates,
                    venueStates: currentCity.venueStates,
                    habits: currentCity.habits,
                    enrichmentIds: activeEnrichmentIds,
                    newlyUnlockedEnrichmentId: newlyUnlockedEnrichmentId,
                    slotPlacements: currentSlotPlacements,
                    selectedDistrict: selectedDistrict,
                    language: l10n.language == .hebrew ? "he" : "en",
                    isPaused: (activeTab != "city"),
                    onSelectDistrict: handleSelectDistrict,
                    onBuildingSelected: handleSelectBuilding,
                    onSlotTapped: nil
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 2. Top Header & Category Selector (Reference Screen 1)
                topControlsHeader
            }
            .opacity(activeTab == "city" ? 1.0 : 0.0)
            .allowsHitTesting(activeTab == "city")

            // ── Other Tabs ──
            if activeTab == "analytics" {
                AnalyticsView(onNavigateToCity: openMonthSnapshot)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
            } else if activeTab == "history" {
                HistoryView()
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
            } else if activeTab == "profile" {
                ProfileView(onNavigateToCity: openMonthSnapshot)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
            }

            // Zen mode and Past Month indicators (city only)
            if activeTab == "city" {
                HStack {
                    if isSnapshotMode {
                        Button(action: closeMonthSnapshot) {
                            HStack(spacing: 8) {
                                MoneyIcon(l10n.language == .hebrew ? .chevronRight : .chevronLeft, size: 14)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(monthYearString)
                                        .font(.system(size: 13.5, weight: .black, design: .rounded))
                                    Text(l10n.language == .hebrew
                                         ? "\(l10n.format(amount: currentCity.totalSpent.rounded())) הוצאות"
                                         : "\(l10n.format(amount: currentCity.totalSpent.rounded())) spent")
                                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                        .opacity(0.75)
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(Color.deepNavy.opacity(0.92))
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.18), radius: 8, y: 3)
                        }
                        .buttonStyle(.plain)
                        .bouncyPress(scale: 0.95)
                        .padding(.leading, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    } else if isViewingPastMonth {
                        // Deliberately not styled like the rest of the chrome: this is a state
                        // the user did not choose to be in permanently, and it has to read as
                        // temporary and reversible at a glance.
                        Button(action: returnToCurrentMonth) {
                            HStack(spacing: 7) {
                                MoneyIcon(.refresh, size: 14)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(monthYearString)
                                        .font(.system(size: 12.5, weight: .black, design: .rounded))
                                    Text(l10n.language == .hebrew ? "חזרה לחודש הנוכחי" : "Back to this month")
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .opacity(0.75)
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.themeLavender)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.15), radius: 6, y: 2)
                        }
                        .buttonStyle(.plain)
                        .bouncyPress(scale: 0.94)
                        .padding(.leading, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
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

                        Spacer()

                        // Clean exit button when in Zen mode
                        Button(action: {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                                isZenMode = false
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.94))
                                    .frame(width: 38, height: 38)
                                    .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                DioramaExpandVectorIcon(isExpanded: true, color: Color.deepNavy)
                                    .frame(width: 15, height: 15)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                    } else {
                        Spacer()
                    }
                }
                .padding(.top, 56)
                .frame(maxHeight: .infinity, alignment: .top)
            }

            // ── Unified Floating Bottom Cards & Navigation Bar (Zero Overlap & Zero Dead Space) ──
            if !isChromeHidden {
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
                            }, onShowFeed: { showReserveSanctuarySheet = true })
                            .id(b.id)
                            .transition(.asymmetric(
                                insertion: .offset(y: 16).combined(with: .opacity),
                                removal: .opacity
                            ))
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
                            // Identity keyed on the building, so exchanging one card for
                            // another is an insertion the transition can actually play.
                            .id(b.id)
                            .transition(.asymmetric(
                                insertion: .offset(y: 16).combined(with: .opacity),
                                removal: .opacity
                            ))
                        } else if let dist = selectedDistrict {
                            DistrictDeepDiveCard(
                                districtId: dist,
                                onBack: {
                                    withAnimation { selectedDistrict = nil; inspectedBuilding = nil }
                                },
                                onSelectBuilding: handleSelectBuilding,
                                pills: districtBuildingPills(for: dist),
                                total: districtTotal(for: dist)
                            )
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
                            // the opening view back — and the opening view is this month, so
                            // the tab is a way out of a past month as well as out of a
                            // district.
                            if isViewingPastMonth { currentDate = Date() }
                            cityViewResetToken &+= 1
                        }
                    )
                }
                .padding(.bottom, 6)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            
        }

        .onAppear {
            if companionsStartedAt == 0 {
                let previousStart = UserDefaults.standard.object(forKey: "firstAppLaunchDate") as? Date
                companionsStartedAt = min(previousStart ?? Date(), Date()).timeIntervalSince1970
            }
            companionNow = Date()
            if !hasCompletedOnboarding && allTransactions.isEmpty {
                showOnboarding = true
            }
            syncWidgetData()
            checkWeeklyEnrichmentPrompt()
            
            // Check if app was cold-launched or opened via payment notification tap
            if let pending = confirmationCoordinator.activeConfirmation {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    triggerExpenseRollConfirmation(pending)
                    confirmationCoordinator.activeConfirmation = nil
                }
            }
        }
        .onChange(of: transactionsDigest) { _, _ in
            syncWidgetData()
        }
        .onReceive(confirmationCoordinator.$activeConfirmation) { newConf in
            if let newConf {
                triggerExpenseRollConfirmation(newConf)
                confirmationCoordinator.activeConfirmation = nil
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

                let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                let merchantTitle = !trimmed.isEmpty ? trimmed : cat.displayName(for: l10n.language)
                ExpenseConfirmationCoordinator.shared.triggerConfirmation(
                    amount: amount,
                    merchant: merchantTitle,
                    isRefund: false
                )
            }
            .environmentObject(l10n)
        }
        .sheet(isPresented: $showFeed) {
            // The sheet used to take an onUpdateCategory closure it never called — tapping a
            // row opens the edit sheet, which does this work itself. The parameter is gone
            // rather than kept as nine lines that look wired up and are not.
            TransactionFeedSheet(
                title: feedSheetTitle,
                transactions: feedFilteredTransactions
            )
            .environmentObject(l10n)
        }
        .onChange(of: companionScenePhase) { _, phase in
            if phase == .active { companionNow = Date(); checkWeeklyEnrichmentPrompt() }
        }
        .sheet(isPresented: $showProgressSheet, onDismiss: {
            guard let id = pendingCompanionWelcome else { return }
            pendingCompanionWelcome = nil
            newlyUnlockedEnrichmentId = id
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                if newlyUnlockedEnrichmentId == id { newlyUnlockedEnrichmentId = nil }
            }
        }) {
            CityProgressSheet(
                options: weeklyRewardOptions,
                unlockedEnrichments: allEnrichments,
                nextDate: nextCompanionDate,
                savedAmount: progressReport.savedAmount,
                hasBaseline: progressReport.previousWeekTotal > 0,
                onSelectOption: { opt in
                    companionNow = Date()
                    guard pendingCompanionWelcome == nil,
                          weeklyRewardOptions.contains(where: { $0.id == opt.id }),
                          !allEnrichments.contains(where: { $0.itemId == opt.id }) else { return false }
                    let newEnrichment = CityEnrichment(
                        itemId: opt.id,
                        name: opt.title,
                        subtitle: opt.subtitle,
                        icon: opt.icon,
                        type: opt.type,
                        tier: opt.tier,
                        savedAmount: progressReport.savedAmount,
                        districtId: opt.districtId,
                        isApplied: true,
                        placedSlotId: nil
                    )
                    modelContext.insert(newEnrichment)
                    do { try modelContext.save() }
                    catch {
                        modelContext.delete(newEnrichment)
                        return false
                    }
                    
                    
                    Haptics.notify(.success)
                    Haptics.impact(.heavy)
                    
                    pendingCompanionWelcome = opt.id
                    return true
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
            .environmentObject(l10n)
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
            .environmentObject(l10n)
        }
        .sheet(isPresented: $showReserveSanctuarySheet) {
            ReserveSanctuarySheet()
                .environmentObject(l10n)
        }
    }
    
    private func syncWidgetData() {
        #if canImport(WidgetKit)
        let spent = currentCity.totalSpent
        let budget = effectiveMonthlyBudget
        let savings = currentCity.totalSavings
        let merchant = displayTransactions.first?.merchant ?? ""
        MoneyCityWidgets.publishData(
            spent: spent,
            budget: budget,
            savings: savings,
            recentMerchant: merchant,
            isHebrew: l10n.language == .hebrew
        )
        #endif
    }
    
    /// Triggers visual rolling number interpolation on the hero spending KPI and displays a subtle confirmation pill.
    private func triggerExpenseRollConfirmation(_ conf: PendingExpenseConfirmation) {
        // Ensure city tab is active so the user visibly sees their numbers update
        activeTab = "city"
        
        let targetTotal = currentCity.totalSpent
        let startingVal = max(0, targetTotal - conf.amount)
        
        // 1. Immediately set starting value and show confirmation banner
        animatedSpentValue = startingVal
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            visibleConfirmationBanner = conf
        }
        Haptics.impact(.light)
        
        // 2. Count up smoothly to targetTotal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.82)) {
                animatedSpentValue = targetTotal
            }
        }
        
        // 3. Success haptic when counter settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            Haptics.notify(.success)
        }
        
        // 4. Fade out confirmation pill after 3.8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            withAnimation(.easeOut(duration: 0.35)) {
                if visibleConfirmationBanner?.id == conf.id {
                    visibleConfirmationBanner = nil
                    animatedSpentValue = nil
                }
            }
        }
    }
    
    private func checkWeeklyEnrichmentPrompt() {
        guard hasCompletedOnboarding, !isSnapshotMode, !showProgressSheet, !showOnboarding else { return }
        guard !weeklyRewardOptions.isEmpty else { return }
        
        let currentWeek = currentCalendarWeekKey
        let lastPromptWeek = UserDefaults.standard.string(forKey: "lastAdditionsPromptWeekKey")
        
        // Trigger only once per calendar week
        guard lastPromptWeek != currentWeek else { return }
        
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                guard !weeklyRewardOptions.isEmpty, !showOnboarding, !isSnapshotMode else { return }
                UserDefaults.standard.set(currentWeek, forKey: "lastAdditionsPromptWeekKey")
                showProgressSheet = true
            }
    }
    
    private func handleSelectDistrict(_ dist: String?) {
        if dist != selectedDistrict { Haptics.selection() }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            selectedDistrict = dist
            // Always clear the building card when changing district/mode,
            // so the next tap on a building is a fresh selection.
            inspectedBuilding = nil
            // Collapse expanded details so the card doesn't open pre-expanded next time.
            isDetailsExpanded = false
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
        // Selecting a different building only changed the numbers inside a card that was
        // already on screen, so SwiftUI reused the same view: no transition ran, nothing moved,
        // and the tap felt like it had missed. The `.id` on the card below makes a swap a real
        // insertion so it animates, and the feedback here distinguishes the two cases —
        // opening a card from nothing, and exchanging one for another.
        let isSwap = inspectedBuilding != nil && inspectedBuilding?.id != real.id
        if isSwap {
            Haptics.selection()
        } else if inspectedBuilding == nil {
            Haptics.impact(.light)
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            inspectedBuilding = real
        }
    }
    

    @ViewBuilder
    private var topControlsHeader: some View {
        if !isChromeHidden {
            VStack(spacing: 10) {
                topNavigationBar
                heroKpiRow
                confirmationBannerView
                districtSelectorRow
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var topNavigationBar: some View {
        HStack(alignment: .center) {
            Text("SPENT")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(Color.deepNavy)
                .tracking(0.5)

            Spacer()

            Button {
                companionNow = Date()
                showProgressSheet = true
            } label: {
                MoneyIcon(.gift, size: 22)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.94), in: Circle())
                    .overlay(alignment: .topTrailing) {
                        if !weeklyRewardOptions.isEmpty {
                            Circle().fill(Color.themeMint).frame(width: 10, height: 10)
                        }
                    }
            }
            .accessibilityLabel(l10n.isHebrew ? "מצטרפים לעיר — הפרס השבועי" : "City companions — weekly reward")

            Button(action: {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    isZenMode.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.94))
                        .frame(width: 38, height: 38)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
                    DioramaExpandVectorIcon(isExpanded: isZenMode, color: Color.deepNavy)
                        .frame(width: 15, height: 15)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private var heroKpiRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            RollingNumberText(
                value: animatedSpentValue ?? currentCity.totalSpent,
                format: { (amt: Double) -> String in l10n.format(amount: amt) }
            )

            HStack(spacing: 3) {
                MoneyIcon(.chevronDown, size: 11)
                Text("12%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(red: 220/255, green: 252/255, blue: 231/255))
            .clipShape(Capsule())

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var confirmationBannerView: some View {
        if let banner = visibleConfirmationBanner {
            let label: String = banner.merchant.isEmpty
                ? (l10n.isHebrew ? "הוצאה עודכנה" : "Expense recorded")
                : banner.merchant
            let amountStr: String = l10n.format(amount: banner.amount)

            HStack(spacing: 7) {
                MoneyIcon(.checkCircle, size: 13)
                    .foregroundColor(MoneyCityTheme.mint)

                Text("+\(amountStr) · \(label)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
            )
            .overlay(
                Capsule()
                    .stroke(Color.borderSubtle, lineWidth: 1)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, -4)
        }
    }
    
    private var districtSelectorRow: some View {
        HStack(spacing: 0) {
            topDistrictPill(
                id: nil,
                title: l10n.language == .hebrew ? "כל העיר" : "All City",
                unselectedBg: Color(red: 243/255, green: 244/255, blue: 246/255)
            ) { isSelected in
                MoneyIcon(.citySkyline, size: 24)
            }
            topDistrictPill(
                id: "food",
                title: l10n.language == .hebrew ? "אוכל" : "Food",
                unselectedBg: Color(red: 254/255, green: 242/255, blue: 232/255)
            ) { isSelected in
                MoneyIcon(.cutlery, size: 24)
            }
            topDistrictPill(
                id: "shopping",
                title: l10n.language == .hebrew ? "קניות" : "Shopping",
                unselectedBg: Color(red: 253/255, green: 238/255, blue: 244/255)
            ) { isSelected in
                MoneyIcon(.shoppingBag, size: 24)
            }
            topDistrictPill(
                id: "housing",
                title: l10n.language == .hebrew ? "מגורים" : "Housing",
                unselectedBg: Color(red: 238/255, green: 245/255, blue: 254/255)
            ) { isSelected in
                MoneyIcon(.home, size: 24)
            }
            topDistrictPill(
                id: "savings",
                title: l10n.language == .hebrew ? "חיסכון" : "Savings",
                unselectedBg: Color(red: 234/255, green: 248/255, blue: 240/255)
            ) { isSelected in
                MoneyIcon(.leaf, size: 24)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 3)
        .padding(.horizontal, 16)
    }
    
    private func topDistrictPill<V: View>(
        id: String?,
        title: String,
        unselectedBg: Color = Color(red: 246/255, green: 247/255, blue: 250/255),
        @ViewBuilder icon: (Bool) -> V
    ) -> some View {
        let isSelected = (id == nil && selectedDistrict == nil) || (id != nil && selectedDistrict == id)
        return Button(action: {
            handleSelectDistrict(id)
        }) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white : unselectedBg)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color(red: 24/255, green: 24/255, blue: 27/255) : Color.clear, lineWidth: 2.2)
                        )
                        .shadow(color: isSelected ? Color.black.opacity(0.12) : Color.clear, radius: 4, y: 2)
                        .scaleEffect(isSelected ? 1.06 : 1.0)
                    
                    icon(isSelected)
                }
                
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? Color(red: 17/255, green: 24/255, blue: 39/255) : Color(red: 100/255, green: 116/255, blue: 139/255))
                
                // Crisp Minimal Selection Indicator
                if isSelected {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(red: 17/255, green: 24/255, blue: 39/255))
                        .frame(width: 12, height: 2.5)
                } else {
                    Color.clear.frame(width: 12, height: 2.5)
                }
            }
            .contentShape(Rectangle())
        }
        .bouncyPress(scale: 0.90)
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func buildingIcon(_ id: String) -> some View {
        switch id {
        case "food_bistro": MoneyIcon(.cutlery, size: 18)
        case "food_super": MoneyIcon(.cart, size: 18)
        case "food_coffee": MoneyIcon(.coffee, size: 18)
        case "food_wolt": MoneyIcon(.car, size: 18)
        case "shop_boutique": MoneyIcon(.shoppingBag, size: 18)
        case "shop_tech": MoneyIcon(.gamepad, size: 18)
        case "shop_travel": MoneyIcon(.airplane, size: 18)
        case "shop_arcade": MoneyIcon(.gamepad, size: 18)
        case "house_tower": MoneyIcon(.home, size: 18)
        case "house_util": MoneyIcon(.lightning, size: 18)
        case "house_subs": MoneyIcon(.refresh, size: 18)
        case "savings_sanctuary": MoneyIcon(.leaf, size: 18)
        case "city_sorting_hub": MoneyIcon(.mail, size: 18)
        case "museum_curiosities": MoneyIcon(.gift, size: 18)
        default: MoneyIcon(.home, size: 18)
        }
    }

    private func isPillSelected(_ pill: BuildingPillItem) -> Bool {
        inspectedBuilding?.id == pill.id
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
                BuildingPillItem(id: "food_bistro", title: isHe ? "מסעדות" : "Restaurants", amount: r, info: DistrictBuildingInfo(id: "food_bistro", districtId: "food", name: isHe ? "מסעדות" : "Restaurants", amount: r, visitCount: buildingVisitCount(for: "food_bistro"), trendText: buildingTrendText(for: "food_bistro"))),
                BuildingPillItem(id: "food_super", title: isHe ? "סופר ומכולת" : "Groceries", amount: g, info: DistrictBuildingInfo(id: "food_super", districtId: "food", name: isHe ? "סופר ומכולת" : "Supermarket & Groceries", amount: g, visitCount: buildingVisitCount(for: "food_super"), trendText: buildingTrendText(for: "food_super"))),
                BuildingPillItem(id: "food_coffee", title: isHe ? "בתי קפה" : "Coffee", amount: c, info: DistrictBuildingInfo(id: "food_coffee", districtId: "food", name: isHe ? "בתי קפה" : "Cafes", amount: c, visitCount: buildingVisitCount(for: "food_coffee"), trendText: buildingTrendText(for: "food_coffee"))),
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
                            MoneyIcon(.xmarkCircle, size: 14)
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
                                    buildingIcon(pill.id)
                                    
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
                                .background(isPillSelected(pill) ? Color.themeLavenderSoft : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isPillSelected(pill) ? Color.primaryBlue : Color.clear,
                                                lineWidth: isPillSelected(pill) ? 2 : 0)
                                )
                                // Lifted and slightly larger, so which one is selected reads
                                // from the corner of the eye rather than needing to be looked
                                // for. The tint and hairline border alone did not register.
                                .scaleEffect(isPillSelected(pill) ? 1.05 : 1.0)
                                .shadow(color: isPillSelected(pill) ? Color.primaryBlue.opacity(0.22) : Color.deepNavy.opacity(0.04),
                                        radius: isPillSelected(pill) ? 7 : 4,
                                        y: isPillSelected(pill) ? 3 : 2)
                                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: inspectedBuilding?.id)
                            }
                            .buttonStyle(.plain)
                            .bouncyPress(scale: 0.94)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                }
            }
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var spendingCard: some View {
        let foodAmt = (currentCity.categoryTotals[.food] ?? 0) + (currentCity.categoryTotals[.groceries] ?? 0)
        let shopAmt = currentCity.categoryTotals[.shopping] ?? 0
        let houseAmt = currentCity.categoryTotals[.housing] ?? 0
        let savingsAmt = currentCity.totalSavings
        let displayTotal = max(currentCity.totalSpent, 1.0)

        let (badgeBg, title, subtitle, amount): (Color, String, String, Double) = {
            switch selectedDistrict {
            case "food":
                return (Color(red: 254/255, green: 242/255, blue: 232/255),
                        l10n.language == .hebrew ? "רובע האוכל" : "Food District",
                        l10n.language == .hebrew ? "\(Int(round((foodAmt / displayTotal) * 100)))% מההוצאות" : "\(Int(round((foodAmt / displayTotal) * 100)))% of spending",
                        foodAmt)
            case "shopping":
                return (Color(red: 253/255, green: 238/255, blue: 244/255),
                        l10n.language == .hebrew ? "שדרת הקניות" : "Shopping District",
                        l10n.language == .hebrew ? "\(Int(round((shopAmt / displayTotal) * 100)))% מההוצאות" : "\(Int(round((shopAmt / displayTotal) * 100)))% of spending",
                        shopAmt)
            case "housing":
                return (Color(red: 238/255, green: 245/255, blue: 254/255),
                        l10n.language == .hebrew ? "מתחם המגורים" : "Housing District",
                        l10n.language == .hebrew ? "\(Int(round((houseAmt / displayTotal) * 100)))% מההוצאות" : "\(Int(round((houseAmt / displayTotal) * 100)))% of spending",
                        houseAmt)
            case "savings":
                return (Color(red: 234/255, green: 248/255, blue: 240/255),
                        l10n.language == .hebrew ? "שמורת הטבע" : "Savings Sanctuary",
                        l10n.language == .hebrew ? "יעדי חיסכון והשקעות" : "Savings & Investments",
                        savingsAmt)
            default:
                return (Color(red: 243/255, green: 244/255, blue: 246/255),
                        l10n.language == .hebrew ? "כל העיר" : "All City",
                        l10n.language == .hebrew ? "לחץ להצגת פירוט רבעים" : "Tap for district breakdown",
                        currentCity.totalSpent)
            }
        }()

        return VStack(spacing: 8) {
            // Header Row: Floating District Row (Reference Screen 1)
            Button(action: {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    isDetailsExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    // 42pt circular pastel badge
                    ZStack {
                        Circle()
                            .fill(badgeBg)
                            .frame(width: 42, height: 42)

                        if selectedDistrict == "shopping" {
                            DistrictBoutiqueVectorIcon(color: Color(red: 236/255, green: 72/255, blue: 153/255))
                                .scaleEffect(0.85)
                        } else if selectedDistrict == "housing" {
                            DistrictHousingVectorIcon(color: Color(red: 59/255, green: 130/255, blue: 246/255))
                                .scaleEffect(0.85)
                        } else if selectedDistrict == "savings" {
                            DistrictParkVectorIcon(color: Color(red: 16/255, green: 185/255, blue: 129/255))
                                .scaleEffect(0.85)
                        } else if selectedDistrict == "food" {
                            DistrictBistroVectorIcon(color: Color(red: 249/255, green: 115/255, blue: 22/255))
                                .scaleEffect(0.85)
                        } else {
                            DistrictSkylineVectorIcon(color: Color(red: 17/255, green: 24/255, blue: 39/255))
                                .scaleEffect(0.85)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)

                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(Color.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Text(l10n.format(amount: amount))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)

                        MoneyIcon(isDetailsExpanded ? .chevronDown : (l10n.language == .hebrew ? .chevronLeft : .chevronRight), size: 12)
                    }
                }
            }
            .buttonStyle(.plain)

            // Contextual Month Milestone
            if displayTransactions.isEmpty {
                HStack(spacing: 6) {
                    MoneyIcon(.leaf, size: 14)
                    Text(l10n.language == .hebrew ? "עיר חדשה מתחילה לצמוח" : "A new city is growing")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.top, 1)
            } else if displayTransactions.count == 1 {
                HStack(spacing: 6) {
                    MoneyIcon(.home, size: 14)
                    Text(l10n.language == .hebrew ? "המבנה הראשון שלך לחודש זה" : "Your first building of the month")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.top, 1)
            }
            

            
            // District Details (Expanded only on tap!)
            if isDetailsExpanded {
                Divider().background(Color.borderSubtle)
                
                let foodAmt = (currentCity.categoryTotals[.food] ?? 0) + (currentCity.categoryTotals[.groceries] ?? 0)
                let shopAmt = currentCity.categoryTotals[.shopping] ?? 0
                let houseAmt = currentCity.categoryTotals[.housing] ?? 0
                let savingsAmt = currentCity.totalSavings
                let displayTotal = max(currentCity.totalSpent, 1.0)
                
                if currentCity.totalSpent <= 0 && savingsAmt <= 0 {
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
                            bgColor: Color(red: 254/255, green: 242/255, blue: 232/255),
                            title: l10n.language == .hebrew ? "רובע האוכל" : "Food District",
                            amount: foodAmt,
                            percentage: Int(round((foodAmt / displayTotal) * 100)),
                            icon: { MoneyIcon(.cutlery, size: 22) }
                        ) {
                            handleSelectDistrict("food")
                        }
                        
                        Divider().background(Color.borderSubtle)
                        
                        districtRow(
                            bgColor: Color(red: 253/255, green: 238/255, blue: 244/255),
                            title: l10n.language == .hebrew ? "שדרת הקניות" : "Shopping Street",
                            amount: shopAmt,
                            percentage: Int(round((shopAmt / displayTotal) * 100)),
                            icon: { MoneyIcon(.shoppingBag, size: 22) }
                        ) {
                            handleSelectDistrict("shopping")
                        }
                        
                        Divider().background(Color.borderSubtle)
                        
                        districtRow(
                            bgColor: Color(red: 238/255, green: 245/255, blue: 254/255),
                            title: l10n.language == .hebrew ? "מתחם המגורים" : "Housing Quarter",
                            amount: houseAmt,
                            percentage: Int(round((houseAmt / displayTotal) * 100)),
                            icon: { MoneyIcon(.home, size: 22) }
                        ) {
                            handleSelectDistrict("housing")
                        }

                        Divider().background(Color.borderSubtle)

                        districtRow(
                            bgColor: Color(red: 234/255, green: 248/255, blue: 240/255),
                            title: l10n.language == .hebrew ? "שמורת הטבע (חיסכון)" : "Savings Sanctuary",
                            amount: savingsAmt,
                            percentage: Int(round((savingsAmt / displayTotal) * 100)),
                            icon: { MoneyIcon(.leaf, size: 22) }
                        ) {
                            handleSelectDistrict("savings")
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.045), radius: 14, x: 0, y: 3)
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
                // Soft pastel circle badge (matches reference)
                ZStack {
                    Circle()
                        .fill(bgColor)
                        .frame(width: 34, height: 34)
                    
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
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
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
        formatter.locale = Locale(identifier: l10n.language == .hebrew ? "he_IL" : "en_US")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: currentDate)
    }

    /// The city can be shown for any month — the engine has always supported it — but nothing
    /// on screen said which month was being shown, and there was no way back. Somebody sent to
    /// a past month would have been stranded there with a screen that looked exactly like the
    /// one they use every day.
    /// True while looking back at a month. Everything the everyday screen offers is hidden.
    private var isSnapshotMode: Bool { monthSnapshot != nil }

    /// Chrome is hidden by the full-map toggle and by the month view alike.
    private var isChromeHidden: Bool { isZenMode || isSnapshotMode }

    private func openMonthSnapshot(_ month: Date) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            monthSnapshot = month
            currentDate = month
            selectedDistrict = nil
            inspectedBuilding = nil
            activeTab = "city"
        }
        cityViewResetToken &+= 1
    }

    private func closeMonthSnapshot() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            monthSnapshot = nil
            currentDate = Date()
            selectedDistrict = nil
            inspectedBuilding = nil
            // Back to where they came from, not to the city — they were reading their history.
            activeTab = "profile"
        }
        cityViewResetToken &+= 1
    }

    private var isViewingPastMonth: Bool {
        !Calendar.current.isDate(currentDate, equalTo: Date(), toGranularity: .month)
    }

    private func returnToCurrentMonth() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentDate = Date()
            selectedDistrict = nil
            inspectedBuilding = nil
        }
        cityViewResetToken &+= 1
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
                case "health_pharmacy":
                    return tx.category == .health || tx.buildingId == "health_pharmacy"
                case "finance_bank":
                    return tx.category == .finance || tx.buildingId == "finance_bank"
                case "museum_curiosities":
                    return tx.category == .miscellaneous || tx.category == .misc || tx.buildingId == "museum_curiosities"
                case "savings_sanctuary":
                    return tx.category == .savings
                case "trans_station":
                    return tx.category == .transport
                case "city_sorting_hub":
                    return tx.category == .other || tx.buildingId == "city_sorting_hub"
                default:
                    return tx.buildingId == building.id
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

struct DistrictDeepDiveCard: View {
    let districtId: String
    let onBack: () -> Void
    let onSelectBuilding: (DistrictBuildingInfo) -> Void
    let pills: [BuildingPillItem]
    let total: Double
    @EnvironmentObject private var l10n: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── Header: district name + total + back ──
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(districtTitle)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    Text(l10n.format(amount: total))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.primaryBlue)
                }

                Spacer()

                Button(action: onBack) {
                    HStack(spacing: 5) {
                        MoneyIcon(.citySkyline, size: 13)
                        Text(l10n.language == .hebrew ? "חזרה" : "Back")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(red: 17/255, green: 24/255, blue: 39/255))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .bouncyPress(scale: 0.94)
            }

            // ── Building rows: tap → open building card ──
            VStack(spacing: 0) {
                ForEach(pills) { pill in
                    Button(action: { onSelectBuilding(pill.info) }) {
                        HStack(spacing: 12) {
                            buildingVectorIcon(pill.id, size: 16)
                                .frame(width: 28, height: 28)
                                .background(Color(red: 248/255, green: 250/255, blue: 252/255))
                                .clipShape(Circle())

                            Text(pill.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.deepNavy)

                            Spacer()

                            if pill.amount > 0 {
                                Text(l10n.format(amount: pill.amount))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.textSecondary)
                            }

                            MoneyIcon(.chevronRight, size: 11)
                                .foregroundColor(Color.textMuted)
                        }
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)

                    if pill.id != pills.last?.id {
                        Divider().opacity(0.5)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 14, y: 4)
        .padding(.horizontal, 16)
    }

    private var districtTitle: String {
        let isHebrew = l10n.language == .hebrew
        switch districtId {
        case "food":     return isHebrew ? "רובע האוכל" : "Food District"
        case "shopping": return isHebrew ? "שדרת הקניות" : "Shopping District"
        case "housing":  return isHebrew ? "מתחם המגורים" : "Housing District"
        case "savings":  return isHebrew ? "שמורת הטבע" : "Savings Sanctuary"
        case "transport": return isHebrew ? "מרכז התחבורה" : "Transport Hub"
        default:         return isHebrew ? "רובע בעיר" : "City District"
        }
    }
}

@ViewBuilder
public func buildingVectorIcon(_ id: String, size: CGFloat = 18) -> some View {
    switch id {
    case "food_bistro": MoneyIcon(.cutlery, size: size)
    case "food_super": MoneyIcon(.cart, size: size)
    case "food_coffee": MoneyIcon(.coffee, size: size)
    case "food_wolt": MoneyIcon(.car, size: size)
    case "shop_boutique": MoneyIcon(.shoppingBag, size: size)
    case "shop_tech": MoneyIcon(.gamepad, size: size)
    case "shop_travel": MoneyIcon(.airplane, size: size)
    case "shop_arcade": MoneyIcon(.gamepad, size: size)
    case "house_tower": MoneyIcon(.home, size: size)
    case "house_util": MoneyIcon(.lightning, size: size)
    case "house_subs": MoneyIcon(.refresh, size: size)
    case "savings_sanctuary": MoneyIcon(.leaf, size: size)
    case "city_sorting_hub": MoneyIcon(.mail, size: size)
    case "museum_curiosities": MoneyIcon(.gift, size: size)
    case "trans_station": MoneyIcon(.car, size: size)
    case "health_pharmacy": MoneyIcon(.medicalCross, size: size)
    case "finance_bank": MoneyIcon(.creditCard, size: size)
    default: MoneyIcon(.home, size: size)
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
        case "food_bistro": return isHe ? "מסעדות" : "Restaurants"
        case "food_super": return isHe ? "סופר ומכולת" : "Supermarket & Groceries"
        case "food_coffee": return isHe ? "בתי קפה" : "Cafes"
        case "food_wolt": return isHe ? "משלוחי אוכל" : "Food Delivery"
        case "shop_boutique": return isHe ? "ביגוד ואופנה" : "Fashion & Boutique"
        case "shop_tech": return isHe ? "טכנולוגיה וחשמל" : "Electronics & Tech"
        case "shop_travel": return isHe ? "חופשות וטיסות" : "Travel & Vacations"
        case "shop_arcade": return isHe ? "קולנוע ובידור" : "Entertainment"
        case "house_tower": return isHe ? "שכירות ודיור" : "Rent & Housing"
        case "house_util": return isHe ? "חשבונות הבית" : "Utilities & Bills"
        case "house_subs": return isHe ? "מנויים וסטרימינג" : "Subscriptions & Streaming"
        case "savings_sanctuary": return isHe ? "שמורת הטבע והחיסכון" : "Nature & Savings Park"
        case "trans_station": return isHe ? "תחבורה וחניה" : "Transit & Parking"
        case "health_pharmacy": return isHe ? "פארם ובריאות" : "Health & Pharmacy"
        case "finance_bank": return isHe ? "בנקאות ועמלות" : "Banking & Finance"
        case "museum_curiosities": return isHe ? "מוזיאון הדברים המשונים" : "Museum of Curiosities"
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
                    MoneyIcon(.shoppingBag, size: 14)
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
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 4)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            onShowFeed()
        }
    }
    
    private var headerRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isSortingHub ? Color(red: 254/255, green: 243/255, blue: 199/255) : Color(red: 241/255, green: 245/255, blue: 249/255))
                    .frame(width: 44, height: 44)
                if isSortingHub {
                    MoneyIcon(.mail, size: 24)
                } else {
                    buildingVectorIcon(info.id, size: 24)
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
                            MoneyIcon(.checkCircle, size: 14)
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
                MoneyIcon(.xmarkCircle, size: 20)
                    .frame(width: 32, height: 32)
                    .background(Color.appBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .highPriorityGesture(TapGesture().onEnded { onClose() })
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

    private var sanctuaryNoteRow: some View {
        HStack(spacing: 8) {
            MoneyIcon(.leaf, size: 14)
            Text(isHebrew
                 ? "שמורת הטבע והחיסכון צומחת עם כל שקל שנשמר או הופקד ליעד. לחץ על התפריט המיוחד לניהול יעדים והפקדות."
                 : "The Nature Sanctuary grows with every shekel saved or deposited into goals. Tap below to manage goals.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            figuresRow
            sanctuaryNoteRow

            Divider().background(Color(red: 243/255, green: 244/255, blue: 246/255))
            footerRow
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 4)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            onShowFeed()
        }
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.themeMintSoft)
                    .frame(width: 44, height: 44)
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
                MoneyIcon(.xmarkCircle, size: 20)
                    .frame(width: 32, height: 32)
                    .background(Color.appBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .highPriorityGesture(TapGesture().onEnded { onClose() })
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
                    MoneyIcon(.leaf, size: 14)
                    Text(isHebrew ? "תפריט השמורה ויעדים" : "Sanctuary & Goals")
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
