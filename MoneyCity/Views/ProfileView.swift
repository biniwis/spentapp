import SwiftUI
import SwiftData

public struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager
    @Query(sort: \Transaction.timestamp, order: .reverse) private var allTransactions: [Transaction]
    @Query private var allEnrichments: [CityEnrichment]

    /// Passed down to the recap archive so its "Back to City" button reaches the tab state,
    /// which lives above this view.
    public var onNavigateToCity: ((Date) -> Void)? = nil

    public init(onNavigateToCity: ((Date) -> Void)? = nil) {
        self.onNavigateToCity = onNavigateToCity
    }
    @Query private var budgets: [CategoryBudget]

    @AppStorage("userName") private var userName = ""
    @AppStorage("monthly_budget") private var userMonthlyBudget: Double = 0
    @State private var showSettings = false
    @State private var showPrivacySheet = false
    @State private var showBudgetsSheet = false
    @State private var showRecurringSheet = false
    @State private var showGoalsSheet = false
    @State private var showApplePayGuideSheet = false
    @State private var showRecapArchive = false
    @State private var showBackupSheet = false
    @State private var showOnboardingTour = false
    @State private var selectedMonth: String? = nil
    @State private var showDetailedYear = false
    @State private var showDetailedTransactions = false
    @State private var showDetailedStreak = false
    @State private var showDetailedBudget = false
    @State private var activeRecapForSheet: MonthlyRecap? = nil

    private var activeWindowRecapAndStatus: (recap: MonthlyRecap, status: MonthlyRecapService.RecapWindowStatus)? {
        let status = MonthlyRecapService.checkRecapWindow()
        guard status.isActive, let targetDate = status.targetMonthDate else { return nil }
        let recap = MonthlyRecapService.generateRecap(
            for: targetDate,
            allTransactions: allTransactions,
            monthlyBudget: effectiveBudgetLimit > 0 ? effectiveBudgetLimit : nil
        )
        guard recap.transactionCount > 0 else { return nil }
        return (recap, status)
    }

    private var thisMonthTransactions: [Transaction] {
        let cal = Calendar.current
        let now = Date()
        return allTransactions.filter {
            cal.isDate($0.timestamp, equalTo: now, toGranularity: .month)
        }
    }

    private var totalThisMonth: Double {
        thisMonthTransactions.filter { $0.category != .savings }.reduce(0) { $0 + $1.amount }
    }

    private var yearTransactions: [Transaction] {
        let cal = Calendar.current
        let now = Date()
        return allTransactions.filter {
            cal.isDate($0.timestamp, equalTo: now, toGranularity: .year)
        }
    }

    private var totalThisYear: Double {
        yearTransactions.filter { $0.category != .savings }.reduce(0) { $0 + $1.amount }
    }

    // Monthly totals for bar chart (last 12 rolling months)
    /// "March 2026" rather than the three-letter axis label, since the readout has the room
    /// and the axis label alone is ambiguous once twelve months wrap a year boundary.
    private func monthFullName(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: l10n.language == .hebrew ? "he_IL" : "en_US")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date)
    }

    private var monthlyTotals: [(label: String, amount: Double, monthDate: Date)] {
        let cal = Calendar.current
        let now = Date()
        let hebrewMonths = ["ינו", "פבר", "מרץ", "אפר", "מאי", "יוני", "יולי", "אוג", "ספט", "אוק", "נוב", "דצמ"]
        return (0..<12).reversed().map { i in
            let monthDate = cal.date(byAdding: .month, value: -i, to: now) ?? now
            let total = allTransactions.filter {
                cal.isDate($0.timestamp, equalTo: monthDate, toGranularity: .month)
                && $0.category != .savings
            }.reduce(0) { $0 + $1.amount }

            let m = cal.component(.month, from: monthDate)
            let monthLabel: String
            if l10n.language == .hebrew {
                monthLabel = (m >= 1 && m <= 12) ? hebrewMonths[m - 1] : "חודש"
            } else {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US")
                f.dateFormat = "MMM"
                monthLabel = f.string(from: monthDate)
            }
            return (monthLabel, total, monthDate)
        }
    }

    private var total12Months: Double {
        monthlyTotals.reduce(0) { $0 + $1.amount }
    }

    /// Real consecutive daily transaction streak
    private var activeStreakDays: Int {
        guard !allTransactions.isEmpty else { return 0 }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let daysWithTx = Set(allTransactions.map { cal.startOfDay(for: $0.timestamp) })
        
        var streak = 0
        var checkDate = today
        
        if !daysWithTx.contains(checkDate) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: today),
                  daysWithTx.contains(yesterday) else {
                return 0
            }
            checkDate = yesterday
        }
        
        while daysWithTx.contains(checkDate) {
            streak += 1
            guard let prevDay = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prevDay
        }
        return streak
    }

    /// Effective budget limit across category caps or global budget
    private var effectiveBudgetLimit: Double {
        BudgetService.monthlySpendingBudget(
            categoryBudgets: budgets,
            overallBudget: userMonthlyBudget
        )
    }

    private var budgetGoalText: String {
        let limit = effectiveBudgetLimit
        guard limit > 0 else {
            return l10n.language == .hebrew ? "לא הוגדר" : "Not set"
        }
        let pct = Int(round((totalThisMonth / limit) * 100))
        return "\(pct)% " + (l10n.language == .hebrew ? "מהיעד" : "of goal")
    }

    /// Empty until the user types their own name. There is no default person.
    private var displayName: String {
        var clean = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("העיר של ") {
            clean = String(clean.dropFirst("העיר של ".count))
        }
        return clean
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let isHe = l10n.language == .hebrew
        let name = displayName
        let base: String
        if hour < 12 {
            base = isHe ? "בוקר טוב" : "Good morning"
        } else if hour < 17 {
            base = isHe ? "צהריים טובים" : "Good afternoon"
        } else {
            base = isHe ? "ערב טוב" : "Good evening"
        }
        // No name set yet: greet without one rather than inventing a person.
        return name.isEmpty ? base : "\(base), \(name)"
    }

    private var transactionCount: Int { allTransactions.count }

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // ── Top Header with Settings Gear Button ──
                    HStack {
                        Text(l10n.language == .hebrew ? "פרופיל" : "Profile")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        Spacer()

                        Button(action: { showSettings = true }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 40, height: 40)
                                    .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
                                SettingsGearVectorIcon(color: Color.deepNavy)
                                    .frame(width: 18, height: 18)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // ── User Avatar & City Greeting Card (Mayor Hero Badge) ──
                    userProfileCard

                    // ── Festive Monthly Recap Banner (Celebration Window) ──
                    if let (recap, status) = activeWindowRecapAndStatus {
                        festiveMonthlyRecapRow(recap: recap, status: status)
                    }

                    // ── 4 Bento Metric Tiles (Tactile with live micro-indicators) ──
                    statsGridCard

                    // ── 12-Month Spending Bar Chart (Architectural Styling) ──
                    yearChartCard

                    // ── Management Navigation Menu Cards (Inset Grouped) ──
                    managementMenuCard

                    Spacer(minLength: 120)
                }
            }
        }
        .fullScreenCover(item: $activeRecapForSheet) { recap in
            MonthlyRecapSheet(recap: recap, onNavigateToCity: onNavigateToCity)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .environmentObject(l10n)
        }
        .sheet(isPresented: $showBudgetsSheet) {
            BudgetSheet()
                .environmentObject(l10n)
        }
        .sheet(isPresented: $showRecurringSheet) {
            RecurringExpensesSheet()
                .environmentObject(l10n)
        }
        .sheet(isPresented: $showGoalsSheet) {
            SavingsGoalsSheet()
                .environmentObject(l10n)
        }
        .sheet(isPresented: $showApplePayGuideSheet) {
            ApplePayGuideSheet()
                .environmentObject(l10n)
        }
        .sheet(isPresented: $showRecapArchive) {
            MonthlyRecapArchiveView(onNavigateToCity: onNavigateToCity)
                .environmentObject(l10n)
        }
        .sheet(isPresented: $showBackupSheet) {
            BackupSheet()
                .environmentObject(l10n)
        }
        .fullScreenCover(isPresented: $showOnboardingTour) {
            OnboardingWizardView(
                initialStep: 1,
                initialPhase: "intro",
                canDismiss: true,
                onComplete: {
                    showOnboardingTour = false
                },
                onTriggerSampleTransaction: {}
            )
            .environmentObject(l10n)
        }
    }

    // MARK: - Festive Monthly Recap Banner (Celebration Window)

    private func festiveMonthlyRecapRow(recap: MonthlyRecap, status: MonthlyRecapService.RecapWindowStatus) -> some View {
        let isHe = l10n.language == .hebrew
        let monthName = isHe ? status.monthNameHe : status.monthNameEn

        return Button(action: {
            Haptics.impact(.medium)
            activeRecapForSheet = recap
        }) {
            VStack(alignment: .leading, spacing: 10) {
                // ── Top Mini Celebration Tag ──
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text(isHe ? "✦ סיכום חודשי" : "✦ MONTHLY RECAP")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.5)
                            .foregroundColor(Color.deepNavy)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(red: 243/255, green: 244/255, blue: 246/255))
                    .clipShape(Capsule())

                    Spacer()

                    Text(isHe ? "זמין לזמן מוגבל" : "Limited Time")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textMuted)
                }

                // ── Main Content Row ──
                HStack(spacing: 14) {
                    // Festive Badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(MoneyCityTheme.babyBlue)
                            .frame(width: 48, height: 48)
                        MoneyIcon(.trophy, size: 22)
                    }

                    // Titles
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isHe ? "הסיכום של \(monthName) מוכן!" : "\(monthName) Recap is Ready")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                            .lineLimit(1)

                        Text(isHe ? "בוא לראות איך העיר שלך נראית ומה היו השיאים" : "See your skyline growth and spending highlights")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(Color.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    // CTA Pill Button
                    HStack(spacing: 4) {
                        Text(isHe ? "צפה ✨" : "View ✨")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.deepNavy)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.borderSubtle, lineWidth: 1)
            )
            .shadow(color: Color.deepNavy.opacity(0.04), radius: 10, y: 3)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - User Profile Greeting Card (Mayor Hero Badge)

    private var userProfileCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(MoneyCityTheme.warmCream)
                    .frame(width: 56, height: 56)
                MoneyIcon(.user, size: 36)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(displayName.isEmpty ? (l10n.language == .hebrew ? "היי, ברוך הבא" : "Welcome") : (l10n.language == .hebrew ? "שלום, \(displayName)" : "Hey, \(displayName)"))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        MoneyIcon(.calendar, size: 12)
                        Text(l10n.language == .hebrew ? "החודש: \(l10n.format(amount: totalThisMonth))" : "This month: \(l10n.format(amount: totalThisMonth))")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color.deepNavy)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(MoneyCityTheme.jetBlack.opacity(0.05))
                    .clipShape(Capsule())

                    if activeStreakDays > 0 {
                        HStack(spacing: 4) {
                            MoneyIcon(.lightning, size: 10)
                            Text("\(activeStreakDays)d")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(MoneyCityTheme.brandPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(MoneyCityTheme.spentGreenSoft)
                        .clipShape(Capsule())
                    }
                }
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)
        .padding(.horizontal, 16)
    }

    // MARK: - 4 Bento Metric Tiles (Tactile with live micro-interactions)

    private var statsGridCard: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            // 1. Total This Year (Tap toggles between compact ₪1.3K and exact amount + monthly avg)
            yearMetricTile

            // 2. This Month Transactions (Tap toggles between count and average per transaction)
            monthTransactionsMetricTile

            // 3. Active Streak 🔥 (Tap triggers flame pulse and streak status)
            streakMetricTile

            // 4. Budget Goal 🎯 (Tap toggles percentage vs remaining amount; edit pill opens BudgetSheet)
            budgetMetricTile
        }
        .padding(.horizontal, 16)
    }

    private var yearMetricTile: some View {
        Button(action: {
            Haptics.selection()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                showDetailedYear.toggle()
            }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.spentGreenSoft)
                            .frame(width: 36, height: 36)
                        AnnualVaultVectorIcon(color: Color.spentGreen)
                            .scaleEffect(0.85)
                    }
                    Spacer()
                    Circle()
                        .fill(Color.spentGreen.opacity(showDetailedYear ? 0.85 : 0.18))
                        .frame(width: 6, height: 6)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if showDetailedYear {
                        Text(l10n.format(amount: totalThisYear, showDecimals: false))
                            .font(.system(size: 18.5, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        let currentMonthIdx = max(1, Calendar.current.component(.month, from: Date()))
                        let monthlyAvg = totalThisYear / Double(currentMonthIdx)
                        Text(l10n.language == .hebrew ? "ממוצע: \(l10n.format(amount: monthlyAvg, showDecimals: false))/חודש" : "Avg: \(l10n.format(amount: monthlyAvg, showDecimals: false))/mo")
                            .font(.system(size: 11, weight: .medium, design: .default))
                            .foregroundColor(Color.spentGreen)
                            .lineLimit(1)
                    } else {
                        Text("\(l10n.baseCurrency.symbol)\(shortAmt(totalThisYear))")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        Text(l10n.language == .hebrew ? "סך הכל השנה" : "Total This Year")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(Color.textSecondary)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 108)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)
        }
        .bouncyPress(scale: 0.96)
    }

    private var monthTransactionsMetricTile: some View {
        Button(action: {
            Haptics.selection()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                showDetailedTransactions.toggle()
            }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.themeTurquoiseSoft)
                            .frame(width: 36, height: 36)
                        BarMetricVectorIcon(color: Color.themeTurquoise)
                            .scaleEffect(0.85)
                    }
                    Spacer()
                    Circle()
                        .fill(Color.themeTurquoise.opacity(showDetailedTransactions ? 0.85 : 0.18))
                        .frame(width: 6, height: 6)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if showDetailedTransactions {
                        let avgTx = thisMonthTransactions.isEmpty ? 0 : (totalThisMonth / Double(thisMonthTransactions.count))
                        Text(l10n.format(amount: avgTx, showDecimals: false))
                            .font(.system(size: 18.5, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(l10n.language == .hebrew ? "ממוצע לעסקה" : "Avg per transaction")
                            .font(.system(size: 11, weight: .medium, design: .default))
                            .foregroundColor(Color.themeTurquoise)
                            .lineLimit(1)
                    } else {
                        Text("\(thisMonthTransactions.count)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        Text(l10n.language == .hebrew ? "עסקאות החודש" : "Transactions")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(Color.textSecondary)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 108)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)
        }
        .bouncyPress(scale: 0.96)
    }

    private var streakMetricTile: some View {
        Button(action: {
            Haptics.impact(.medium)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                showDetailedStreak.toggle()
            }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.themeOrangeSoft)
                            .frame(width: 36, height: 36)
                        StreakFlameVectorIcon(color: Color.themeOrange)
                            .scaleEffect(showDetailedStreak ? 1.0 : 0.85)
                    }
                    Spacer()
                    Circle()
                        .fill(Color.themeOrange.opacity(showDetailedStreak ? 0.85 : 0.18))
                        .frame(width: 6, height: 6)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if showDetailedStreak {
                        Text(activeStreakDays > 0 ? (l10n.language == .hebrew ? "פעיל היום! 🔥" : "Active Today! 🔥") : (l10n.language == .hebrew ? "התחל היום! ✨" : "Start Today! ✨"))
                            .font(.system(size: 16.5, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(l10n.language == .hebrew ? "שמור על הרצף מחר" : "Keep streak tomorrow")
                            .font(.system(size: 11, weight: .medium, design: .default))
                            .foregroundColor(Color.themeOrange)
                            .lineLimit(1)
                    } else {
                        Text("\(activeStreakDays) " + (l10n.language == .hebrew ? "ימים" : "days"))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        Text(l10n.language == .hebrew ? "רצף ימים פעיל" : "Active Streak")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(Color.textSecondary)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 108)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)
        }
        .bouncyPress(scale: 0.96)
    }

    private var budgetMetricTile: some View {
        Button(action: {
            Haptics.selection()
            if effectiveBudgetLimit <= 0 {
                showBudgetsSheet = true
            } else {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    showDetailedBudget.toggle()
                }
            }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.themeMintSoft)
                            .frame(width: 36, height: 36)
                        TargetReticleVectorIcon(color: Color(red: 16/255, green: 185/255, blue: 129/255))
                            .scaleEffect(0.85)
                    }
                    Spacer()
                    Circle()
                        .fill(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(showDetailedBudget ? 0.85 : 0.18))
                        .frame(width: 6, height: 6)
                }

                let limit = effectiveBudgetLimit
                let remaining = max(0, limit - totalThisMonth)
                let fraction = limit > 0 ? min(totalThisMonth / limit, 1.0) : 0.0

                VStack(alignment: .leading, spacing: 3) {
                    if limit <= 0 {
                        Text(l10n.language == .hebrew ? "הגדר יעד" : "Set Goal")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                    } else if showDetailedBudget {
                        Text(totalThisMonth > limit ? (l10n.language == .hebrew ? "חריגה" : "Over") : "\(l10n.language == .hebrew ? "נותרו" : "Left") \(l10n.format(amount: remaining, showDecimals: false))")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(totalThisMonth > limit ? Color.deleteRed : Color.deepNavy)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    } else {
                        Text(budgetGoalText)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(red: 243/255, green: 244/255, blue: 246/255))
                            Capsule().fill(totalThisMonth > limit && limit > 0 ? Color.deleteRed : Color(red: 16/255, green: 185/255, blue: 129/255))
                                .frame(width: geo.size.width * CGFloat(fraction))
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 2)

                    if showDetailedBudget && limit > 0 {
                        Text(l10n.language == .hebrew ? "מתוך \(l10n.format(amount: limit, showDecimals: false)) תקציב" : "of \(l10n.format(amount: limit, showDecimals: false)) budget")
                            .font(.system(size: 11, weight: .medium, design: .default))
                            .foregroundColor(Color.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text(l10n.language == .hebrew ? "יעד תקציב חודשי" : "Monthly Budget")
                            .font(.system(size: 11, weight: .medium, design: .default))
                            .foregroundColor(Color.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 108)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)
        }
        .bouncyPress(scale: 0.96)
    }

    // MARK: - 12-Month Spending Bar Chart (SPENT Green Architectural Styling)

    private var yearChartCard: some View {
        let maxAmt = max(monthlyTotals.map(\.amount).max() ?? 1, 100)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                if let sel = selectedMonth, let m = monthlyTotals.first(where: { $0.label == sel }) {
                    Text(monthFullName(m.monthDate))
                        .font(.system(size: 15, weight: .bold, design: .default))
                        .foregroundColor(Color.deepNavy)
                    Spacer()
                    Text(l10n.format(amount: m.amount.rounded()))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color.spentGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Button {
                        Haptics.impact(.light)
                        onNavigateToCity?(m.monthDate)
                    } label: {
                        HStack(spacing: 4) {
                            Text(l10n.language == .hebrew ? "לעיר" : "City")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            Text(verbatim: l10n.language == .hebrew ? "‹" : "›")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(MoneyCityTheme.jetBlack)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.spentGreen)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .bouncyPress(scale: 0.94)
                } else {
                    Text(l10n.language == .hebrew ? "סקירת 12 חודשים" : "12-Month Overview")
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .foregroundColor(Color.deepNavy)
                    Spacer()
                    Text("\(l10n.baseCurrency.symbol)\(shortAmt(total12Months))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color.spentGreen)
                }
            }
            .frame(minHeight: 28)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedMonth)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(monthlyTotals.enumerated()), id: \.element.label) { idx, month in
                    let isCurrentMonth = (idx == monthlyTotals.count - 1)
                    let isSelected = (selectedMonth == month.label)
                    let frac = maxAmt > 0 ? CGFloat(month.amount / maxAmt) : 0

                    Button(action: {
                        Haptics.impact(.light)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedMonth = isSelected ? nil : month.label
                        }
                    }) {
                        VStack(spacing: 6) {
                            Spacer(minLength: 0)

                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(red: 243/255, green: 244/255, blue: 246/255))
                                    .frame(height: 72)

                                if month.amount > 0 {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(
                                            (isSelected || isCurrentMonth)
                                                ? Color.spentGreen
                                                : Color.spentGreenSoft
                                        )
                                        .frame(height: max(frac * 72, 8))
                                        .scaleEffect(isSelected ? 1.06 : 1.0)
                                }
                            }

                            Text(month.label)
                                .font(.system(size: 9.5, weight: (isCurrentMonth || isSelected) ? .bold : .medium, design: .default))
                                .foregroundColor((isCurrentMonth || isSelected) ? Color.deepNavy : Color.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .bouncyPress(scale: 0.94)
                }
            }
            .frame(height: 112)
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)
        .padding(.horizontal, 16)
    }

    // MARK: - Management Menu Card (Inset Grouped)

    private var managementMenuCard: some View {
        VStack(spacing: 0) {
            menuRow(
                title: l10n.language == .hebrew ? "סיכומי חודש • Monthly Recaps" : "Monthly Recaps Archive",
                subtitle: l10n.language == .hebrew ? "צפייה בסיפורי העיר וההוצאות בכל חודש" : "View city growth and spending stories",
                iconBg: Color.themeTurquoiseSoft
            ) {
                MoneyIcon(.receipt, size: 24)
            } action: {
                showRecapArchive = true
            }

            Divider().background(Color.borderSubtle).padding(.leading, 68)

            menuRow(
                title: l10n.language == .hebrew ? "תקציב חודשי" : "Monthly Budget",
                subtitle: l10n.language == .hebrew ? "ניהול תקרות הוצאה לפי קטגוריה" : "Manage spending limits by category",
                iconBg: Color(red: 243/255, green: 232/255, blue: 255/255)
            ) {
                MoneyIcon(.barChart, size: 24)
            } action: {
                showBudgetsSheet = true
            }

            Divider().background(Color.borderSubtle).padding(.leading, 68)

            menuRow(
                title: l10n.language == .hebrew ? "יעדי חיסכון" : "Savings Goals",
                subtitle: l10n.language == .hebrew ? "מעקב אחר התקדמות החיסכון שלך" : "Track your savings progress",
                iconBg: Color(red: 209/255, green: 250/255, blue: 229/255)
            ) {
                MoneyIcon(.coins, size: 24)
            } action: {
                showGoalsSheet = true
            }

            Divider().background(Color.borderSubtle).padding(.leading, 68)

            menuRow(
                title: l10n.language == .hebrew ? "הוצאות קבועות ומנויים" : "Fixed Expenses & Subscriptions",
                subtitle: l10n.language == .hebrew ? "שכירות, חשבונות והוראות קבע" : "Rent, utilities, recurring charges",
                iconBg: Color(red: 254/255, green: 242/255, blue: 232/255)
            ) {
                MoneyIcon(.refresh, size: 24)
            } action: {
                showRecurringSheet = true
            }

            Divider().background(Color.borderSubtle).padding(.leading, 68)

            menuRow(
                title: l10n.language == .hebrew ? "הגדרת קליטת Apple Pay באייפון" : "Apple Pay Shortcuts Setup",
                subtitle: l10n.language == .hebrew ? "מדריך פשוט צעד-אחר-צעד לחיבור אוטומטי" : "Step-by-step automation guide",
                iconBg: Color(red: 254/255, green: 240/255, blue: 245/255)
            ) {
                MoneyIcon(.creditCard, size: 24)
            } action: {
                showApplePayGuideSheet = true
            }

            Divider().background(Color.borderSubtle).padding(.leading, 68)

            menuRow(
                title: l10n.language == .hebrew ? "גיבוי ושחזור" : "Backup & Restore",
                subtitle: l10n.language == .hebrew
                    ? "ייצוא הנתונים לקובץ, שחזור מקובץ, ותצלומים אוטומטיים"
                    : "Export to a file, restore from one, and automatic snapshots",
                iconBg: Color(red: 243/255, green: 244/255, blue: 246/255)
            ) {
                MoneyIcon(.cloud, size: 24)
            } action: {
                showBackupSheet = true
            }

            Divider().background(Color.borderSubtle).padding(.leading, 68)

            menuRow(
                title: l10n.language == .hebrew ? "הדרכת פתיחה והיכרות" : "Welcome & Onboarding",
                subtitle: l10n.language == .hebrew
                    ? "סיור היכרות בעיר, הגדרת יעד והאוטומציה"
                    : "City tour, spending target, and automation guide",
                iconBg: Color(red: 236/255, green: 253/255, blue: 245/255)
            ) {
                MoneyIcon(.citySkyline, size: 24)
            } action: {
                showOnboardingTour = true
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)
        .padding(.horizontal, 16)
    }

    private func menuRow<IconContent: View>(
        title: String,
        subtitle: String,
        iconBg: Color,
        @ViewBuilder icon: () -> IconContent,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(iconBg)
                        .frame(width: 42, height: 42)
                    icon()
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .foregroundColor(Color.deepNavy)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(Color.textSecondary)
                }

                Spacer()

                MoneyIcon(
                    l10n.language == .hebrew ? .chevronLeft : .chevronRight,
                    size: 12,
                    color: Color.textMuted
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .bouncyPress(scale: 0.98)
    }

    private func shortAmt(_ v: Double) -> String {
        v >= 1000 ? String(format: "%.1fK", v/1000) : "\(Int(v))"
    }
}


