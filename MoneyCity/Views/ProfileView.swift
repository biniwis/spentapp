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
    @State private var showBudgetsSheet = false
    @State private var showRecurringSheet = false
    @State private var showGoalsSheet = false
    @State private var showApplePayGuideSheet = false
    @State private var showRecapArchive = false
    @State private var showBackupSheet = false
    @State private var selectedMonth: String? = nil

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

                    // ── 4 Bento Metric Tiles (Tactile with live micro-indicators) ──
                    statsGridCard

                    // ── 12-Month Spending Bar Chart (Architectural Styling) ──
                    yearChartCard

                    // ── Management Navigation Menu Cards (Inset Grouped) ──
                    managementMenuCard

                    // ── Unlocked Enrichments ──
                    if !allEnrichments.isEmpty {
                        enrichmentsCard
                    }

                    Spacer(minLength: 120)
                }
            }
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
    }

    // MARK: - User Profile Greeting Card (Mayor Hero Badge)

    private var userProfileCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 254/255, green: 242/255, blue: 232/255))
                    .frame(width: 56, height: 56)
                MoneyIcon(.user, size: 36)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName.isEmpty ? (l10n.language == .hebrew ? "היי, ראש העיר" : "Hey, Mayor") : (l10n.language == .hebrew ? "שלום, \(displayName)" : "Hey, \(displayName)"))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                Text(l10n.language == .hebrew ? "בונים עתיד פיננסי טוב יותר 🌱" : "Building a better financial future 🌱")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundColor(Color.textSecondary)

                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        MoneyIcon(.calendar, size: 12)
                        Text(l10n.language == .hebrew ? "החודש: \(l10n.format(amount: totalThisMonth))" : "This month: \(l10n.format(amount: totalThisMonth))")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color.deepNavy)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color(red: 243/255, green: 244/255, blue: 246/255))
                    .clipShape(Capsule())

                    if activeStreakDays > 0 {
                        HStack(spacing: 3) {
                            Text("⚡️")
                                .font(.system(size: 10))
                            Text("\(activeStreakDays)d")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 209/255, green: 250/255, blue: 229/255))
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

    // MARK: - 4 Bento Metric Tiles (Clean Modern Surfaces)

    private var statsGridCard: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            // 1. Total This Year
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(red: 243/255, green: 232/255, blue: 255/255))
                        .frame(width: 36, height: 36)
                    AnnualVaultVectorIcon(color: Color(red: 168/255, green: 85/255, blue: 247/255))
                        .scaleEffect(0.85)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(l10n.baseCurrency.symbol)\(shortAmt(totalThisYear))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    Text(l10n.language == .hebrew ? "סך הכל השנה" : "Total This Year")
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(Color.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)

            // 2. This Month Transactions
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.themeTurquoiseSoft)
                        .frame(width: 36, height: 36)
                    BarMetricVectorIcon(color: Color.themeTurquoise)
                        .scaleEffect(0.85)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(thisMonthTransactions.count)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    Text(l10n.language == .hebrew ? "עסקאות החודש" : "Transactions")
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(Color.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)

            // 3. Active Streak 🔥
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.themeOrangeSoft)
                        .frame(width: 36, height: 36)
                    StreakFlameVectorIcon(color: Color.themeOrange)
                        .scaleEffect(0.85)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(activeStreakDays) " + (l10n.language == .hebrew ? "ימים" : "days"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    Text(l10n.language == .hebrew ? "רצף ימים פעיל" : "Active Streak")
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(Color.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)

            // 4. Budget Goal 🎯 (with Live Micro Progress Bar)
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.themeMintSoft)
                        .frame(width: 36, height: 36)
                    TargetReticleVectorIcon(color: Color(red: 16/255, green: 185/255, blue: 129/255))
                        .scaleEffect(0.85)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(budgetGoalText)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)

                    let limit = effectiveBudgetLimit
                    let fraction = limit > 0 ? min(totalThisMonth / limit, 1.0) : 0.0
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(red: 243/255, green: 244/255, blue: 246/255))
                            Capsule().fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                                .frame(width: geo.size.width * CGFloat(fraction))
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 2)

                    Text(l10n.language == .hebrew ? "יעד תקציב חודשי" : "Monthly Budget")
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundColor(Color.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 12-Month Spending Bar Chart (Lilac / Purple Architectural Styling)

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
                        .foregroundColor(Color(red: 168/255, green: 85/255, blue: 247/255))
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
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(red: 168/255, green: 85/255, blue: 247/255))
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
                        .foregroundColor(Color(red: 168/255, green: 85/255, blue: 247/255))
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
                                                ? Color(red: 168/255, green: 85/255, blue: 247/255)
                                                : Color(red: 221/255, green: 214/255, blue: 254/255)
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
                title: l10n.language == .hebrew ? "תקציבים ויעדים חודשיים" : "Budgets & Monthly Targets",
                subtitle: l10n.language == .hebrew ? "ניהול תקרות הוצאה לפי רובע" : "Manage spending caps by district",
                iconBg: Color(red: 243/255, green: 232/255, blue: 255/255)
            ) {
                MoneyIcon(.barChart, size: 24)
            } action: {
                showBudgetsSheet = true
            }

            Divider().background(Color.borderSubtle).padding(.leading, 68)

            menuRow(
                title: l10n.language == .hebrew ? "יעדי חיסכון והשקעה" : "Savings & Growth Goals",
                subtitle: l10n.language == .hebrew ? "מעקב אחר חסכונות ושמורת הפארק" : "Track nature park savings reserves",
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

    // MARK: - Enrichments Card

    private var enrichmentsCard: some View {
        let activeEnrichments = allEnrichments.filter { $0.isApplied }
        return VStack(alignment: .leading, spacing: 14) {
            Text(l10n.language == .hebrew ? "שדרוגי עיר שנפתחו" : "City Upgrades Unlocked")
                .font(.system(size: 16, weight: .bold, design: .default))
                .foregroundColor(Color.deepNavy)

            if activeEnrichments.isEmpty {
                VStack(spacing: 8) {
                    DistrictSkylineVectorIcon(color: Color.primaryBlue)
                        .frame(width: 32, height: 32)
                        .scaleEffect(1.2)
                    Text(l10n.language == .hebrew ? "שמור כסף בפארק החודש כדי לפתוח שדרוגים מיוחדים!" : "Save money in your park this month to unlock special monuments!")
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(activeEnrichments) { e in
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(enrichmentSoftBg(for: e.type))
                                    .frame(width: 48, height: 48)
                                enrichmentBadgeIcon(for: e)
                            }
                            Text(e.name)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 248/255, green: 250/255, blue: 252/255))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.02), radius: 4, y: 1)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func enrichmentBadgeIcon(for e: CityEnrichment) -> some View {
        EnrichmentVectorBadge(enrichment: e)
    }


    private func enrichmentSoftBg(for type: EnrichmentType) -> Color {
        switch type {
        case .nature: return Color.themeMintSoft
        case .resident: return Color.themeTurquoiseSoft
        case .pet: return Color.themeOrangeSoft
        case .decoration: return Color.themeLavenderSoft
        case .repair: return Color(red: 238/255, green: 242/255, blue: 255/255)
        case .landmark: return Color.themeYellowSoft
        }
    }

    private func shortAmt(_ v: Double) -> String {
        v >= 1000 ? String(format: "%.1fK", v/1000) : "\(Int(v))"
    }
}

