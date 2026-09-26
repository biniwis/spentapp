import SwiftUI
import SwiftData

// MARK: - Analytics View

public struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager
    @Query(sort: \Transaction.timestamp, order: .reverse) private var personalTransactions: [Transaction]
    #if !SWIFT_PACKAGE
    @ObservedObject private var scope = AppScopeContext.shared
    #endif
    private var allTransactions: [ExpenseSnapshot] {
        #if !SWIFT_PACKAGE
        let personal = scope.allExpenses(personalTransactions: personalTransactions)
        guard includeMySharedSpend, !scope.activeScope.isShared else { return personal }
        return personal + scope.mySharedExpenses(for: monthsOnScreen,
                                                 baseCurrencyCode: l10n.baseCurrency.code)
        #else
        return personalTransactions.map(ExpenseSnapshot.init)
        #endif
    }
    private var scopeCalendar: Calendar {
        #if !SWIFT_PACKAGE
        return scope.calendar
        #else
        return .current
        #endif
    }
    @Query private var categoryBudgets: [CategoryBudget]
    @AppStorage("monthly_budget") private var userMonthlyBudget: Double = 0

    /// Asks the screen that owns the tabs to show the city for a month.
    public var onNavigateToCity: ((Date) -> Void)? = nil

    public init(onNavigateToCity: ((Date) -> Void)? = nil) {
        self.onNavigateToCity = onNavigateToCity
    }

    // Housing filter: variable spending vs fixed housing
    @AppStorage("stats_exclude_housing") private var excludeHousing: Bool = false
    // Off by default: adding shared money changes every number on this screen, so it is
    // something the user asks for rather than something that happens to them.
    @AppStorage("stats_include_my_shared") private var includeMySharedSpend: Bool = false

    private let storyVibrantPurple = Color.spentGreen
    private let storySoftLilac = Color.spentGreenSoft

    @State private var selectedSlice: SpendingCategory? = nil
    @State private var selectedMonthOffset: Int = 0
    @State private var activeRecap: MonthlyRecap? = nil
    @State private var animateChart = false
    @State private var showAllCategories: Bool = false
    @State private var categoryForFeed: SpendingCategory? = nil
    /// The bar that is currently highlighted in the chart — nil means "follow selectedMonthOffset"
    @State private var selectedBarOffset: Int? = nil
    @State private var isScrubbingChart: Bool = false

    /// The month range the chart is anchored to — follows arrow navigation only, never bar taps.
    private var chartAnchorDate: Date {
        let cal = scopeCalendar
        return cal.date(byAdding: .month, value: selectedMonthOffset, to: Date()) ?? Date()
    }

    /// The month whose data is shown below the chart — follows bar selection when set, else chart anchor.
    private var targetMonthDate: Date {
        let cal = scopeCalendar
        let offset = selectedBarOffset ?? selectedMonthOffset
        return cal.date(byAdding: .month, value: offset, to: Date()) ?? Date()
    }

    /// Every month the screen shows or compares at once: the six chart months, plus the
    /// month before the one on screen. Asked of the shared ledger in one go, so a month
    /// that shows up in two places is one answer rather than two.
    private var monthsOnScreen: [Date] {
        let cal = scopeCalendar
        var months = (0..<6).map { cal.date(byAdding: .month, value: -$0, to: chartAnchorDate) ?? chartAnchorDate }
        let prev = cal.date(byAdding: .month, value: -1, to: targetMonthDate) ?? targetMonthDate
        months.append(prev)
        return months
    }

    private var isRecapWindowActiveForTargetMonth: Bool {
        #if !SWIFT_PACKAGE
        guard !scope.activeScope.isShared else { return false }
        #endif
        let status = MonthlyRecapService.checkRecapWindow()
        guard status.isActive, let activeDate = status.targetMonthDate else { return false }
        return scopeCalendar.isDate(activeDate, equalTo: targetMonthDate, toGranularity: .month)
    }

    private var monthYearString: String {
        let f = DateFormatter()
        f.calendar = scopeCalendar
        f.timeZone = scopeCalendar.timeZone
        f.locale = Locale(identifier: l10n.language == .hebrew ? "he_IL" : "en_US")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: targetMonthDate)
    }

    private var previousMonthName: String {
        let cal = scopeCalendar
        let prev = cal.date(byAdding: .month, value: -1, to: targetMonthDate) ?? targetMonthDate
        let f = DateFormatter()
        f.calendar = scopeCalendar
        f.timeZone = scopeCalendar.timeZone
        f.locale = Locale(identifier: l10n.language == .hebrew ? "he_IL" : "en_US")
        f.dateFormat = "LLLL"
        return f.string(from: prev)
    }

    /// Earliest recorded transaction date across all data
    private var earliestRecordedDate: Date? {
        allTransactions.map(\.timestamp).min()
    }

    /// Whether the user actually has recorded history for the month prior to targetMonthDate
    private var hasPreviousMonthHistory: Bool {
        guard let earliest = earliestRecordedDate else { return false }
        let cal = scopeCalendar
        let prevMonth = cal.date(byAdding: .month, value: -1, to: targetMonthDate) ?? targetMonthDate
        guard let endOfPrevMonth = cal.dateInterval(of: .month, for: prevMonth)?.end else { return false }
        return earliest < endOfPrevMonth
    }

    /// Transactions for the currently selected month
    private var displayTransactions: [ExpenseSnapshot] {
        let cal = scopeCalendar
        return allTransactions.filter {
            cal.isDate($0.timestamp, equalTo: targetMonthDate, toGranularity: .month)
        }
    }

    /// Previous month transactions for trend comparison
    private var previousMonthTransactions: [ExpenseSnapshot] {
        let cal = scopeCalendar
        let prev = cal.date(byAdding: .month, value: -1, to: targetMonthDate) ?? targetMonthDate
        return allTransactions.filter {
            cal.isDate($0.timestamp, equalTo: prev, toGranularity: .month)
        }
    }

    private func countsTowardStats(_ tx: ExpenseSnapshot) -> Bool {
        AnalyticsCategoryTotal.countsTowardStats(tx, excludeHousing: excludeHousing)
    }

    /// The spend reading the tag is about, over the month the screen is showing.
    ///
    /// Personal scope only, and only ever a reading: in a shared city the space's own
    /// analytics are the right answer, and mixing a personal toggle into them would
    /// quietly change what a partner sees. With the tag off nothing here is consulted.
    private var mySpend: MyTotalSpend {
        #if !SWIFT_PACKAGE
        return scope.myTotalSpend(for: targetMonthDate, baseCurrencyCode: l10n.baseCurrency.code,
                                  personalTransactions: personalTransactions)
        #else
        return MyTotalSpend(personalMinor: 0, baseCurrencyCode: "ILS", spaces: [], includedExpenses: [])
        #endif
    }

    /// Whether the tag is worth a line on the screen at all.
    private var offersMySharedSpend: Bool {
        #if !SWIFT_PACKAGE
        return !scope.activeScope.isShared && mySpend.isMemberOfAnySpace
        #else
        return false
        #endif
    }

    /// What the filter is holding back, so the row can display the exact amount.
    ///
    /// Only money that was going to be counted in the first place: a housing record with no
    /// usable rate was never part of the total, so calling it hidden would overstate what
    /// the filter did.
    private var hiddenHousing: Double {
        guard excludeHousing else { return 0 }
        return AnalyticsCategoryTotal.hiddenHousingAmount(in: displayTransactions)
    }

    /// Countable housing this month, filter on or off. The row is not worth showing for
    /// housing the statistics never counted, because then it would claim to hide ₪0.
    private var housingThisMonth: Double {
        AnalyticsCategoryTotal.hiddenHousingAmount(in: displayTransactions)
    }

    private var totalSpent: Double {
        displayTransactions.filter(countsTowardStats).reduce(0) { $0 + $1.amount }
    }

    private var prevTotalSpent: Double {
        previousMonthTransactions.filter(countsTowardStats).reduce(0) { $0 + $1.amount }
    }

    /// Daily average spending for the target month
    private var dailyAverageSpent: Double {
        let cal = scopeCalendar
        let now = Date()
        let daysElapsed: Int
        if cal.isDate(targetMonthDate, equalTo: now, toGranularity: .month) {
            daysElapsed = max(cal.component(.day, from: now), 1)
        } else {
            let range = cal.range(of: .day, in: .month, for: targetMonthDate)
            daysElapsed = max(range?.count ?? 30, 1)
        }
        return totalSpent / Double(daysElapsed)
    }

    /// Transaction count contributing to this month's stats
    private var activeTransactionCount: Int {
        displayTransactions.filter(countsTowardStats).count
    }

    /// Single largest transaction this month
    private var topTransactionThisMonth: ExpenseSnapshot? {
        displayTransactions.filter(countsTowardStats).max(by: { $0.amount < $1.amount })
    }

    /// Top categories sorted by spending
    private var categoryTotals: [AnalyticsCategoryTotal] {
        AnalyticsCategoryTotal.totals(from: displayTransactions, countsTowardStats: countsTowardStats)
    }

    /// 6 comparative months for the bar chart up to chartAnchorDate
    private var chartMonths: [AnalyticsChartMonth] {
        let cal = scopeCalendar
        let isHe = l10n.language == .hebrew

        return (0..<6).reversed().map { i in
            let mDate = cal.date(byAdding: .month, value: -i, to: chartAnchorDate) ?? chartAnchorDate
            let isCurrent = (i == 0 && selectedMonthOffset == 0)
            let total = allTransactions.filter {
                cal.isDate($0.timestamp, equalTo: mDate, toGranularity: .month) && countsTowardStats($0)
            }.reduce(0) { $0 + $1.amount }

            let f = DateFormatter()
        f.calendar = scopeCalendar
        f.timeZone = scopeCalendar.timeZone
            f.locale = Locale(identifier: isHe ? "he_IL" : "en_US")
            f.dateFormat = "MMM"
            let lbl = f.string(from: mDate)
            return AnalyticsChartMonth(monthDate: mDate, label: lbl, amount: total, isCurrent: isCurrent, offset: selectedMonthOffset - i)
        }
    }

    /// Average spending across the active months displayed in the chart
    private var averageChartSpending: Double {
        let active = chartMonths.filter { $0.amount > 0 }
        guard !active.isEmpty else { return 0 }
        let total = active.map(\.amount).reduce(0, +)
        return total / Double(active.count)
    }

    /// Crystal-clear comparison descriptor
    private var comparisonInfo: (text: String, isIncrease: Bool?, color: Color, bgColor: Color)? {
        let isHe = l10n.language == .hebrew

        // If user wasn't in the app before this month, don't show an artificial difference vs zero
        guard hasPreviousMonthHistory else {
            return (isHe ? "חודש ראשון לדיווח באפליקציה\u{00A0}🎉" : "First month tracking in SPENT\u{00A0}🎉", nil, MoneyCityTheme.brandPrimary, MoneyCityTheme.surfaceSoft)
        }

        let diff = totalSpent - prevTotalSpent
        if abs(diff) < 1 {
            return (isHe ? "ללא שינוי מ\(previousMonthName)" : "No change from \(previousMonthName)", nil, MoneyCityTheme.textSecondary, MoneyCityTheme.jetBlack.opacity(0.04))
        }

        let formattedDiff = l10n.formatScoped(amount: abs(diff).rounded())
        if diff > 0 {
            let txt = isHe ? "↑ \(formattedDiff) יותר מ\(previousMonthName)" : "↑ \(formattedDiff) more than \(previousMonthName)"
            return (txt, true, MoneyCityTheme.brandSecondary, MoneyCityTheme.surfaceSoft)
        } else {
            let txt = isHe ? "↓ \(formattedDiff) פחות מ\(previousMonthName)" : "↓ \(formattedDiff) less than \(previousMonthName)"
            return (txt, false, MoneyCityTheme.brandSecondary, MoneyCityTheme.surfaceSoft)
        }
    }

    // MARK: - Shared Scope

    #if !SWIFT_PACKAGE
    /// The active space's month for the month on screen, or `nil` in personal scope.
    ///
    /// Read for the month being *viewed*, not for today: the stepper walks back, and a
    /// target read for the current month would sit above last month's spending. The date
    /// picks the month in the space's own calendar; the arithmetic stays in the one engine.
    private var sharedMonthSummary: SharedMonthlySummary? {
        scope.sharedMonthSummary(for: targetMonthDate)
    }
    #endif

    private var sharedCurrency: String {
        #if !SWIFT_PACKAGE
        return scope.sharedCurrencyCode ?? "ILS"
        #else
        return "ILS"
        #endif
    }

    private func sharedAmountText(_ minor: Int64) -> String {
        l10n.formatScopedMinor(minor, currency: sharedCurrency)
    }

    /// Whether shares of the month can be drawn at all.
    ///
    /// A refund can push a category, or the month itself, below zero. A percentage of a
    /// total that is not positive is not a share of anything, and dividing by
    /// `max(total, 1)` used to turn such a month into confident negative percentages. The
    /// amounts are real and stay; only the percentage and its bar go.
    private var canShowCategoryShares: Bool {
        guard totalSpent > 0 else { return false }
        return !categoryTotals.contains { $0.amount < 0 }
    }

    /// Where the space stands against the target it set for itself.
    ///
    /// Every number is read from `SharedMonthlySummary`, the same source the profile
    /// reports, so the two screens cannot disagree about the same month. The month's
    /// headline amount is deliberately not repeated: the hero above already states it, and
    /// printing it twice is two chances to show two different numbers.
    private var sharedTargetSection: some View {
        Group {
            #if !SWIFT_PACKAGE
            if let summary = sharedMonthSummary {
                let progress = summary.progress
                VStack(alignment: .leading, spacing: 9) {
                    if progress.hasTarget, let target = progress.targetMinor {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(l10n.language == .hebrew ? "מתוך יעד של" : "Out of a target of")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.textSecondary)
                            Text(sharedAmountText(target))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                        }

                        if progress.isOverTarget {
                            Text(l10n.language == .hebrew
                                 ? "מעל היעד ב־\(sharedAmountText(-(progress.remainingMinor ?? 0)))"
                                 : "\(sharedAmountText(-(progress.remainingMinor ?? 0))) over target")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color.orange)
                        } else {
                            Text(l10n.language == .hebrew
                                 ? "נותרו \(sharedAmountText(progress.remainingMinor ?? 0)) החודש"
                                 : "\(sharedAmountText(progress.remainingMinor ?? 0)) left this month")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color.spentGreen)
                        }
                    } else {
                        // No target, so no bar and no comparison. A space that never set one
                        // is not a space that is somehow at zero.
                        Text(l10n.language == .hebrew
                             ? "לא הוגדר יעד חודשי למרחב, ולכן אין עם מה להשוות"
                             : "No monthly target for this space, so there is nothing to compare against")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // The bar clamps; the fraction behind it stays uncapped, because 118%
                    // spent is information the reader is owed.
                    if let fraction = progress.fraction {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(red: 243/255, green: 244/255, blue: 246/255))
                                Capsule()
                                    .fill(progress.isOverTarget ? Color.orange : MoneyCityTheme.brandPrimary)
                                    .frame(width: geo.size.width * CGFloat(min(max(fraction, 0), 1)))
                            }
                        }
                        .frame(height: 6)
                    }

                    // Why the ledger's month and the category breakdown can differ. Each line
                    // names the actual cause, and only when it is the actual cause: a vague
                    // "these totals do not match" tells the reader nothing they can act on,
                    // and is usually the sign of a bug rather than a rule.
                    if excludeHousing, hiddenHousing > 0 {
                        sharedFootnote(l10n.language == .hebrew
                                       ? "הוצאות דיור בסכום \(sharedAmountText(minor(hiddenHousing))) מוסתרות מהפירוט לפי הבחירה שלך"
                                       : "\(sharedAmountText(minor(hiddenHousing))) of housing is hidden from the breakdown, by your choice")
                    }

                    if summary.savingsMinor != 0 {
                        sharedFootnote(l10n.language == .hebrew
                                       ? "חיסכון בסכום \(sharedAmountText(summary.savingsMinor)) אינו נכלל בפירוט הקטגוריות, אך נכלל ביעד"
                                       : "\(sharedAmountText(summary.savingsMinor)) of savings is not in the category breakdown, but is part of the target")
                    }

                    sharedUnresolvedNote(summary.unresolvedCount)
                }
                .padding(.horizontal, 20)
                .padding(.top, 2)
            }
            #endif
        }
    }

    /// A quiet line for money that exists in the space but cannot be counted yet. Never an
    /// error state: the record is real, the rate simply is not known.
    private func sharedUnresolvedNote(_ count: Int) -> some View {
        Group {
            #if !SWIFT_PACKAGE
            if count > 0 {
                sharedFootnote(unresolvedCountText(count))
            }
            #endif
        }
    }

    /// A small explanatory line under the target. Same weight everywhere, so a screen with
    /// two of them does not look like one of them is more important.
    private func sharedFootnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .default))
            .foregroundColor(Color.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// A major-unit amount back into the space's minor units, for the few places a rule
    /// speaks in `Double` (the screen's own statistics) and has to name an amount in the
    /// ledger's units.
    private func minor(_ majorAmount: Double) -> Int64 {
        Int64((majorAmount * pow(10, Double(SharedMoney.digits(sharedCurrency)))).rounded())
    }

    private func unresolvedCountText(_ count: Int) -> String {
        guard l10n.language == .hebrew else {
            return count == 1
                ? "1 foreign-currency record awaits a rate and is not counted"
                : "\(count) foreign-currency records await a rate and are not counted"
        }
        switch count {
        case 1: return "עסקה אחת במטבע זר ממתינה להמרה ולא נספרה"
        case 2: return "שתי עסקאות במטבע זר ממתינות להמרה ולא נספרו"
        default: return "\(count) עסקאות במטבע זר ממתינות להמרה ולא נספרו"
        }
    }

    /// Who paid the month, in the space's currency and members' own colours.
    ///
    /// Not a leaderboard: no ranking, no winner, no medals. A member who spent nothing
    /// still appears, at zero, and a refund larger than the payment shows its real
    /// negative. Shares are drawn only when `canShowMemberShares` says the month can carry
    /// them; otherwise the row is the amount and nothing else.
    private var sharedMemberSection: some View {
        Group {
            #if !SWIFT_PACKAGE
            if let summary = sharedMonthSummary,
               !summary.memberTotals.isEmpty,
               summary.transactionCount > 0 {
                VStack(alignment: .leading, spacing: 13) {
                    HStack(spacing: 7) {
                        MoneyIcon(.users, size: 15, color: MoneyCityTheme.brandPrimary)
                        Text(l10n.language == .hebrew ? "מי שילם החודש" : "Who Paid This Month")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        Spacer()
                    }

                    VStack(spacing: 12) {
                        ForEach(summary.memberTotals) { total in
                            sharedMemberRow(total, summary: summary)
                        }
                    }

                    if summary.unattributedMinor != 0 {
                        // Money that came from outside the member list stays unattributed.
                        // Splitting it evenly would invent a payer the ledger does not name.
                        HStack(spacing: 12) {
                            MoneyIcon(.user, size: 13, color: Color.textMuted)
                                .frame(width: 34, height: 34)
                            Text(l10n.language == .hebrew ? "לא משויך לחבר" : "Not attributed to a member")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Color.textSecondary)
                            Spacer(minLength: 8)
                            Text(sharedAmountText(summary.unattributedMinor))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
            }
            #endif
        }
    }

    private func sharedMemberRow(_ total: SharedMemberTotal, summary: SharedMonthlySummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                SharedMemberMark(colorHex: total.colorHex, size: 32)
                Text(total.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(sharedAmountText(total.amountMinor))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(total.amountMinor < 0 ? Color.spentGreen : Color.deepNavy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if summary.canShowMemberShares, summary.spentMinor > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(red: 243/255, green: 244/255, blue: 246/255))
                        Capsule()
                            .fill(Color(hex: total.colorHex))
                            .frame(width: max(geo.size.width * CGFloat(Double(total.amountMinor) / Double(summary.spentMinor)), 3),
                                   height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
    }

    // MARK: - Body Layout

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Sticky Header (Pinned outside ScrollView, matches HistoryView) ──
                VStack(spacing: 8) {
                    topNavigationBar
                    monthStepperRow
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Color.appBackground)

                // ── Scrollable Body ──
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        heroKpiSection

                        sharedTargetSection

                        compactBarChart
                            .padding(.horizontal, 20)

                        if activeTransactionCount > 0 {
                            monthlyPulseRow
                                .padding(.top, 4)
                        }

                        if housingThisMonth > 0 {
                            housingLineItem
                                .padding(.top, 2)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if offersMySharedSpend {
                            mySharedSpendLineItem
                                .padding(.top, 2)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        topCategoriesSection
                            .padding(.horizontal, 20)
                            .padding(.top, 4)

                        if !categoryTotals.isEmpty {
                            // A donut of a month that nets out at or below zero would be a
                            // picture of nothing. The category amounts above still stand.
                            if canShowCategoryShares {
                                categoryDonutCard
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)
                            }

                            sharedMemberSection
                        }

                        Spacer(minLength: 110)
                    }
                    .padding(.top, 6)
                }
            }
        }
        .fullScreenCover(item: $activeRecap) { recap in
            MonthlyRecapSheet(recap: recap, onNavigateToCity: onNavigateToCity)
        }
        .sheet(item: $categoryForFeed) { cat in
            let txs = displayTransactions.filter { $0.category.canonical == cat.canonical }
            TransactionFeedSheet(
                title: cat.displayName(for: l10n.language),
                expenses: txs
            )
            .environmentObject(l10n)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { animateChart = true }
        }
        #if !SWIFT_PACKAGE
        // Switching scope swaps the whole dataset underneath. Nothing here caches totals,
        // but a bar or category chosen in the previous scope would point at data that is
        // no longer on screen, so the selection state is dropped with the scope.
        .onChange(of: scope.activeScope) { _, _ in
            selectedSlice = nil
            selectedBarOffset = nil
            isScrubbingChart = false
            categoryForFeed = nil
        }
        #endif
    }

    // MARK: - Sticky Top Navigation Bar

    private var topNavigationBar: some View {
        HStack(alignment: .center) {
            Text(l10n.language == .hebrew ? "ניתוח הוצאות" : "Analytics")
                .font(.system(size: 26, weight: .bold, design: .default))
                .foregroundColor(Color.deepNavy)

            Spacer()

            // Monthly Story / Recap Button (Active only during the celebration window for this month)
            if isRecapWindowActiveForTargetMonth {
                Button(action: {
                    Haptics.impact(.medium)
                    activeRecap = MonthlyRecapService.timelineRecap(
                        for: targetMonthDate,
                        allTransactions: personalTransactions,
                        monthlyBudget: BudgetService.monthlySpendingBudget(
                            categoryBudgets: categoryBudgets,
                            overallBudget: userMonthlyBudget
                        ),
                        context: modelContext
                    )
                }) {
                    HStack(spacing: 5) {
                        MoneyIcon(.calendar, size: 14, color: Color.deepNavy)
                        Text(l10n.language == .hebrew ? "סיכום חודשי" : "Monthly Recap")
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .foregroundColor(Color.deepNavy)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
                }
            }
        }
    }

    // MARK: - Subtle Month Stepper Row

    private var monthStepperRow: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.35)) {
                    selectedMonthOffset -= 1
                    selectedSlice = nil
                }
            }) {
                MoneyIcon(
                    l10n.isHebrew ? .chevronRight : .chevronLeft,
                    size: 11,
                    color: Color.deepNavy
                )
                .frame(width: 26, height: 26)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }

            Text(monthYearString)
                .font(.system(size: 15, weight: .bold, design: .default))
                .foregroundColor(Color.deepNavy)
                .padding(.horizontal, 6)

            Button(action: {
                if selectedMonthOffset < 0 {
                    withAnimation(.spring(response: 0.35)) {
                        selectedMonthOffset += 1
                        selectedSlice = nil
                    }
                }
            }) {
                MoneyIcon(
                    l10n.isHebrew ? .chevronLeft : .chevronRight,
                    size: 11,
                    color: selectedMonthOffset >= 0 ? Color.borderSubtle : Color.deepNavy
                )
                .frame(width: 26, height: 26)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .disabled(selectedMonthOffset >= 0)

            Spacer()
        }
    }

    // MARK: - Hero KPI Section

    private var heroKpiSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(l10n.formatScoped(amount: totalSpent))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if let info = comparisonInfo {
                    Text(info.text)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(info.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(info.bgColor)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    // MARK: - Category Donut Card ("עוגה בעיגול" - בשפת כרטיסי הפרופיל עם פירוט תתי-סוגים)

    private var categoryDonutCard: some View {
        AnalyticsDonutCard(
            categoryTotals: categoryTotals,
            totalSpent: totalSpent,
            displayTransactions: displayTransactions,
            selectedSlice: $selectedSlice,
            countsTowardStats: countsTowardStats
        )
    }

    // MARK: - Top Categories Section

    private var topCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l10n.language == .hebrew ? "קטגוריות מובילות" : "Top Categories")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(Color.deepNavy)

                Spacer()

                if categoryTotals.count > 5 {
                    Button(action: {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showAllCategories.toggle()
                        }
                    }) {
                        HStack(spacing: 3) {
                            Text(showAllCategories
                                 ? (l10n.language == .hebrew ? "הצג פחות" : "Show Less")
                                 : (l10n.language == .hebrew ? "הצג הכל" : "See All"))
                                .font(.system(size: 13, weight: .semibold, design: .default))
                            MoneyIcon(showAllCategories ? .chevronUp : (l10n.isHebrew ? .chevronLeft : .chevronRight), size: 9)
                        }
                        .foregroundColor(Color.textSecondary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                }
            }

            if categoryTotals.isEmpty {
                SpentEmptyState(icon: .pieChart,
                    title: l10n.isHebrew ? "התמונה תתמלא עם ההוצאות" : "Your spending brings the picture together",
                    message: hiddenHousing > 0
                     ? (l10n.language == .hebrew
                        ? "החודש נרשם דיור בלבד, והוא מוסתר כרגע מהחישוב"
                        : "Only housing was recorded this month, and it is currently hidden")
                     : (l10n.language == .hebrew ? "כאן יופיע הפירוט לפי קטגוריות כשיירשמו הוצאות בחודש הזה." : "Your category breakdown will appear here when expenses are recorded this month."))
            } else {
                let visibleCategories = showAllCategories ? categoryTotals : Array(categoryTotals.prefix(5))
                VStack(spacing: 14) {
                    ForEach(visibleCategories, id: \.category) { item in
                        categoryRow(item.category, amount: item.amount, fraction: item.fraction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Haptics.selection()
                                categoryForFeed = item.category
                            }
                    }
                }
            }
        }
    }


    // MARK: - Compact Comparative Bar Chart

    private var compactBarChart: some View {
        AnalyticsComparativeBarChart(
            months: chartMonths,
            averageSpending: averageChartSpending,
            selectedMonthOffset: selectedMonthOffset,
            selectedBarOffset: $selectedBarOffset,
            isScrubbingChart: $isScrubbingChart,
            animateChart: animateChart,
            onSelectOffset: { _ in
                selectedSlice = nil
            }
        )
        .onChange(of: selectedMonthOffset) { _, _ in
            selectedBarOffset = nil
            selectedSlice = nil
        }
        .onChange(of: selectedBarOffset) { _, _ in
            selectedSlice = nil
        }
    }

    // MARK: - Category Row with Micro Progress Bar

    private func categoryRow(_ category: SpendingCategory, amount: Double, fraction: Double) -> some View {
        let isHighlighted = selectedSlice == category
        return HStack(spacing: 12) {
            CategoryBadge(category: category, size: 38)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(category.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .foregroundColor(Color.deepNavy)

                    Spacer()

                    HStack(spacing: 6) {
                        if canShowCategoryShares {
                            Text("\(Int(round(fraction * 100)))%")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(Color.textSecondary)
                        }

                        Text(l10n.formatScoped(amount: amount))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)

                        MoneyIcon(l10n.isHebrew ? .chevronLeft : .chevronRight, size: 8, color: Color.textMuted.opacity(0.6))
                    }
                }

                // Micro Progress Bar indicating relative spending volume
                if canShowCategoryShares {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(uiColor: .systemGray6))
                                .frame(height: 4)

                            Capsule()
                                .fill(category.themeColor)
                                .frame(width: max(geo.size.width * CGFloat(fraction), 6), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, isHighlighted ? 10 : 0)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHighlighted ? category.themeColor.opacity(0.1) : Color.clear)
        )
    }

    // MARK: - Inline Borderless Pulse Metric Strip

    private var monthlyPulseRow: some View {
        let isHe = l10n.language == .hebrew
        let dailyAvg = dailyAverageSpent
        let txCount = activeTransactionCount
        let topTx = topTransactionThisMonth
        let maxTxText = topTx.map { l10n.formatScoped(amount: $0.amount.rounded()) } ?? l10n.formatScoped(amount: 0)

        return ViewThatFits(in: .horizontal) {
            // 3-Column primary layout
            HStack(alignment: .top, spacing: 0) {
                pulseMetricItem(title: isHe ? "ממוצע ליום" : "Daily Average", value: l10n.formatScoped(amount: dailyAvg.rounded()))
                Rectangle().fill(Color.borderSubtle.opacity(0.6)).frame(width: 1, height: 26).padding(.horizontal, 10)
                pulseMetricItem(title: isHe ? "פעילות" : "Activity", value: isHe ? "\(txCount) עסקאות" : "\(txCount) txs")
                Rectangle().fill(Color.borderSubtle.opacity(0.6)).frame(width: 1, height: 26).padding(.horizontal, 10)
                pulseMetricItem(title: isHe ? "הוצאת שיא" : "Top Expense", value: maxTxText)
            }

            // 2-Row compact fallback for narrow screens (320pt) / large dynamic type
            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 0) {
                    pulseMetricItem(title: isHe ? "ממוצע ליום" : "Daily Average", value: l10n.formatScoped(amount: dailyAvg.rounded()))
                    Rectangle().fill(Color.borderSubtle.opacity(0.6)).frame(width: 1, height: 26).padding(.horizontal, 10)
                    pulseMetricItem(title: isHe ? "הוצאת שיא" : "Top Expense", value: maxTxText)
                }
                HStack {
                    pulseMetricItem(title: isHe ? "פעילות" : "Activity", value: isHe ? "\(txCount) עסקאות" : "\(txCount) txs")
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    private func pulseMetricItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .default))
                .foregroundColor(Color.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - My Shared Spend Line Item (Borderless)

    /// The same quiet line as the housing filter, saying one thing: the numbers on this
    /// screen can also count what I paid for in a space I share with someone. Off by
    /// default, and it only appears when there is such a space to speak of.
    @ViewBuilder
    private var mySharedSpendLineItem: some View {
        let isHebrew = l10n.language == .hebrew
        let myTotal = mySharedTotalThisMonth
        HStack(spacing: 12) {
            MoneyIcon(.users, size: 16, color: Color.deepNavy)
                .frame(width: 28, height: 28)
                .background(Color(uiColor: .systemGray6))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(isHebrew ? "כולל מה ששילמתי במשותף" : "Including what I paid in shared")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundColor(Color.deepNavy)

                Text(includeMySharedSpend
                     ? (isHebrew
                        ? "\(l10n.formatScoped(amount: myTotal)) מתוך הסכום הכולל"
                        : "\(l10n.formatScoped(amount: myTotal)) of the total")
                     : (isHebrew
                        ? "רק הוצאות אישיות בספירה"
                        : "Personal spending only"))
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundColor(Color.textMuted)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { includeMySharedSpend },
                set: { val in
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        includeMySharedSpend = val
                    }
                }
            ))
            .labelsHidden()
            .tint(Color.primaryBlue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    /// What the user personally paid in shared spaces, for the month on screen, in the
    /// personal currency and excluding anything the app cannot state honestly.
    private var mySharedTotalThisMonth: Double {
        Double(mySpend.sharedMinor) / pow(10, Double(SharedMoney.digits(mySpend.baseCurrencyCode)))
    }

    // MARK: - Integral Housing Line Item (Borderless)

    @ViewBuilder
    private var housingLineItem: some View {
        let isHebrew = l10n.language == .hebrew
        HStack(spacing: 12) {
            MoneyIcon(.home, size: 16, color: Color.deepNavy)
                .frame(width: 28, height: 28)
                .background(Color(uiColor: .systemGray6))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(isHebrew ? "הוצאות דיור" : "Housing Expenses")
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(Color.deepNavy)

                    Text(excludeHousing ? (isHebrew ? "מוסתר" : "Hidden") : (isHebrew ? "כלול" : "Included"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(excludeHousing ? MoneyCityTheme.brandSecondary : MoneyCityTheme.brandPrimary)
                }

                Text(excludeHousing
                     ? (isHebrew
                        ? "\(l10n.formatScoped(amount: hiddenHousing.rounded())) מוסתרים מהחישוב"
                        : "\(l10n.formatScoped(amount: hiddenHousing.rounded())) hidden from total")
                     : (isHebrew
                        ? "שכירות וחשבונות כלולים (\(l10n.formatScoped(amount: housingThisMonth.rounded())))"
                        : "Rent & utilities included (\(l10n.formatScoped(amount: housingThisMonth.rounded())))"))
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundColor(Color.textMuted)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { excludeHousing },
                set: { val in
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        excludeHousing = val
                        if excludeHousing && selectedSlice?.canonical == .housing {
                            selectedSlice = nil
                        }
                    }
                }
            ))
            .labelsHidden()
            .tint(Color.primaryBlue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }
}
