import SwiftUI
import SwiftData

// MARK: - Donut Chart Shape

private struct DonutSlice: Shape {
    var startAngle: Double
    var endAngle: Double
    var innerRatio: Double = 0.64

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle, endAngle) }
        set { startAngle = newValue.first; endAngle = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = min(rect.width, rect.height) / 2
        let innerR = outerR * innerRatio
        let gap: Double = 2.5

        let sA = Angle(degrees: startAngle + gap / 2)
        let eA = Angle(degrees: endAngle   - gap / 2)

        var path = Path()
        path.addArc(center: center, radius: outerR, startAngle: sA, endAngle: eA, clockwise: false)
        path.addArc(center: center, radius: innerR, startAngle: eA, endAngle: sA, clockwise: true)
        path.closeSubpath()
        return path
    }
}

// MARK: - Analytics View

public struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager
    @Query(sort: \Transaction.timestamp, order: .reverse) private var allTransactions: [Transaction]

    @State private var selectedSlice: SpendingCategory? = nil
    @State private var selectedWeek: String? = nil
    @State private var activeRecap: MonthlyRecap? = nil
    @State private var animateChart = false

    private var displayTransactions: [Transaction] {
        let cal = Calendar.current
        let now = Date()
        return allTransactions.filter {
            cal.isDate($0.timestamp, equalTo: now, toGranularity: .month)
        }
    }

    private var totalSpent: Double {
        displayTransactions.filter { $0.category != .savings }.reduce(0) { $0 + $1.amount }
    }

    private var categoryTotals: [(category: SpendingCategory, amount: Double)] {
        var totals: [SpendingCategory: Double] = [:]
        for tx in displayTransactions where tx.category != .savings {
            totals[tx.category, default: 0] += tx.amount
        }
        return totals.sorted { $0.value > $1.value }.map { (category: $0.key, amount: $0.value) }
    }

    private var weeklyTotals: [(label: String, amount: Double)] {
        let cal = Calendar.current
        let now = Date()
        let isHebrew = l10n.language == .hebrew
        let weekRef = startOfWeek(cal, now)
        return (0..<4).reversed().map { i in
            let weekStart = cal.date(byAdding: .weekOfYear, value: -i, to: weekRef) ?? now
            let weekEnd   = cal.date(byAdding: .day, value: 7, to: weekStart) ?? now
            let total = allTransactions
                .filter { $0.timestamp >= weekStart && $0.timestamp < weekEnd && $0.category != .savings }
                .reduce(0) { $0 + $1.amount }
            let lbl = isHebrew ? "שב׳ \(4 - i)" : "W\(4 - i)"
            return (lbl, total)
        }
    }

    private func startOfWeek(_ cal: Calendar, _ date: Date) -> Date {
        return cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    private func sliceAngles() -> [(category: SpendingCategory, start: Double, end: Double)] {
        var result: [(SpendingCategory, Double, Double)] = []
        var cursor: Double = -90
        for item in categoryTotals where item.amount > 0 {
            let sweep = totalSpent > 0 ? (item.amount / totalSpent) * 360 : 0
            result.append((item.category, cursor, cursor + sweep))
            cursor += sweep
        }
        return result
    }

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // ── Header ──
                    HStack {
                        Text(l10n.language == .hebrew ? "ניתוח" : "Analytics")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // ── Modern Donut Card with Embedded Category Legend ──
                    donutAnalyticsCard

                    // ── Monthly Story Card (Spotify Wrapped Style) ──
                    if !displayTransactions.isEmpty {
                        Button(action: {
                            Haptics.impact(.medium)
                            activeRecap = MonthlyRecapService.generateRecap(
                                for: Date(),
                                allTransactions: allTransactions
                            )
                        }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.primaryBlue.opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    DistrictSkylineVectorIcon(color: Color.primaryBlue)
                                        .scaleEffect(1.0)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(l10n.language == .hebrew ? "הסיפור של החודש" : "Monthly City Story")
                                        .font(.system(size: 15, weight: .black, design: .rounded))
                                        .foregroundColor(Color.deepNavy)
                                    Text(l10n.language == .hebrew ? "צפה בסיכום הוויזואלי של מה שבנית החודש בעיר" : "See the visual story of what you built")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(Color.textMuted)
                                }
                                
                                Spacer()
                                
                                Image(systemName: l10n.language == .hebrew ? "chevron.left" : "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.primaryBlue)
                            }
                            .padding(14)
                            .cityCard(.plain, radius: MoneyCityTheme.radiusCard)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }

                    // ── Weekly Expenses Bar Chart ──
                    weeklyExpensesCard

                    // ── Category Breakdown List ──
                    categoryBreakdownCard

                    Spacer(minLength: 110)
                }
            }
        }
        .sheet(item: $activeRecap) { recap in
            MonthlyRecapSheet(recap: recap)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { animateChart = true }
        }
    }

    // MARK: - Donut & Breakdown Card

    private var donutAnalyticsCard: some View {
        VStack(spacing: 20) {
            // Chart & Center Summary
            ZStack {
                if categoryTotals.isEmpty || totalSpent <= 0 {
                    Circle()
                        .stroke(Color.borderSubtle, lineWidth: 28)
                        .frame(width: 190, height: 190)
                } else {
                    ForEach(sliceAngles(), id: \.category) { item in
                        DonutSlice(
                            startAngle: animateChart ? item.start : -90,
                            endAngle:   animateChart ? item.end   : -90
                        )
                        .fill(item.category == selectedSlice
                              ? item.category.themeColor
                              : item.category.themeColor.opacity(0.92))
                        .scaleEffect(item.category == selectedSlice ? 1.05 : 1.0)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                selectedSlice = selectedSlice == item.category ? nil : item.category
                            }
                        }
                    }
                }

                // Center Total Text
                VStack(spacing: 2) {
                    if let sel = selectedSlice,
                       let item = categoryTotals.first(where: { $0.category == sel }) {
                        CategoryVectorIcon(category: sel, size: 28)
                        Text("\(l10n.baseCurrency.symbol)\(Int(item.amount))")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        Text(sel.displayName)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color.textMuted)
                            .lineLimit(1)
                    } else {
                        Text("\(l10n.baseCurrency.symbol)\(Int(totalSpent))")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        Text(l10n.language == .hebrew ? "החודש" : "Total This Month")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.textMuted)
                    }
                }
                .frame(width: 120)
                .multilineTextAlignment(.center)
            }
            .frame(width: 210, height: 210)
            .padding(.top, 10)

            // Category Legend Table (matching Mockup)
            if !categoryTotals.isEmpty {
                VStack(spacing: 10) {
                    ForEach(categoryTotals.prefix(5), id: \.category) { item in
                        let pct = totalSpent > 0 ? Int(round((item.amount / totalSpent) * 100)) : 0
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedSlice = selectedSlice == item.category ? nil : item.category
                            }
                        }) {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(item.category.themeColor)
                                    .frame(width: 10, height: 10)

                                Text(item.category.displayName)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(selectedSlice == item.category ? Color.primaryBlue : Color.deepNavy)

                                Spacer()

                                Text("\(l10n.baseCurrency.symbol)\(Int(item.amount))")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundColor(Color.deepNavy)

                                Text("\(pct)%")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.textMuted)
                                    .frame(width: 32, alignment: .trailing)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedSlice == item.category ? Color.borderSubtle.opacity(0.5) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .cityCard(.plain, radius: MoneyCityTheme.radiusCard)
        .padding(.horizontal, 16)
    }

    // MARK: - Weekly Expenses Bar Chart

    private var weeklyExpensesCard: some View {
        let maxAmt = max(weeklyTotals.map(\.amount).max() ?? 1, 100)
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(l10n.language == .hebrew ? "הוצאות שבועיות" : "Weekly Expenses")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                Spacer()
                Text(l10n.language == .hebrew ? "4 שבועות אחרונים" : "Last 4 weeks")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textMuted)
            }

            HStack(alignment: .bottom, spacing: 14) {
                ForEach(Array(weeklyTotals.enumerated()), id: \.element.label) { idx, week in
                    let frac = maxAmt > 0 ? CGFloat(week.amount / maxAmt) : 0
                    let isSelected = (selectedWeek == week.label)
                    
                    Button(action: {
                        Haptics.impact(.light)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedWeek = isSelected ? nil : week.label
                        }
                    }) {
                        VStack(spacing: 8) {
                            // Interactive floating tooltip
                            if isSelected {
                                Text("\(l10n.baseCurrency.symbol)\(Int(week.amount))")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.deepNavy)
                                    .clipShape(Capsule())
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Color.clear.frame(height: 18)
                            }
                            
                            Spacer(minLength: 0)
                            
                            ZStack(alignment: .bottom) {
                                // Light gray background track
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.borderSubtle)
                                    .frame(width: 32, height: 90)

                                // Royal Blue Fill Bar
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.themeTurquoise : Color.primaryBlue)
                                    .frame(width: 32, height: animateChart ? max(frac * 90, 8) : 8)
                                    .animation(.easeOut(duration: 0.75).delay(Double(idx) * 0.08), value: animateChart)
                                    .scaleEffect(isSelected ? 1.06 : 1.0)
                            }

                            Text(week.label)
                                .font(.system(size: 11, weight: isSelected ? .black : .bold, design: .rounded))
                                .foregroundColor(isSelected ? Color.primaryBlue : Color.deepNavy)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .bouncyPress(scale: 0.94)
                }
            }
            .frame(height: 145)
        }
        .padding(20)
        .cityCard(.plain, radius: MoneyCityTheme.radiusCard)
        .padding(.horizontal, 16)
    }

    // MARK: - Category Breakdown List

    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(l10n.language == .hebrew ? "לפי קטגוריה" : "By Category")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                Spacer()
            }
            .padding(.bottom, 14)

            if categoryTotals.isEmpty {
                Text(l10n.language == .hebrew ? "טרם נרשמו הוצאות החודש" : "No expenses this month")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .padding(.vertical, 10)
            } else {
                ForEach(Array(categoryTotals.enumerated()), id: \.element.category) { idx, item in
                    if idx > 0 {
                        Divider().background(Color.borderSubtle).padding(.vertical, 2)
                    }
                    categoryProgressRow(item.category, amount: item.amount)
                }
            }
        }
        .padding(20)
        .cityCard(.plain, radius: MoneyCityTheme.radiusCard)
        .padding(.horizontal, 16)
    }

    private func categoryProgressRow(_ cat: SpendingCategory, amount: Double) -> some View {
        let pct = totalSpent > 0 ? CGFloat(amount / totalSpent) : 0
        let pctInt = totalSpent > 0 ? Int(round((amount / totalSpent) * 100)) : 0
        return HStack(spacing: 12) {
            CategoryBadge(category: cat, size: 42)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(cat.displayName)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    Spacer()
                    Text("\(l10n.baseCurrency.symbol)\(Int(amount))")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    Text("\(pctInt)%")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textMuted)
                        .frame(width: 32, alignment: .trailing)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.borderSubtle)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(cat.themeColor)
                            .frame(width: animateChart ? geo.size.width * pct : 0, height: 6)
                            .animation(.easeOut(duration: 0.8).delay(0.15), value: animateChart)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(.vertical, 8)
    }
}