// MARK: - Dedicated Settings Sheet Modal

public struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager
    @Query private var allTransactions: [Transaction]

    @AppStorage("userName") private var userName = ""
    @AppStorage("notifications_enabled") private var notificationsEnabled = true
    @AppStorage("haptics_enabled") private var hapticsEnabled = true
    
    @State private var showResetConfirmation = false

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // 1. Language & Currency
                        settingsGroup(title: l10n.language == .hebrew ? "שפה ומטבעות" : "Language & Currency") {
                            // The English translation is not finished: the onboarding wizard, the
                            // month header on the City screen, every Siri and Shortcuts action and
                            // the transaction-capture notifications are all Hebrew-only. Offering
                            // the switch would send an English user into a Hebrew setup flow for
                            // the app's headline feature. The picker comes back when the
                            // translation does; the setting itself still works underneath.
                            #if DEBUG
                            HStack {
                                Text(l10n.language == .hebrew ? "שפת ממשק" : "Interface Language")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                Spacer()
                                Picker("", selection: $l10n.language) {
                                    ForEach(AppLanguage.allCases) { lang in
                                        Text(lang.displayName).tag(lang)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 170)
                            }
                            .padding(.vertical, 4)

                            Divider().background(Color.borderSubtle).padding(.vertical, 4)
                            #endif

                            HStack {
                                Text(l10n.language == .hebrew ? "מטבע ראשי" : "Base Currency")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                Spacer()
                                Picker("", selection: $l10n.baseCurrency) {
                                    ForEach(CurrencyType.allCases) { cur in
                                        Text("\(cur.symbol) \(cur.rawValue)").tag(cur)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Color.primaryBlue)
                            }
                            .padding(.vertical, 4)

                            Divider().background(Color.borderSubtle).padding(.vertical, 4)

                            Toggle(isOn: $l10n.autoConvertForeign) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(l10n.language == .hebrew ? "המרה אוטומטית לעסקאות מט״ח" : "Auto Convert FX")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.deepNavy)
                                    Text(l10n.language == .hebrew ? "עדכון שערי יציג חי של בנק ישראל" : "Live Bank of Israel rates")
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundColor(Color.textMuted)
                                }
                            }
                            .tint(Color.primaryBlue)
                            .padding(.vertical, 4)
                        }

                        // 2. User & Monthly Budget
                        settingsGroup(title: l10n.language == .hebrew ? "פרופיל ותקציב" : "User & Budget") {
                            HStack(spacing: 12) {
                                Text(l10n.language == .hebrew ? "שם המשתמש" : "User Name")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                Spacer()
                                TextField(l10n.language == .hebrew ? "שם" : "Name", text: $userName)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(Color.primaryBlue)
                            }
                            .padding(.vertical, 4)

                            Divider().background(Color.borderSubtle).padding(.vertical, 4)

                            // The budget used to be editable here as well as on the budget
                            // screen, and the two disagreed about what a budget even was.
                            // It now has exactly one home.
                            HStack(spacing: 12) {
                                Text(l10n.language == .hebrew ? "יעד תקציב חודשי" : "Monthly Budget Target")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                Spacer()
                                Text(l10n.language == .hebrew ? "במסך התקציב" : "On the budget screen")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.textMuted)
                            }
                            .padding(.vertical, 4)
                        }

                        // 3. Notifications & Haptics
                        settingsGroup(title: l10n.language == .hebrew ? "העדפות ממשק" : "Preferences") {
                            Toggle(isOn: $notificationsEnabled) {
                                Text(l10n.language == .hebrew ? "התראות על הוצאות חדשות" : "Expense Notifications")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                            }
                            .tint(Color.primaryBlue)
                            // NotificationService.sync was only ever called at launch, so the
                            // switch did nothing until the app was next opened cold: turning it
                            // off left the weekly reminder scheduled, and turning it on never
                            // raised the permission prompt — a first-time user flipped it, saw
                            // nothing happen, and got no notifications.
                            .onChange(of: notificationsEnabled) { _, isOn in
                                NotificationService.sync(
                                    enabled: isOn,
                                    isHebrew: l10n.language == .hebrew
                                )
                            }
                            .padding(.vertical, 4)

                            Divider().background(Color.borderSubtle).padding(.vertical, 4)

                            Toggle(isOn: $hapticsEnabled) {
                                Text(l10n.language == .hebrew ? "רטט פידבק (Haptics)" : "Haptic Feedback")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                            }
                            .tint(Color.primaryBlue)
                            .padding(.vertical, 4)
                        }

                        // 4. Danger Zone
                        settingsGroup(title: l10n.language == .hebrew ? "אזור איפוס נתונים" : "Data Management") {
                            Button(role: .destructive, action: { showResetConfirmation = true }) {
                                HStack(spacing: 8) {
                                    TrashVectorIcon(color: Color.red)
                                    Text(l10n.language == .hebrew ? "איפוס כל העסקאות והנתונים" : "Reset All Transactions & Data")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                    Spacer()
                                }
                                .foregroundColor(Color.red)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle(l10n.language == .hebrew ? "הגדרות" : "Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.language == .hebrew ? "סגור" : "Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color.primaryBlue)
                }
            }
            .confirmationDialog(
                l10n.language == .hebrew ? "האם אתה בטוח שברצונך לאפס את כל הנתונים?" : "Are you sure you want to reset all data?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                // This used to delete transactions only, while the dialog promised to erase
                // everything — leaving the earned city, the split-payment plans, the ingest
                // log and the merchant rules the app had learned about the user still in
                // place. DatabaseService.resetAllData draws the line properly and, until
                // now, nothing called it.
                Button(l10n.language == .hebrew ? "מחק הכל ואפס" : "Delete & Reset", role: .destructive) {
                    Task {
                        try? await DatabaseService.shared.resetAllData()
                        await MainActor.run { Haptics.notify(.warning) }
                    }
                }
                Button(l10n.language == .hebrew ? "ביטול" : "Cancel", role: .cancel) {}
            } message: {
                // Say what survives. A destructive action that is vague about its scope is
                // one the user either fears or is surprised by afterwards.
                Text(l10n.language == .hebrew
                     ? "כל העסקאות, העיר שבנית, התשלומים והכללים שהאפליקציה למדה יימחקו. התקציב, ההכנסות, ההוצאות הקבועות ויעדי החיסכון יישארו — היעדים יתאפסו לאפס."
                     : "Every transaction, the city you built, your instalment plans and the rules the app learned will be deleted. Your budget, income, recurring expenses and savings goals stay — the goals reset to zero.")
            }
        }
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Color.textMuted)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Bespoke Profile & Management Vector Icons (Signature Set)

