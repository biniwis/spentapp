import SwiftUI
import SwiftData

// MARK: - Donut Chart Shape & Slice Model

public struct DonutArcShape: Shape {
    public var startAngle: Double
    public var endAngle: Double

    public var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle, endAngle) }
        set {
            startAngle = newValue.first
            endAngle = newValue.second
        }
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max((min(rect.width, rect.height) - 30) / 2, 10)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )
        return path
    }
}

private struct DonutSliceData: Identifiable {
    let id: String
    let category: SpendingCategory
    let name: String
    let icon: MoneyIconType?
    let color: Color
    let amount: Double
    let fraction: Double
    let count: Int
    let startAngle: Double
    let endAngle: Double
    let rawStartAngle: Double
    let rawEndAngle: Double
}

// MARK: - Analytics View

public struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager
    @Query(sort: \Transaction.timestamp, order: .reverse) private var allTransactions: [Transaction]
    @Query private var categoryBudgets: [CategoryBudget]
    @AppStorage("monthly_budget") private var userMonthlyBudget: Double = 0

    /// Asks the screen that owns the tabs to show the city for a month.
    public var onNavigateToCity: ((Date) -> Void)? = nil

    public init(onNavigateToCity: ((Date) -> Void)? = nil) {
        self.onNavigateToCity = onNavigateToCity
    }

    // Housing filter: variable spending vs fixed housing
    @AppStorage("stats_exclude_housing") private var excludeHousing: Bool = false

    private let storyVibrantPurple = Color.spentGreen
    private let storySoftLilac = Color.spentGreenSoft

    @State private var selectedTab: String = "spending"
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
        let cal = Calendar.current
        return cal.date(byAdding: .month, value: selectedMonthOffset, to: Date()) ?? Date()
    }

    /// The month whose data is shown below the chart — follows bar selection when set, else chart anchor.
    private var targetMonthDate: Date {
        let cal = Calendar.current
        let offset = selectedBarOffset ?? selectedMonthOffset
        return cal.date(byAdding: .month, value: offset, to: Date()) ?? Date()
    }

    private var monthYearString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: l10n.language == .hebrew ? "he_IL" : "en_US")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: targetMonthDate)
    }

    private var previousMonthName: String {
        let cal = Calendar.current
        let prev = cal.date(byAdding: .month, value: -1, to: targetMonthDate) ?? targetMonthDate
        let f = DateFormatter()
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
        let cal = Calendar.current
        let prevMonth = cal.date(byAdding: .month, value: -1, to: targetMonthDate) ?? targetMonthDate
        guard let endOfPrevMonth = cal.dateInterval(of: .month, for: prevMonth)?.end else { return false }
        return earliest < endOfPrevMonth
    }

    /// Transactions for the currently selected month
    private var displayTransactions: [Transaction] {
        let cal = Calendar.current
        return allTransactions.filter {
            cal.isDate($0.timestamp, equalTo: targetMonthDate, toGranularity: .month)
        }
    }

    /// Previous month transactions for trend comparison
    private var previousMonthTransactions: [Transaction] {
        let cal = Calendar.current
        let prev = cal.date(byAdding: .month, value: -1, to: targetMonthDate) ?? targetMonthDate
        return allTransactions.filter {
            cal.isDate($0.timestamp, equalTo: prev, toGranularity: .month)
        }
    }

    private func countsTowardStats(_ tx: Transaction) -> Bool {
        if tx.category.canonical == .savings { return false }
        if excludeHousing && tx.category.canonical == .housing { return false }
        return true
    }

    /// What the filter is holding back, so the row can display the exact amount
    private var hiddenHousing: Double {
        guard excludeHousing else { return 0 }
        return displayTransactions
            .filter { $0.category.canonical == .housing }
            .reduce(0) { $0 + $1.amount }
    }

    /// Housing this month regardless of the filter — used to decide whether the row is worth showing
    private var housingThisMonth: Double {
        displayTransactions
            .filter { $0.category.canonical == .housing }
            .reduce(0) { $0 + $1.amount }
    }

    private var totalSpent: Double {
        displayTransactions.filter(countsTowardStats).reduce(0) { $0 + $1.amount }
    }

    private var prevTotalSpent: Double {
        previousMonthTransactions.filter(countsTowardStats).reduce(0) { $0 + $1.amount }
    }

    /// Daily average spending for the target month
    private var dailyAverageSpent: Double {
        let cal = Calendar.current
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
    private var topTransactionThisMonth: Transaction? {
        displayTransactions.filter(countsTowardStats).max(by: { $0.amount < $1.amount })
    }

    /// Top categories sorted by spending
    private var categoryTotals: [(category: SpendingCategory, amount: Double, fraction: Double)] {
        var totals: [SpendingCategory: Double] = [:]
        for tx in displayTransactions where countsTowardStats(tx) {
            totals[tx.category.canonical, default: 0] += tx.amount
        }
        let total = max(totals.values.reduce(0, +), 1.0)
        return totals.sorted { $0.value > $1.value }.map { (category: $0.key, amount: $0.value, fraction: $0.value / total) }
    }

    /// 6 comparative months for the bar chart up to chartAnchorDate
    private var chartMonths: [(monthDate: Date, label: String, amount: Double, isCurrent: Bool, offset: Int)] {
        let cal = Calendar.current
        let isHe = l10n.language == .hebrew

        return (0..<6).reversed().map { i in
            let mDate = cal.date(byAdding: .month, value: -i, to: chartAnchorDate) ?? chartAnchorDate
            let isCurrent = (i == 0 && selectedMonthOffset == 0)
            let total = allTransactions.filter {
                cal.isDate($0.timestamp, equalTo: mDate, toGranularity: .month) && countsTowardStats($0)
            }.reduce(0) { $0 + $1.amount }

            let f = DateFormatter()
            f.locale = Locale(identifier: isHe ? "he_IL" : "en_US")
            f.dateFormat = "MMM"
            let lbl = f.string(from: mDate)
            return (mDate, lbl, total, isCurrent, selectedMonthOffset - i)
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
        guard selectedTab == "spending" else {
            if selectedTab == "income" {
                return (isHe ? "הכנסה חודשית פעילה" : "Active monthly income", nil, Color.textSecondary, Color(uiColor: .systemGray6))
            } else {
                return (isHe ? "סך שנחסך החודש" : "Saved this month", nil, Color.textSecondary, Color(uiColor: .systemGray6))
            }
        }

        // If user wasn't in the app before this month, don't show an artificial difference vs zero
        guard hasPreviousMonthHistory else {
            return (isHe ? "חודש ראשון לדיווח באפליקציה 🎉" : "First month tracking in SPENT 🎉", nil, Color(red: 16/255, green: 185/255, blue: 129/255), Color(red: 209/255, green: 250/255, blue: 229/255))
        }

        let diff = totalSpent - prevTotalSpent
        if abs(diff) < 1 {
            return (isHe ? "ללא שינוי מ\(previousMonthName)" : "No change from \(previousMonthName)", nil, Color.textSecondary, Color(uiColor: .systemGray6))
        }

        let formattedDiff = l10n.format(amount: abs(diff).rounded())
        if diff > 0 {
            let txt = isHe ? "↑ \(formattedDiff) יותר מ\(previousMonthName)" : "↑ \(formattedDiff) more than \(previousMonthName)"
            return (txt, true, Color(red: 239/255, green: 68/255, blue: 68/255), Color(red: 254/255, green: 242/255, blue: 242/255))
        } else {
            let txt = isHe ? "↓ \(formattedDiff) פחות מ\(previousMonthName)" : "↓ \(formattedDiff) less than \(previousMonthName)"
            return (txt, false, Color(red: 16/255, green: 185/255, blue: 129/255), Color(red: 209/255, green: 250/255, blue: 229/255))
        }
    }

    private var currentCitySavings: Double {
        displayTransactions.filter { $0.category.canonical == .savings }.reduce(0) { $0 + $1.amount }
    }

    private var expectedIncome: Double {
        BudgetService.monthlySpendingBudget(categoryBudgets: categoryBudgets, overallBudget: userMonthlyBudget)
    }

    // MARK: - Body Layout

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Sticky Header (Pinned outside ScrollView, matches HistoryView) ──
                VStack(spacing: 10) {
                    topNavigationBar
                    monthStepperRow
                    flatSegmentedTabs
                        .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Color.appBackground)

                // ── Scrollable Body ──
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        heroKpiSection

                        compactBarChart
                            .padding(.horizontal, 20)

                        if selectedTab == "spending" && !displayTransactions.isEmpty {
                            monthlyPulseRow
                                .padding(.top, 4)
                        }

                        if selectedTab == "spending" && housingThisMonth > 0 {
                            housingLineItem
                                .padding(.top, 2)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        topCategoriesSection
                            .padding(.horizontal, 20)
                            .padding(.top, 4)

                        if selectedTab == "spending" && !categoryTotals.isEmpty {
                            categoryDonutCard
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
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
                transactions: txs
            )
            .environmentObject(l10n)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { animateChart = true }
        }
    }

    // MARK: - Sticky Top Navigation Bar

    private var topNavigationBar: some View {
        HStack(alignment: .center) {
            Text(l10n.language == .hebrew ? "ניתוח נתונים" : "Analytics")
                .font(.system(size: 26, weight: .bold, design: .default))
                .foregroundColor(Color.deepNavy)

            Spacer()

            // Monthly Story / Recap Button
            Button(action: {
                Haptics.impact(.medium)
                activeRecap = MonthlyRecapService.generateRecap(
                    for: targetMonthDate,
                    allTransactions: allTransactions,
                    monthlyBudget: BudgetService.monthlySpendingBudget(
                        categoryBudgets: categoryBudgets,
                        overallBudget: userMonthlyBudget
                    )
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
            }
            .disabled(selectedMonthOffset >= 0)

            Spacer()
        }
    }

    // MARK: - Hero KPI Section

    private var heroKpiSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(l10n.format(amount: selectedTab == "savings" ? currentCitySavings : (selectedTab == "income" ? expectedIncome : totalSpent)))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                if let info = comparisonInfo {
                    Text(info.text)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(info.color)
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
        VStack(alignment: .leading, spacing: 16) {
            // Header: Category Title / Back Button / Reset
            donutCardHeader

            // Interactive Donut Chart with Center Info Hub
            donutView

            // Interactive Category / Subcategory Legend Chips
            donutLegendView
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)
    }

    // MARK: - Donut Card Header

    private var donutCardHeader: some View {
        HStack {
            HStack(spacing: 6) {
                MoneyIcon(.pieChart, size: 16, color: Color.deepNavy)
                Text(l10n.language == .hebrew ? "התפלגות הוצאות" : "Spending Breakdown")
                    .font(.system(size: 16, weight: .bold, design: .default))
                    .foregroundColor(Color.deepNavy)
            }

            Spacer()

            if selectedSlice != nil {
                Button(action: {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedSlice = nil
                    }
                }) {
                    Text(l10n.language == .hebrew ? "איפוס" : "Reset")
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(Color.textSecondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Color(uiColor: .systemGray6))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Donut Chart Ring & Calculations

    private var donutSlices: [DonutSliceData] {
        let totals = categoryTotals
        guard !totals.isEmpty else { return [] }
        let totalAmt = max(totals.reduce(0.0) { $0 + $1.amount }, 1.0)
        let gap: Double = totals.count > 1 ? 2.5 : 0.0
        var currentAngle: Double = -90.0

        var slices: [DonutSliceData] = []
        for item in totals {
            let sweep = (item.amount / totalAmt) * 360.0
            let rawStart = currentAngle
            let rawEnd = currentAngle + sweep

            let sAngle = rawStart + (gap / 2.0)
            let eAngle = rawEnd - (gap / 2.0)
            let validEnd = max(sAngle, eAngle)

            let txCount = displayTransactions.filter { countsTowardStats($0) && $0.category.canonical == item.category.canonical }.count

            slices.append(DonutSliceData(
                id: item.category.rawValue,
                category: item.category,
                name: item.category.displayName,
                icon: nil,
                color: item.category.themeColor,
                amount: item.amount,
                fraction: item.fraction,
                count: txCount,
                startAngle: sAngle,
                endAngle: validEnd,
                rawStartAngle: rawStart,
                rawEndAngle: rawEnd
            ))
            currentAngle += sweep
        }
        return slices
    }

    private var donutView: some View {
        let diameter: CGFloat = 185

        return ZStack {
            // Track background ring
            Circle()
                .stroke(Color(uiColor: .systemGray6).opacity(0.85), lineWidth: 21)
                .frame(width: diameter, height: diameter)

            // Dynamic Slices
            ForEach(donutSlices) { slice in
                let isSelected = selectedSlice == slice.category
                let isDimmed = selectedSlice != nil && !isSelected

                DonutArcShape(startAngle: slice.startAngle, endAngle: slice.endAngle)
                    .stroke(
                        slice.color,
                        style: StrokeStyle(lineWidth: isSelected ? 26 : 21, lineCap: .butt)
                    )
                    .frame(width: diameter, height: diameter)
                    .opacity(isDimmed ? 0.35 : 1.0)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
            }

            // Center Info Hub
            donutCenterHub
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .onTapGesture(coordinateSpace: .local) { location in
            handleDonutTap(at: location, diameter: diameter)
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func handleDonutTap(at location: CGPoint, diameter: CGFloat) {
        let center = CGPoint(x: diameter / 2, y: diameter / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let dist = sqrt(dx * dx + dy * dy)

        // Center hub tap (radius ~52pt) or tap outside ring -> reset selection
        if dist <= 52 || dist > (diameter / 2 + 18) {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedSlice = nil
            }
            return
        }

        let slices = donutSlices
        guard !slices.isEmpty else { return }

        // Method 1: Geometric Path hit-test using stroked arc (lineWidth 36 for easy, forgiving finger touch)
        let radius = max((diameter - 30) / 2, 10)
        var hitSlice: DonutSliceData? = nil
        for slice in slices {
            var path = Path()
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(slice.startAngle),
                endAngle: .degrees(slice.endAngle),
                clockwise: false
            )
            let strokePath = path.strokedPath(StrokeStyle(lineWidth: 36, lineCap: .butt))
            if strokePath.contains(location) {
                hitSlice = slice
                break
            }
        }

        // Method 2: Polar angle fallback (if tap landed precisely in the gap between slices)
        if hitSlice == nil {
            var angleDeg = atan2(dy, dx) * 180.0 / .pi
            if angleDeg < -90.0 {
                angleDeg += 360.0
            }
            for (index, slice) in slices.enumerated() {
                let isLast = (index == slices.count - 1)
                let matches = isLast
                    ? (angleDeg >= slice.rawStartAngle && angleDeg <= slice.rawEndAngle + 0.5)
                    : (angleDeg >= slice.rawStartAngle && angleDeg < slice.rawEndAngle)
                if matches {
                    hitSlice = slice
                    break
                }
            }
        }

        if let hit = hitSlice {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if selectedSlice == hit.category {
                    // Tapping already-selected category toggles it off!
                    selectedSlice = nil
                } else {
                    selectedSlice = hit.category
                }
            }
        }
    }

    private var donutCenterHub: some View {
        VStack(spacing: 2) {
            if let sel = selectedSlice, let match = categoryTotals.first(where: { $0.category == sel }) {
                // Category Selected
                CategoryBadge(category: sel, size: 22)

                Text(sel.displayName)
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .foregroundColor(Color.deepNavy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(l10n.format(amount: match.amount.rounded()))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(sel.themeColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("\(Int(round(match.fraction * 100)))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)

                let count = displayTransactions.filter { countsTowardStats($0) && $0.category.canonical == sel.canonical }.count
                Text("\(count) \(l10n.language == .hebrew ? "עסקאות" : "txs")")
                    .font(.system(size: 8, weight: .medium, design: .default))
                    .foregroundColor(Color.textSecondary)
            } else {
                // Default: Month Total Spending
                Text(l10n.language == .hebrew ? "סה״כ החודש" : "Total Spent")
                    .font(.system(size: 10, weight: .medium, design: .default))
                    .foregroundColor(Color.textSecondary)

                Text(l10n.format(amount: totalSpent.rounded()))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                let count = displayTransactions.filter(countsTowardStats).count
                if count > 0 {
                    Text("\(count) \(l10n.language == .hebrew ? "עסקאות" : "txs")")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textMuted)
                }
            }
        }
        .frame(width: 104, height: 104)
        .background(
            Circle()
                .fill(Color(red: 250/255, green: 250/255, blue: 252/255))
        )
    }

    private var donutLegendView: some View {
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]

        return VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(categoryTotals, id: \.category) { item in
                    let isSelected = selectedSlice == item.category
                    let isDimmed = selectedSlice != nil && !isSelected

                    Button(action: {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            if selectedSlice == item.category {
                                selectedSlice = nil
                            } else {
                                selectedSlice = item.category
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.category.themeColor)
                                .frame(width: 8, height: 8)

                            Text(item.category.displayName)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .default))
                                .foregroundColor(Color.deepNavy)
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            Text("\(Int(round(item.fraction * 100)))%")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(isSelected ? item.category.themeColor : Color.textSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isSelected ? item.category.themeColor.opacity(0.12) : Color(uiColor: .systemGray6).opacity(0.65))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(isSelected ? item.category.themeColor.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                        .opacity(isDimmed ? 0.45 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Subcategory / Merchant Breakdown when a category is selected
            if let sel = selectedSlice {
                selectedCategorySubBreakdown(for: sel)
            }
        }
    }

    @ViewBuilder
    private func selectedCategorySubBreakdown(for category: SpendingCategory) -> some View {
        let activeTxs = displayTransactions.filter { countsTowardStats($0) && $0.category.canonical == category.canonical }
        let items = SubcategoryBreakdownService.shared.breakdown(
            for: category,
            transactions: activeTxs,
            isHebrew: l10n.language == .hebrew
        )

        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(l10n.language == .hebrew ? "פירוט עבור \(category.displayName):" : "Breakdown for \(category.displayName):")
                        .font(.system(size: 11, weight: .bold, design: .default))
                        .foregroundColor(Color.deepNavy)
                    Spacer()
                }
                .padding(.top, 4)

                VStack(spacing: 5) {
                    ForEach(items.prefix(4)) { sub in
                        HStack(spacing: 6) {
                            MoneyIcon(sub.icon, size: 12, color: sub.color)
                            Text(sub.name)
                                .font(.system(size: 11, weight: .medium, design: .default))
                                .foregroundColor(Color.deepNavy)
                                .lineLimit(1)
                            Spacer()
                            Text(l10n.format(amount: sub.amount.rounded()))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            Text("(\(Int(round(sub.fraction * 100)))%)")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(Color.textSecondary)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color(uiColor: .systemGray6).opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .padding(.top, 4)
        }
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

    // MARK: - Modern Flat Segmented Tabs

    private var flatSegmentedTabs: some View {
        let isHe = l10n.language == .hebrew
        let tabs: [(id: String, label: String)] = [
            ("spending", isHe ? "הוצאות" : "Spending"),
            ("income", isHe ? "הכנסות" : "Income"),
            ("savings", isHe ? "חיסכון" : "Savings")
        ]

        return HStack(spacing: 0) {
            ForEach(tabs, id: \.id) { tab in
                let isSel = selectedTab == tab.id
                Button(action: {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        selectedTab = tab.id
                    }
                }) {
                    Text(tab.label)
                        .font(.system(size: 13, weight: isSel ? .bold : .medium, design: .default))
                        .foregroundColor(isSel ? Color.deepNavy : Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            ZStack {
                                if isSel {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white)
                                        .shadow(color: Color.black.opacity(0.06), radius: 4, y: 1)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color(uiColor: .systemGray6).opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Compact Comparative Bar Chart

    private var compactBarChart: some View {
        let months = chartMonths
        let maxAmt = max(months.map(\.amount).max() ?? 1, 100)
        let chartHeight: CGFloat = 72
        let avgAmt = averageChartSpending

        // Which bar is highlighted — defaults to the current month (offset == selectedMonthOffset)
        let highlightedOffset = selectedBarOffset ?? selectedMonthOffset

        return VStack(spacing: 10) {
            // Section Header: Title + Clean Average Capsule Badge
            HStack(alignment: .center) {
                Text(l10n.language == .hebrew ? "השוואה חצי שנתית" : "6-Month Overview")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                Spacer()

                if avgAmt > 10 {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(storyVibrantPurple)
                            .frame(width: 5, height: 5)
                        Text(l10n.language == .hebrew ? "ממוצע: \(l10n.format(amount: avgAmt.rounded()))" : "Avg: \(l10n.format(amount: avgAmt.rounded()))")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(Capsule())
                }
            }

            // 6 Evenly Spaced Month Columns with Discrete Touch Scrubbing
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(months, id: \.offset) { item in
                        let frac = maxAmt > 0 ? CGFloat(item.amount / maxAmt) : 0
                        let barHeight: CGFloat = animateChart
                            ? (item.amount > 0 ? max(frac * chartHeight, 10) : 4)
                            : 4
                        let isHighlighted = (item.offset == highlightedOffset)
                        let columnOpacity: Double = isHighlighted ? 1.0 : ((isScrubbingChart || selectedBarOffset != nil) ? 0.55 : 1.0)

                        Button(action: {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                                selectedBarOffset = item.offset
                                selectedSlice = nil
                            }
                        }) {
                            VStack(spacing: 6) {
                                // Amount Badge above the bar
                                ZStack {
                                    if isHighlighted && item.amount > 0 {
                                        Text(l10n.format(amount: item.amount.rounded()))
                                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                            .foregroundColor(storyVibrantPurple)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(storySoftLilac.opacity(0.85))
                                            .clipShape(Capsule())
                                            .fixedSize()
                                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                                    } else {
                                        Color.clear.frame(height: 18)
                                    }
                                }
                                .frame(height: 18)

                                // Bar track + Filled pillar
                                ZStack(alignment: .bottom) {
                                    // Subtle track providing clean structure for all 6 months
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color(uiColor: .systemGray6).opacity(0.9))
                                        .frame(width: 28, height: chartHeight)

                                    // Dynamic filled bar
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(isHighlighted ? storyVibrantPurple : (item.amount > 0 ? storySoftLilac : Color.clear))
                                        .frame(width: 28, height: barHeight)
                                        .scaleEffect(isHighlighted ? 1.04 : 1.0, anchor: .bottom)
                                }

                                // Month abbreviation label
                                Text(item.label)
                                    .font(.system(size: 11, weight: isHighlighted ? .bold : .medium, design: .default))
                                    .foregroundColor(isHighlighted ? Color.deepNavy : Color.textSecondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .opacity(columnOpacity)
                            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: columnOpacity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 6)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) * 0.7 else { return }
                            isScrubbingChart = true
                            let totalWidth = geo.size.width
                            guard totalWidth > 0, !months.isEmpty else { return }
                            let count = months.count
                            let fraction = max(0, min(1, value.location.x / totalWidth))
                            let isHe = l10n.language == .hebrew
                            let index = isHe
                                ? min(max(Int((1.0 - fraction) * Double(count)), 0), count - 1)
                                : min(max(Int(fraction * Double(count)), 0), count - 1)

                            let candidateOffset = months[index].offset
                            if candidateOffset != selectedBarOffset {
                                Haptics.selection()
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                                    selectedBarOffset = candidateOffset
                                    selectedSlice = nil
                                }
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.2)) {
                                isScrubbingChart = false
                            }
                        }
                )
            }
            .frame(height: 118)
        }
        .padding(.vertical, 4)
        .onChange(of: selectedMonthOffset) { _, _ in
            // When user navigates with the arrows, reset bar selection to the new current month
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
                        Text("\(Int(round(fraction * 100)))%")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color.textSecondary)

                        Text(l10n.format(amount: amount))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)

                        MoneyIcon(l10n.isHebrew ? .chevronLeft : .chevronRight, size: 8, color: Color.textMuted.opacity(0.6))
                    }
                }

                // Micro Progress Bar indicating relative spending volume
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
        let maxTxText = topTx.map { l10n.format(amount: $0.amount.rounded()) } ?? "₪0"

        return HStack(alignment: .top, spacing: 0) {
            // 1. Daily Average
            VStack(alignment: .leading, spacing: 2) {
                Text(isHe ? "ממוצע ליום" : "Daily Avg")
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundColor(Color.textMuted)

                Text(l10n.format(amount: dailyAvg.rounded()))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Subtle hairline separator
            Rectangle()
                .fill(Color.borderSubtle.opacity(0.6))
                .frame(width: 1, height: 26)
                .padding(.horizontal, 10)

            // 2. Activity / Transaction Count
            VStack(alignment: .leading, spacing: 2) {
                Text(isHe ? "פעילות" : "Activity")
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundColor(Color.textMuted)

                Text(isHe ? "\(txCount) עסקאות" : "\(txCount) txs")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Subtle hairline separator
            Rectangle()
                .fill(Color.borderSubtle.opacity(0.6))
                .frame(width: 1, height: 26)
                .padding(.horizontal, 10)

            // 3. Top Expense
            VStack(alignment: .leading, spacing: 2) {
                Text(isHe ? "הוצאת שיא" : "Top Expense")
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundColor(Color.textMuted)

                Text(maxTxText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
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
                        .foregroundColor(excludeHousing ? Color.primaryBlue : Color.themeMint)
                }

                Text(excludeHousing
                     ? (isHebrew
                        ? "\(l10n.format(amount: hiddenHousing.rounded())) מוסתרים מהחישוב"
                        : "\(l10n.format(amount: hiddenHousing.rounded())) hidden from total")
                     : (isHebrew
                        ? "שכירות וחשבונות כלולים (\(l10n.format(amount: housingThisMonth.rounded())))"
                        : "Rent & utilities included (\(l10n.format(amount: housingThisMonth.rounded())))"))
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
