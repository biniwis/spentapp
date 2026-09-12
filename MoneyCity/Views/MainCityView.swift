import SwiftUI
import SwiftData
import Combine

/// The main edge-to-edge view showcasing the real-time 3D living diorama with Multi-Building Neighborhood Deep-Dive and Spatial Inspection.
public struct MainCityView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Transaction.timestamp, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \CityEnrichment.unlockedDate, order: .reverse) private var allEnrichments: [CityEnrichment]
    
    @AppStorage("monthly_budget") private var userMonthlyBudget: Double = 0
    @AppStorage("userName") private var userName = ""

    @Query private var categoryBudgets: [CategoryBudget]

    @State private var derived = CityDerivedCache()

    private var transactionsDigest: Int {
        CityTransactionDigest.make(allTransactions)
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
    @State private var quickAddPreselectedCategory: SpendingCategory? = nil
    @State private var showBudgetSheet = false
    @State private var isQuickActionActive = false
    @State private var quickActionBuilding: CityBuilding? = nil
    @State private var quickActionAmountText: String = ""
    @State private var showFeed = false
    @State private var showProgressSheet = false
    @Environment(\.scenePhase) private var companionScenePhase
    @AppStorage("cityCompanionsStartedAt") private var companionsStartedAt: Double = 0
    @State private var companionNow = Date()

    // ── Budget HUD Pace & Progress Metrics (Item 3B) ──
    private var daysRemainingInMonth: Int {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: currentDate) else { return 1 }
        let currentDay = cal.component(.day, from: currentDate)
        return max(1, range.count - currentDay + 1)
    }

    private var totalDaysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: currentDate)?.count ?? 30
    }

    private var currentDayOfMonth: Int {
        Calendar.current.component(.day, from: currentDate)
    }

    private var monthElapsedFraction: Double {
        let total = Double(totalDaysInMonth)
        guard total > 0 else { return 0 }
        return min(1.0, max(0.0, Double(currentDayOfMonth) / total))
    }

    private var budgetSpentFraction: Double {
        guard effectiveMonthlyBudget > 0 else { return 0 }
        return min(2.0, max(0.0, currentCity.totalSpent / effectiveMonthlyBudget))
    }

    private var recommendedDailyPace: Double {
        guard effectiveMonthlyBudget > 0 else { return 0 }
        let remaining = effectiveMonthlyBudget - currentCity.totalSpent
        guard remaining > 0 else { return 0 }
        return remaining / Double(daysRemainingInMonth)
    }
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
    @State private var isCameraOffset = false

    // ── Live Expense Confirmation & Rolling Amount ──
    @ObservedObject private var confirmationCoordinator = ExpenseConfirmationCoordinator.shared
    @State private var animatedSpentValue: Double? = nil
    @State private var visibleConfirmationBanner: PendingExpenseConfirmation? = nil
    @State private var showBrandSplash: Bool

    // ── In-App Pending Wallet Ingests (Missing Amount Fallback) ──
    @State private var pendingWalletItems: [PendingWalletIngest] = []
    @State private var resolvingPendingItem: PendingWalletIngest? = nil

    // ── Month Transition & City Affordance ──
    @State private var pendingRecapForNewMonth: MonthlyRecap? = nil
    @State private var activeNewMonthRecap: MonthlyRecap? = nil
    @AppStorage("hasSeenCityTapHint") private var hasSeenCityTapHint: Bool = false
    @State private var showCityTapHint: Bool = false
    @AppStorage("hasSeenRecurringPrompt") private var hasSeenRecurringPrompt: Bool = false
    @State private var showRecurringCoachmark: Bool = false
    @State private var showRecurringExpensesSheet: Bool = false
    
    public init(skipBrandSplash: Bool = false) {
        _showBrandSplash = State(initialValue: !skipBrandSplash)
    }
    
    private var displayTransactions: [Transaction] {
        currentMonthTransactions
    }

    /// The lesson points at a place the user actually built, preferring the venue with the
    /// largest amount so the highlighted object is visually easy to find.
    private var cityTutorialBuildingId: String? {
        guard canPresentCityLesson, showCityTapHint, !hasSeenCityTapHint, inspectedBuilding == nil,
              selectedDistrict == nil, !displayTransactions.isEmpty else { return nil }
        let supported = Set([
            "food_bistro", "food_super", "food_coffee", "food_wolt",
            "shop_boutique", "shop_tech", "shop_travel", "shop_arcade",
            "house_tower", "house_util", "house_subs", "trans_station",
            "health_pharmacy", "finance_bank", "museum_curiosities",
            "city_sorting_hub"
        ])
        return currentCity.buildingTotals
            .filter { supported.contains($0.key) && $0.value > 0 }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.first?.key
    }

    private var canPresentCityLesson: Bool {
        hasCompletedOnboarding && activeTab == "city" && !isChromeHidden
            && companionScenePhase == .active && !showBrandSplash
            && !showQuickAdd && !showFeed && !showProgressSheet
            && !showSortingHubSheet && !showReserveSanctuarySheet
            && resolvingPendingItem == nil && activeNewMonthRecap == nil
            && pendingRecapForNewMonth == nil && pendingWalletItems.isEmpty
            && visibleConfirmationBanner == nil && !showRecurringExpensesSheet
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
    private var lastCompanionRewardDate: Date? {
        allEnrichments
            .filter { CityCompanions.ids.contains($0.itemId) }
            .map(\.unlockedDate)
            .max()
    }
    private var nextCompanionDate: Date {
        CityCompanions.nextDate(firstUse: companionFirstUse, lastReward: lastCompanionRewardDate)
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
            MoneyCityTheme.appBackground.ignoresSafeArea()

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
                    selectedBuildingId: inspectedBuilding?.id,
                    tutorialBuildingId: cityTutorialBuildingId,
                    language: l10n.language == .hebrew ? "he" : "en",
                    isPaused: activeTab != "city" || companionScenePhase != .active
                        || showQuickAdd || showFeed || showProgressSheet
                        || showSortingHubSheet || showReserveSanctuarySheet,
                    onSelectDistrict: handleSelectDistrict,
                    onBuildingSelected: handleSelectBuilding,
                    onSlotTapped: nil,
                    onCameraOffsetChanged: { isOff in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isCameraOffset = isOff
                        }
                    }
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

            // Zen mode, Past Month indicators, and Unresolved Pending Banners (city only)
            if activeTab == "city" {
                VStack(spacing: 8) {
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
                                .background(MoneyCityTheme.brandSecondary)
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
                                Circle().fill(MoneyCityTheme.brandPrimary).frame(width: 7, height: 7)
                                Text(l10n.language == .hebrew ? "תצוגת מפה מלאה" : "Full Map View")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(MoneyCityTheme.textPrimary)
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
                                    DioramaExpandVectorIcon(isExpanded: true, color: MoneyCityTheme.textPrimary)
                                        .frame(width: 15, height: 15)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 16)
                        } else {
                            Spacer()
                        }
                    }

                    // In-app fallback banner for Apple Pay transactions missing an amount
                    if let pending = pendingWalletItems.first, !isZenMode {
                        HStack(spacing: 9) {
                            MoneyIcon(.creditCard, size: 16)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(l10n.language == .hebrew ? "תשלום ב-\(pending.merchant)" : "Payment at \(pending.merchant)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(MoneyCityTheme.textPrimary)
                                    .lineLimit(1)
                                Text(l10n.language == .hebrew ? "הזן סכום לעדכון העיר" : "Enter amount to update city")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }

                            Spacer(minLength: 4)

                            Button(action: {
                                resolvingPendingItem = pending
                            }) {
                                Text(l10n.language == .hebrew ? "הזן סכום ✎" : "Enter ✎")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundColor(MoneyCityTheme.jetBlack)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(MoneyCityTheme.brandPrimary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    PendingWalletStore.shared.remove(id: pending.id)
                                    pendingWalletItems.removeAll(where: { $0.id == pending.id })
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .padding(4)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.96))
                                .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
                        )
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.top, 56)
                .frame(maxHeight: .infinity, alignment: .top)
            }

            // Backdrop for quick action subcategory picker
            if isQuickActionActive && quickActionBuilding == nil {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeQuickAction()
                    }
                    .transition(.opacity)
                    .zIndex(75)
            }

            // ── Unified Floating Bottom Cards & Navigation Bar (Zero Overlap & Zero Dead Space) ──
            if !isChromeHidden {
                VStack(spacing: 8) {
                    Spacer()
                    if isCameraOffset && activeTab == "city" && selectedDistrict == nil && inspectedBuilding == nil && !isQuickActionActive {
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    cityViewResetToken &+= 1
                                    isCameraOffset = false
                                }
                            }) {
                                HStack(spacing: 6) {
                                    MoneyIcon(.navigation, size: 14, color: Color.deepNavy)
                                    Text(l10n.language == .hebrew ? "איפוס מבט" : "Recenter")
                                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.deepNavy)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.95))
                                .clipShape(Capsule())
                                .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            .bouncyPress(scale: 0.94)
                            .padding(.trailing, 16)
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                        }
                    }
                    if activeTab == "city" && !isQuickActionActive {
                        cityActiveCardView
                    }

                    // Quick Action: 3 Dynamic Subcategory Buildings floating above the plus button
                    if isQuickActionActive && quickActionBuilding == nil {
                        quickActionBuildingPickerBar
                    }

                    FloatingBottomBar(
                        activeTab: $activeTab,
                        onQuickAdd: {
                            if isQuickActionActive {
                                closeQuickAction()
                            } else {
                                quickAddPreselectedCategory = nil
                                showQuickAdd = true
                            }
                        },
                        // The city tab is the way back to the whole city. Leaving the camera
                        // inside a district meant the button appeared to do nothing whenever
                        // you were already on the city tab, and the only way out was the
                        // "back to city" button on a card that is not always on screen.
                        onTabTapped: { tab in
                            if isQuickActionActive {
                                closeQuickAction()
                            }
                            guard tab == "city" else { return }
                            handleSelectDistrict(nil)
                            // Rotation, tilt, zoom and pan all live inside city mode, so
                            // clearing the district cannot undo them. This asks the map for
                            // the opening view back — and the opening view is this month, so
                            // the tab is a way out of a past month as well as out of a
                            // district.
                            if isViewingPastMonth { currentDate = Date() }
                            cityViewResetToken &+= 1
                        },
                        onLongPressAdd: {
                            handleLongPressAdd()
                        }
                    )
                }
                .zIndex(80)
                .padding(.bottom, 6)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }

            // Big Quick Expense Overlay (Bold, Fast & Prominent on Screen)
            if isQuickActionActive, let building = quickActionBuilding {
                bigQuickAmountOverlay(for: building)
                    .zIndex(950)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.94).combined(with: .opacity),
                        removal: .scale(scale: 0.94).combined(with: .opacity)
                    ))
            }

            // ── Premium Brand Launch Splash Overlay ──
            if showBrandSplash {
                BrandSplashView(isPresented: $showBrandSplash, isHebrew: l10n.language == .hebrew)
                    .zIndex(999)
                    .transition(.opacity)
            }
        }

        .onAppear {
            if companionsStartedAt == 0 {
                let previousStart = UserDefaults.standard.object(forKey: "firstAppLaunchDate") as? Date
                companionsStartedAt = min(previousStart ?? Date(), Date()).timeIntervalSince1970
            }
            companionNow = Date()
            syncWidgetData()
            checkWeeklyEnrichmentPrompt()
            refreshPendingWalletItems()
            checkNewMonthTransition()
            checkCityTapHint()
            checkRecurringCoachmark()
            
            // Check if app was cold-launched or opened via payment notification tap
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                consumeQueuedConfirmationsIfNeeded()
            }
        }
        .onChange(of: transactionsDigest) { _, _ in
            syncWidgetData()
            checkCityTapHint()
            checkRecurringCoachmark()
        }
        .onChange(of: canPresentCityLesson) { _, canPresent in
            if canPresent {
                checkCityTapHint()
                checkRecurringCoachmark()
            }
        }
        .onChange(of: activeTab) { _, _ in
            if isQuickActionActive {
                closeQuickAction()
            }
        }
        .onReceive(confirmationCoordinator.$activeConfirmation) { newConf in
            if newConf != nil {
                consumeQueuedConfirmationsIfNeeded()
            }
        }
        .onOpenURL { url in
            let scheme = url.scheme?.lowercased() ?? ""
            let host = url.host?.lowercased() ?? ""
            let path = url.path.lowercased()
            
            if scheme == "spentapp" || scheme == "moneycity" {
                if host == "scan" || path.contains("scan" ) || host == "quick-add" || path.contains("quick-add") {
                    activeTab = "city"
                    showQuickAdd = true
                }
            }
        }
        .sheet(isPresented: $showQuickAdd, onDismiss: {
            quickAddPreselectedCategory = nil
        }) {
            QuickAddSheet(initialCategory: quickAddPreselectedCategory, initialCurrency: l10n.baseCurrency) { amount, cat, note, origAmount, origCurrency, exchangeRate, buildingId in
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
                guard DatabaseService.safeSave(modelContext) else {
                    Haptics.notify(.error)
                    return
                }

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
        .sheet(isPresented: $showBudgetSheet) {
            BudgetSheet()
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
            if phase == .active {
                companionNow = Date()
                checkWeeklyEnrichmentPrompt()
                refreshPendingWalletItems()
                checkNewMonthTransition()
                checkCityTapHint()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    consumeQueuedConfirmationsIfNeeded()
                }
                #if canImport(UserNotifications)
                CityNarrativeEngine.shared.onAppForeground()
                #endif
            }
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
        .sheet(isPresented: $showRecurringExpensesSheet) {
            RecurringExpensesSheet()
                .environmentObject(l10n)
        }
        .fullScreenCover(item: $activeNewMonthRecap) { recap in
            MonthlyRecapSheet(recap: recap) { targetDate in
                currentDate = targetDate
                activeNewMonthRecap = nil
            }
            .environmentObject(l10n)
        }
        .sheet(item: $resolvingPendingItem) { pending in
            ResolvePendingAmountSheet(
                pending: pending,
                onCommit: { amount in
                    Task {
                        _ = await WalletIngestCoordinator.run(
                            amount: amount,
                            amountText: nil,
                            merchant: pending.merchant,
                            currency: pending.currency,
                            transactionDate: pending.timestamp,
                            intentName: "InAppPendingResolution",
                            pendingID: pending.id
                        )
                        await MainActor.run {
                            PendingWalletStore.shared.remove(id: pending.id)
                            pendingWalletItems.removeAll(where: { $0.id == pending.id })
                            resolvingPendingItem = nil
                        }
                    }
                },
                onDismiss: {
                    resolvingPendingItem = nil
                }
            )
            .environmentObject(l10n)
            .presentationDetents([.fraction(0.42), .medium])
        }
    }
    
    private func refreshPendingWalletItems() {
        pendingWalletItems = PendingWalletStore.shared.getAll()
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
            isHebrew: l10n.language == .hebrew,
            currencySymbol: l10n.baseCurrency.symbol
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

    /// Consumes all queued payment confirmations from disk and displays an aggregated roll animation.
    private func consumeQueuedConfirmationsIfNeeded() {
        let list = confirmationCoordinator.consumeAllPendingConfirmations()
        guard !list.isEmpty else { return }

        let totalAmount = list.reduce(0.0) { $0 + $1.amount }
        if let last = list.last {
            let aggregateConf = PendingExpenseConfirmation(
                id: last.id,
                amount: totalAmount,
                merchant: list.count > 1 ? "\(last.merchant) ועוד \(list.count - 1)" : last.merchant,
                timestamp: last.timestamp,
                isRefund: last.isRefund
            )
            triggerExpenseRollConfirmation(aggregateConf)
        }
    }
    
    private func checkWeeklyEnrichmentPrompt() {
        guard hasCompletedOnboarding, !isSnapshotMode, !showProgressSheet else { return }
        guard !weeklyRewardOptions.isEmpty else { return }
        
        let currentWeek = currentCalendarWeekKey
        let lastPromptWeek = UserDefaults.standard.string(forKey: "lastAdditionsPromptWeekKey")
        
        // Trigger only once per calendar week
        guard lastPromptWeek != currentWeek else { return }
        
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                guard !weeklyRewardOptions.isEmpty, !isSnapshotMode else { return }
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
    
    /// Everything the reserve's card needs, taken from the authoritative ReserveStateService,
    /// so the card and the land can never disagree.
    private var reserveSnapshot: ReserveSnapshot {
        let budget = effectiveMonthlyBudget
        let spent = currentCity.totalSpent
        let elapsed = CitySimulationEngine.budgetAccruedFraction(for: currentDate, now: Date())
        return ReserveStateService.computeSnapshot(
            monthlyBudget: budget,
            monthlySpent: spent,
            monthProgressRatio: elapsed
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
            visitCount: DistrictDataHelper.buildingVisitCount(for: building.id, transactions: displayTransactions),
            trendText: DistrictDataHelper.buildingTrendText(for: building.id, transactions: displayTransactions, language: l10n.language)
        )
        // Selecting a different building only changed the numbers inside a card that was
        // already on screen, so SwiftUI reused the same view: no transition ran, nothing moved,
        // and the tap felt like it had missed. The `.id` on the card below makes a swap a real
        // insertion so it animates, and the feedback here distinguishes the two cases —
        // opening a card from nothing, and exchanging one for another.
        if !hasSeenCityTapHint {
            hasSeenCityTapHint = true
            withAnimation(.easeOut(duration: 0.2)) { showCityTapHint = false }
            checkRecurringCoachmark()
        }

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

    private func dismissNewMonthBanner() {
        let status = MonthlyRecapService.checkRecapWindow()
        let ackId = status.isActive ? status.monthId : MonthlyRecapService.monthId(for: Date())
        UserDefaults.standard.set(ackId, forKey: "last_acknowledged_month")
        withAnimation(.easeOut(duration: 0.25)) {
            pendingRecapForNewMonth = nil
        }
    }

    private func checkNewMonthTransition() {
        guard hasCompletedOnboarding, !isSnapshotMode else { return }
        let status = MonthlyRecapService.checkRecapWindow()
        guard status.isActive, let targetMonthDate = status.targetMonthDate else {
            if pendingRecapForNewMonth != nil {
                pendingRecapForNewMonth = nil
            }
            return
        }

        let lastAck = UserDefaults.standard.string(forKey: "last_acknowledged_month")
        if let lastAck = lastAck {
            if lastAck != status.monthId {
                let recap = MonthlyRecapService.generateRecap(
                    for: targetMonthDate,
                    allTransactions: allTransactions,
                    monthlyBudget: effectiveMonthlyBudget
                )
                if recap.transactionCount > 0 {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        pendingRecapForNewMonth = recap
                    }
                } else {
                    UserDefaults.standard.set(status.monthId, forKey: "last_acknowledged_month")
                }
            }
        } else {
            UserDefaults.standard.set(status.monthId, forKey: "last_acknowledged_month")
        }
    }

    private func checkCityTapHint() {
        guard canPresentCityLesson, !hasSeenCityTapHint, !isSnapshotMode,
              !displayTransactions.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            guard canPresentCityLesson, !isSnapshotMode, !hasSeenCityTapHint, !displayTransactions.isEmpty,
                  !showQuickAdd, activeTab == "city",
                  inspectedBuilding == nil, selectedDistrict == nil else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.8)) {
                showCityTapHint = true
            }
        }
    }

    private var cityTapCoachmark: some View {
        CityTapCoachmark {
            hasSeenCityTapHint = true
            withAnimation(.easeOut(duration: 0.2)) { showCityTapHint = false }
            checkRecurringCoachmark()
        }
    }

    private func checkRecurringCoachmark() {
        guard canPresentCityLesson, hasSeenCityTapHint, !hasSeenRecurringPrompt,
              !isSnapshotMode, showCityTapHint == false, !showRecurringExpensesSheet else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard canPresentCityLesson, hasSeenCityTapHint, !hasSeenRecurringPrompt,
                  !isSnapshotMode, !showQuickAdd, activeTab == "city",
                  inspectedBuilding == nil, selectedDistrict == nil, !showRecurringExpensesSheet else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.8)) {
                showRecurringCoachmark = true
            }
        }
    }

    private var recurringExpensesCoachmark: some View {
        RecurringExpensesCoachmark(
            onAddRecurring: {
                hasSeenRecurringPrompt = true
                withAnimation(.easeOut(duration: 0.2)) { showRecurringCoachmark = false }
                showRecurringExpensesSheet = true
            },
            onDismiss: {
                hasSeenRecurringPrompt = true
                withAnimation(.easeOut(duration: 0.2)) { showRecurringCoachmark = false }
            }
        )
    }

    private var firstTransactionCard: some View {
        FirstTransactionCard(
            isViewingPastMonth: isViewingPastMonth,
            onReturnToCurrentMonth: returnToCurrentMonth,
            onAddExpense: { showQuickAdd = true }
        )
    }

    @ViewBuilder
    private var topControlsHeader: some View {
        if !isChromeHidden {
            VStack(spacing: 10) {
                CityTopBarView(
                    hasWeeklyReward: !weeklyRewardOptions.isEmpty,
                    isZenMode: $isZenMode,
                    onOpenCompanions: {
                        companionNow = Date()
                        showProgressSheet = true
                    }
                )
                if let recap = pendingRecapForNewMonth {
                    CityNewMonthRecapBanner(
                        recap: recap,
                        onOpen: {
                            activeNewMonthRecap = recap
                            dismissNewMonthBanner()
                        },
                        onDismiss: dismissNewMonthBanner
                    )
                }
                CityHeroKpiRow(spentValue: animatedSpentValue ?? currentCity.totalSpent)
                confirmationBannerView
                districtSelectorRow
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Dynamic Top Buildings (Subcategories) for Fast Action
    private var dynamicTopBuildings: [CityBuilding] {
        CityQuickActionHelper.dynamicTopBuildings(from: allTransactions)
    }

    private func handleLongPressAdd() {
        quickActionAmountText = ""
        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
            quickActionBuilding = nil
            isQuickActionActive = true
        }
    }

    private func closeQuickAction() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
            isQuickActionActive = false
            quickActionBuilding = nil
            quickActionAmountText = ""
        }
    }

    private func submitQuickAction() {
        guard let building = quickActionBuilding,
              let amt = Double(quickActionAmountText.replacingOccurrences(of: ",", with: ".")),
              amt > 0 else {
            Haptics.notify(.warning)
            return
        }

        let tx = Transaction(
            amount: amt,
            currency: l10n.baseCurrency.symbol,
            merchant: building.displayName(for: l10n.language),
            category: building.category,
            timestamp: Date(),
            confidenceScore: 1.0,
            isManual: true,
            isConfirmed: true,
            note: nil,
            buildingId: building.id,
            originalAmount: nil,
            originalCurrency: nil,
            exchangeRate: nil
        )
        modelContext.insert(tx)
        try? modelContext.save()

        ExpenseConfirmationCoordinator.shared.triggerConfirmation(
            amount: amt,
            merchant: building.displayName(for: l10n.language),
            isRefund: false
        )
        Haptics.notify(.success)

        withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
            isQuickActionActive = false
            quickActionBuilding = nil
            quickActionAmountText = ""
        }
    }

    // MARK: - 3 Mini Subcategory Pills (Phase 1)
    @ViewBuilder
    private var quickActionBuildingPickerBar: some View {
        QuickActionBuildingPickerBar(
            buildings: dynamicTopBuildings,
            onSelect: { building in
                withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                    quickActionBuilding = building
                    quickActionAmountText = ""
                }
            }
        )
    }

    // MARK: - Big Quick Amount Overlay (Phase 2 - Clean Editorial Fast Entry)
    @ViewBuilder
    private func bigQuickAmountOverlay(for building: CityBuilding) -> some View {
        BigQuickAmountOverlay(
            building: building,
            amountText: $quickActionAmountText,
            onClose: closeQuickAction,
            onSubmit: submitQuickAction
        )
    }

    // MARK: - Active City Card Modular View
    @ViewBuilder
    private var cityActiveCardView: some View {
        if let b = inspectedBuilding, b.id == "savings_sanctuary" {
            ReserveModalView(
                snapshot: reserveSnapshot,
                onClose: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        inspectedBuilding = nil
                    }
                },
                onOpenBudgetSetup: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        inspectedBuilding = nil
                        showBudgetSheet = true
                    }
                }
            )
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
            if cityTutorialBuildingId != nil {
                cityTapCoachmark
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else if showRecurringCoachmark && !hasSeenRecurringPrompt {
                recurringExpensesCoachmark
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else if displayTransactions.isEmpty && !isSnapshotMode {
                firstTransactionCard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                spendingCard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var confirmationBannerView: some View {
        CityConfirmationBanner(banner: visibleConfirmationBanner)
    }
    
    private var districtSelectorRow: some View {
        CityDistrictSelector(
            selectedDistrict: selectedDistrict,
            onSelectDistrict: handleSelectDistrict
        )
    }
    
    private func districtName(for dist: String) -> String {
        DistrictDataHelper.districtName(for: dist, language: l10n.language)
    }
    
    private func districtTotal(for dist: String) -> Double {
        DistrictDataHelper.districtTotal(for: dist, currentCity: currentCity)
    }
    
    private func districtBuildingPills(for dist: String) -> [BuildingPillItem] {
        DistrictDataHelper.districtBuildingPills(
            for: dist,
            currentCity: currentCity,
            transactions: displayTransactions,
            language: l10n.language
        )
    }

    private var spendingCard: some View {
        CitySpendingCard(
            currentCity: currentCity,
            selectedDistrict: selectedDistrict,
            isDetailsExpanded: $isDetailsExpanded,
            displayTransactions: displayTransactions,
            onSelectDistrict: handleSelectDistrict
        )
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

#Preview {
    MainCityView()
        .preferredColorScheme(.light)
        .modelContainer(for: Transaction.self, inMemory: true)
}