/// 1. Settings Precision Cog / Dial
public struct SettingsGearVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.deepNavy) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.gear, size: 22, color: color)
    }
}

/// 2. Annual Vault / Double Coin Vector Token
public struct AnnualVaultVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeLavender) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.coins, size: 24, color: color)
    }
}

/// 3. Metric 3-Bar Histogram
public struct BarMetricVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeTurquoise) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.barChart, size: 24, color: color)
    }
}

/// 4. Active Streak Vector Flame
public struct StreakFlameVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeOrange) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.flame, size: 24, color: color)
    }
}

/// 5. Budget Target Reticle Vector
public struct TargetReticleVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeMint) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.target, size: 24, color: color)
    }
}

/// 6. Classical Treasury / Budgets Facade
public struct TreasuryVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeLavender) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.trophy, size: 24, color: color)
    }
}

/// 7. Recurring Fixed Expenses Calendar Flip-Pad
public struct RecurringCalendarVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeOrange) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.calendar, size: 24, color: color)
    }
}


/// 9. Bespoke City Enrichment Vector Badges
public struct EnrichmentVectorBadge: View {
    public let enrichment: CityEnrichment
    
    public var body: some View {
        let name = enrichment.name.lowercased()
        
        if name.contains("סקורה") || name.contains("sakura") || name.contains("פרח") {
            // Sakura Botanical Tree
            ZStack {
                Circle().fill(Color(red: 244/255, green: 114/255, blue: 182/255)).frame(width: 14, height: 14).offset(x: -4, y: -2)
                Circle().fill(Color(red: 251/255, green: 146/255, blue: 60/255).opacity(0.8)).frame(width: 12, height: 12).offset(x: 4, y: -3)
                Circle().fill(Color(red: 236/255, green: 72/255, blue: 153/255)).frame(width: 15, height: 15).offset(x: 0, y: -5)
                RoundedRectangle(cornerRadius: 1).fill(Color(red: 120/255, green: 53/255, blue: 15/255)).frame(width: 3.5, height: 9).offset(y: 6)
            }
            .frame(width: 28, height: 28)
        } else if name.contains("ספסל") || name.contains("bench") {
            // Park Bench
            ZStack {
                // Backrest
                RoundedRectangle(cornerRadius: 1).fill(Color(red: 180/255, green: 83/255, blue: 9/255)).frame(width: 18, height: 4).offset(y: -4)
                // Seat slat
                RoundedRectangle(cornerRadius: 1).fill(Color(red: 217/255, green: 119/255, blue: 6/255)).frame(width: 20, height: 3).offset(y: 1)
                // Legs
                HStack(spacing: 12) {
                    Rectangle().fill(Color.deepNavy).frame(width: 2, height: 7)
                    Rectangle().fill(Color.deepNavy).frame(width: 2, height: 7)
                }
                .offset(y: 5)
            }
            .frame(width: 28, height: 28)
        } else if name.contains("פנס") || name.contains("lamp") {
            // Victorian Street Lantern
            ZStack {
                Rectangle().fill(Color.deepNavy).frame(width: 2, height: 16).offset(y: 4)
                TriangleShape().fill(Color.deepNavy).frame(width: 11, height: 5).offset(y: -7)
                RoundedRectangle(cornerRadius: 1).fill(Color(red: 251/255, green: 191/255, blue: 36/255)).frame(width: 8, height: 8).offset(y: -2)
            }
            .frame(width: 28, height: 28)
        } else if name.contains("חתול") || name.contains("כלב") || name.contains("ג'ינג'י") || name.contains("pet") {
            // City Pet Mascot
            ZStack {
                // Head
                Circle().fill(Color(red: 245/255, green: 158/255, blue: 11/255)).frame(width: 15, height: 15)
                // Pointed ears
                HStack(spacing: 7) {
                    TriangleShape().fill(Color(red: 217/255, green: 119/255, blue: 6/255)).frame(width: 5, height: 5)
                    TriangleShape().fill(Color(red: 217/255, green: 119/255, blue: 6/255)).frame(width: 5, height: 5)
                }
                .offset(y: -8)
                // White muzzle
                Circle().fill(Color.white).frame(width: 6, height: 4).offset(y: 2)
            }
            .frame(width: 28, height: 28)
        } else if name.contains("ערוגה") || name.contains("פרחים") || name.contains("flower") {
            // Flowerbed Planter
            ZStack {
                // Planter Box
                RoundedRectangle(cornerRadius: 2).fill(Color(red: 5/255, green: 150/255, blue: 105/255)).frame(width: 20, height: 7).offset(y: 5)
                // 3 Floral Stems
                HStack(spacing: 3) {
                    Circle().fill(Color(red: 236/255, green: 72/255, blue: 153/255)).frame(width: 5.5, height: 5.5)
                    Circle().fill(Color(red: 239/255, green: 68/255, blue: 68/255)).frame(width: 6, height: 6).offset(y: -2)
                    Circle().fill(Color(red: 245/255, green: 158/255, blue: 11/255)).frame(width: 5.5, height: 5.5)
                }
                .offset(y: -2)
            }
            .frame(width: 28, height: 28)
        } else {
            DistrictParkVectorIcon(color: Color.themeMint)
                .scaleEffect(0.9)
        }
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Apple Pay Shortcuts Setup Guide Sheet

public struct ApplePayGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager
    
    private var isHebrew: Bool { l10n.language == .hebrew }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.themeTurquoiseSoft)
                                .frame(width: 60, height: 60)
                            DistrictFinanceVectorIcon(color: Color.themeTurquoise)
                                .scaleEffect(1.3)
                        }
                        
                        Text(isHebrew ? "הגדרת קליטת Apple Pay אוטומטית" : "Automatic Apple Pay Setup")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                            .multilineTextAlignment(.center)
                        
                        Text(isHebrew
                             ? "בגלל ש-iOS שומרת על פרטיות, נדרש חיבור קצר באפליקציית 'קיצורים' (Shortcuts) כדי שכל תשלום ייקלט מיד בעיר שלך."
                             : "Due to iOS privacy, a quick Shortcuts automation is required to stream tap-to-pay charges directly into your city.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                    }
                    .padding(.top, 10)
                    
                    // Auto-Installed Notification Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.15))
                                    .frame(width: 44, height: 44)
                                DistrictFinanceVectorIcon(color: Color(red: 16/255, green: 185/255, blue: 129/255))
                                    .scaleEffect(1.1)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isHebrew ? "הפעולות של SPENT כבר מותקנות באייפון!" : "SPENT actions are already installed!")
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                Text(isHebrew ? "הפעולה מובנית במערכת — נותר רק להפעיל אוטומציה:" : "Built-in to iOS — just enable the 3-step automation:")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.textMuted)
                            }
                        }
                    }
                    .padding(18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)

                    // Simple Step-by-Step Instructions Card
                    VStack(alignment: .leading, spacing: 18) {
                        stepRow(
                            number: "1",
                            title: isHebrew ? "פתח את אפליקציית 'קיצורים' (Shortcuts)" : "Open 'Shortcuts' App",
                            desc: isHebrew ? "עבור ללשונית 'אוטומציה' בתחתית ולחץ על + ליצירת 'אוטומציה אישית'." : "Go to 'Automation' tab and tap + to create a Personal Automation."
                        )
                        
                        stepRow(
                            number: "2",
                            title: isHebrew ? "בחר בטריגר 'עסקה' (Transaction)" : "Select 'Transaction' Trigger",
                            desc: isHebrew ? "ודא שמסומן 'כרטיס כלשהו', ובחר 'הפעל מיד' (ללא אישור ידני)." : "Select 'Any Card' and choose 'Run Immediately' (without confirmation)."
                        )
                        
                        stepRow(
                            number: "3",
                            title: isHebrew ? "הוסף פעולה: 'הקלטת עסקת Apple Pay'" : "Add Action: 'Record Apple Pay Transaction'",
                            desc: isHebrew ? "בחר 'אוטומציה ריקה חדשה' > 'הוסף פעולה' > חפש SPENT ובחר 'הקלטת עסקת Apple Pay'." : "Choose 'New Blank Automation' > 'Add Action' > search SPENT and pick 'Record Apple Pay Transaction'."
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                                        .frame(width: 24, height: 24)
                                    Text("4")
                                        .font(.system(size: 12, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isHebrew ? "חבר את הקלט (סכום ובית עסק 💡)" : "Connect Shortcut Input (💡)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.deepNavy)
                                    Text(isHebrew ? "לחץ על השדות הכחולים וחבר אותם ל'קלט הקיצור':" : "Tap the blue fields to attach 'Shortcut Input':")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(Color.textMuted)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text(isHebrew ? "• לחץ" : "• Tap")
                                        .font(.system(size: 11.5, weight: .medium))
                                    Text(isHebrew ? "[סכום העסקה]" : "[Transaction Amount]")
                                        .font(.system(size: 11.5, weight: .bold))
                                        .foregroundColor(Color.primaryBlue)
                                    Text(isHebrew ? "➔ בחר" : "➔ select")
                                        .font(.system(size: 11.5, weight: .medium))
                                    Text(isHebrew ? "[קלט הקיצור]" : "[Shortcut Input]")
                                        .font(.system(size: 11.5, weight: .bold))
                                        .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                                    Text(isHebrew ? "(סכום)" : "(Amount)")
                                        .font(.system(size: 11.5, weight: .semibold))
                                }
                                HStack(spacing: 4) {
                                    Text(isHebrew ? "• לחץ" : "• Tap")
                                        .font(.system(size: 11.5, weight: .medium))
                                    Text(isHebrew ? "[שם בית העסק]" : "[Merchant Name]")
                                        .font(.system(size: 11.5, weight: .bold))
                                        .foregroundColor(Color.primaryBlue)
                                    Text(isHebrew ? "➔ בחר" : "➔ select")
                                        .font(.system(size: 11.5, weight: .medium))
                                    Text(isHebrew ? "[קלט הקיצור]" : "[Shortcut Input]")
                                        .font(.system(size: 11.5, weight: .bold))
                                        .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                                    Text(isHebrew ? "(שם העסק)" : "(Merchant)")
                                        .font(.system(size: 11.5, weight: .semibold))
                                }
                                Text(isHebrew ? "• לחץ 'סיום' (Done) — מעכשיו הכל יקלט אוטומטית! 🎉" : "• Tap 'Done' — and you are all set! 🎉")
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                                    .padding(.top, 2)
                            }
                            .padding(.leading, 36)
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)
                    
                    // Action Links
                    #if os(iOS)
                    VStack(spacing: 10) {
                        if let url = URL(string: "shortcuts://") {
                            Link(destination: url) {
                                HStack(spacing: 8) {
                                    MoneyIcon(.lightning, size: 18)
                                    Text(isHebrew ? "פתח את אפליקציית 'קיצורים' עכשיו" : "Open Shortcuts App Now")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Capsule().fill(Color(red: 16/255, green: 185/255, blue: 129/255)))
                                .shadow(color: Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.3), radius: 8, y: 3)
                            }
                        }
                    }
                    .padding(.top, 6)
                    #endif
                    
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 18)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(isHebrew ? "הגדרת אוטומציה" : "Shortcuts Guide")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.text(for: "close")) { dismiss() }
                        .foregroundColor(Color.primaryBlue)
                }
            }
        }
    }
    
    private func stepRow(number: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primaryBlue)
                    .frame(width: 24, height: 24)
                Text(number)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                Text(desc)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
            }
        }
    }
    
}
