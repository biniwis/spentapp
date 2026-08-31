import SwiftUI
import SwiftData

public struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager
    @Query(sort: \Transaction.timestamp, order: .reverse) private var allTransactions: [Transaction]
    @Query private var allEnrichments: [CityEnrichment]

    @AppStorage("userName") private var userName = "בן"
    @AppStorage("monthly_budget") private var userMonthlyBudget: Double = 8000.0
    @State private var showSettings = false
    @State private var showBudgetsSheet = false
    @State private var showRecurringSheet = false
    @State private var showGoalsSheet = false
    @State private var showIngestLogSheet = false
    @State private var showApplePayGuideSheet = false
    @State private var selectedMonth: String? = nil

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

    private var totalThisMonth: Double {
        let cal = Calendar.current
        let now = Date()
        return allTransactions.filter {
            cal.isDate($0.timestamp, equalTo: now, toGranularity: .month) && $0.category != .savings
        }.reduce(0) { $0 + $1.amount }
    }

    // Monthly totals for bar chart (last 12 months)
    private var monthlyTotals: [(label: String, amount: Double)] {
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
            return (monthLabel, total)
        }
    }

    private var transactionCount: Int { allTransactions.count }
    private var enrichmentCount: Int { allEnrichments.filter { $0.isApplied }.count }

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // ── Top Header with Settings Gear Button ──
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(l10n.language == .hebrew ? "פרופיל והגדרות" : "Profile")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            Text(l10n.language == .hebrew ? "ניהול החשבון והעדפות המשתמש" : "Manage your account & preferences")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(Color.textMuted)
                        }
                        Spacer()

                        Button(action: { showSettings = true }) {
                            ZStack {
                                Circle()
                                    .fill(Color.cardBackground)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: Color.deepNavy.opacity(0.04), radius: 8, y: 3)
                                    .overlay(Circle().stroke(Color.borderSubtle, lineWidth: 1.2))
                                
                                SettingsGearVectorIcon(color: Color.deepNavy)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // ── User Avatar & City Greeting Card ──
                    userProfileCard

                    // ── 4 Stats Grid (Matching Mockup) ──
                    statsGridCard

                    // ── 12-Month Spending Bar Chart ──
                    yearChartCard

                    // ── Management Navigation Menu Cards ──
                    managementMenuCard

                    // ── Unlocked Enrichments ──
                    if !allEnrichments.isEmpty {
                        enrichmentsCard
                    }

                    Spacer(minLength: 110)
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
        .sheet(isPresented: $showIngestLogSheet) {
            IngestLogSheet()
                .environmentObject(l10n)
        }
        .sheet(isPresented: $showApplePayGuideSheet) {
            ApplePayGuideSheet()
                .environmentObject(l10n)
        }
    }

    // MARK: - User Profile Greeting Card

    private var userProfileCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.themeLavenderSoft)
                    .frame(width: 58, height: 58)
                DistrictSkylineVectorIcon(color: Color.primaryBlue)
                    .scaleEffect(1.3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.language == .hebrew ? "בוקר טוב, \(userName)" : "Good morning, \(userName)")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                
                Text(l10n.language == .hebrew ? "אתה בונה את עיר הכסף שלך" : "You're building your money city")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textMuted)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.borderSubtle, lineWidth: 1.5))
        .shadow(color: Color.deepNavy.opacity(0.04), radius: 10, y: 3)
        .padding(.horizontal, 16)
    }

    // MARK: - 4 Stats Grid Card

    private var statsGridCard: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            statTile(
                label: l10n.language == .hebrew ? "סך הכל השנה" : "Total This Year",
                value: "\(l10n.baseCurrency.symbol)\(shortAmt(totalThisYear))",
                iconBg: Color.themeLavenderSoft
            ) {
                AnnualVaultVectorIcon(color: Color.themeLavender)
            }
            statTile(
                label: l10n.language == .hebrew ? "עסקאות החודש" : "Transactions",
                value: "\(allTransactions.count)",
                iconBg: Color.themeTurquoiseSoft
            ) {
                BarMetricVectorIcon(color: Color.themeTurquoise)
            }
            statTile(
                label: l10n.language == .hebrew ? "רצף ימים פעיל" : "Active Streak",
                value: "14 " + (l10n.language == .hebrew ? "ימים" : "days"),
                iconBg: Color.themeOrangeSoft
            ) {
                StreakFlameVectorIcon(color: Color.themeOrange)
            }
            let budgetPct = userMonthlyBudget > 0 ? Int(min((totalThisMonth / userMonthlyBudget) * 100, 100)) : 0
            statTile(
                label: l10n.language == .hebrew ? "יעד תקציב" : "Budget Goal",
                value: "\(budgetPct)% " + (l10n.language == .hebrew ? "מהיעד" : "of goal"),
                iconBg: Color.themeMintSoft
            ) {
                TargetReticleVectorIcon(color: Color.themeMint)
            }
        }
        .padding(.horizontal, 16)
    }

    private func statTile<IconContent: View>(
        label: String,
        value: String,
        iconBg: Color,
        @ViewBuilder icon: () -> IconContent
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconBg)
                        .frame(width: 32, height: 32)
                    icon()
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.borderSubtle, lineWidth: 1.2))
        .shadow(color: Color.deepNavy.opacity(0.03), radius: 6, y: 2)
    }

    // MARK: - 12-Month Spending Bar Chart

    private var yearChartCard: some View {
        let maxAmt = max(monthlyTotals.map(\.amount).max() ?? 1, 100)
        let peakAmt = monthlyTotals.map(\.amount).max() ?? 0
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(l10n.language == .hebrew ? "הוצאות 12 חודשים" : "12-Month Overview")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                Spacer()
                Text("\(l10n.baseCurrency.symbol)\(shortAmt(totalThisYear))")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(Color.primaryBlue)
            }

            HStack(alignment: .bottom, spacing: 5) {
                ForEach(monthlyTotals, id: \.label) { month in
                    let isPeak = month.amount == peakAmt && peakAmt > 0
                    let isSelected = (selectedMonth == month.label)
                    let frac = maxAmt > 0 ? CGFloat(month.amount / maxAmt) : 0
                    
                    Button(action: {
                        Haptics.impact(.light)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedMonth = isSelected ? nil : month.label
                        }
                    }) {
                        VStack(spacing: 4) {
                            if isSelected {
                                Text("\(l10n.baseCurrency.symbol)\(Int(month.amount))")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.deepNavy)
                                    .clipShape(Capsule())
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Color.clear.frame(height: 14)
                            }
                            
                            Spacer(minLength: 0)
                            
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.borderSubtle)
                                    .frame(height: 70)

                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isSelected ? Color.themeTurquoise : (isPeak ? Color.primaryBlue : Color.primaryBlue.opacity(0.7)))
                                    .frame(height: max(frac * 70, 6))
                                    .scaleEffect(isSelected ? 1.08 : 1.0)
                            }

                            Text(month.label)
                                .font(.system(size: 9, weight: (isSelected || isPeak) ? .black : .bold, design: .rounded))
                                .foregroundColor(isSelected ? Color.themeTurquoise : (isPeak ? Color.primaryBlue : Color.textMuted))
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .bouncyPress(scale: 0.94)
                }
            }
            .frame(height: 110)
        }
        .padding(18)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.borderSubtle, lineWidth: 1.5))
        .shadow(color: Color.deepNavy.opacity(0.04), radius: 10, y: 3)
        .padding(.horizontal, 16)
    }

    // MARK: - Management Menu Card

    private var managementMenuCard: some View {
        VStack(spacing: 0) {
            menuRow(
                title: l10n.language == .hebrew ? "תקציבים ויעדים חודשיים" : "Budgets & Monthly Targets",
                subtitle: l10n.language == .hebrew ? "ניהול תקרות הוצאה לפי רובע" : "Manage spending caps by district",
                iconBg: Color.themeLavenderSoft
            ) {
                TreasuryVectorIcon(color: Color.themeLavender)
            } action: {
                showBudgetsSheet = true
            }

            Divider().background(Color.borderSubtle).padding(.leading, 62)

            menuRow(
                title: l10n.language == .hebrew ? "יעדי חיסכון והשקעה" : "Savings & Growth Goals",
                subtitle: l10n.language == .hebrew ? "מעקב אחר חסכונות ושמורת הפארק" : "Track nature park savings reserves",
                iconBg: Color.themeMintSoft
            ) {
                DistrictParkVectorIcon(color: Color.themeMint)
            } action: {
                showGoalsSheet = true
            }

            Divider().background(Color.borderSubtle).padding(.leading, 62)

            menuRow(
                title: l10n.language == .hebrew ? "הוצאות קבועות ומנויים" : "Fixed Expenses & Subscriptions",
                subtitle: l10n.language == .hebrew ? "שכירות, חשבונות והוראות קבע" : "Rent, utilities, recurring charges",
                iconBg: Color.themeOrangeSoft
            ) {
                RecurringCalendarVectorIcon(color: Color.themeOrange)
            } action: {
                showRecurringSheet = true
            }

            Divider().background(Color.borderSubtle).padding(.leading, 62)

            menuRow(
                title: l10n.language == .hebrew ? "הגדרת קליטת Apple Pay באייפון" : "Apple Pay Shortcuts Setup",
                subtitle: l10n.language == .hebrew ? "מדריך פשוט צעד-אחר-צעד לחיבור אוטומטי" : "Step-by-step automation guide",
                iconBg: Color.themeTurquoiseSoft
            ) {
                DistrictFinanceVectorIcon(color: Color.themeTurquoise)
            } action: {
                showApplePayGuideSheet = true
            }

            Divider().background(Color.borderSubtle).padding(.leading, 62)

            menuRow(
                title: l10n.language == .hebrew ? "יומן קליטה אוטומטי (Apple Pay / OCR)" : "Ingest & Screenshot Log",
                subtitle: l10n.language == .hebrew ? "תיעוד עסקאות שנקלטו אוטומטית" : "Live transaction diagnostics",
                iconBg: Color.themeYellowSoft
            ) {
                ScannerLensVectorIcon(color: Color.themeYellow)
            } action: {
                showIngestLogSheet = true
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.borderSubtle, lineWidth: 1.5))
        .shadow(color: Color.deepNavy.opacity(0.04), radius: 10, y: 3)
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconBg)
                        .frame(width: 40, height: 40)
                    icon()
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textMuted)
                }

                Spacer()

                Text(verbatim: l10n.language == .hebrew ? "‹" : "›")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .bouncyPress(scale: 0.98)
    }

    // MARK: - Enrichments Card

    private var enrichmentsCard: some View {
        let activeEnrichments = allEnrichments.filter { $0.isApplied }
        return VStack(alignment: .leading, spacing: 14) {
            Text(l10n.language == .hebrew ? "שדרוגי עיר שנפתחו" : "City Upgrades Unlocked")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(Color.deepNavy)

            if activeEnrichments.isEmpty {
                VStack(spacing: 8) {
                    DistrictSkylineVectorIcon(color: Color.primaryBlue)
                        .frame(width: 32, height: 32)
                        .scaleEffect(1.2)
                    Text(l10n.language == .hebrew ? "שמור כסף בפארק החודש כדי לפתוח שדרוגים מיוחדים!" : "Save money in your park this month to unlock special monuments!")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(activeEnrichments) { e in
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(enrichmentSoftBg(for: e.type))
                                    .frame(width: 48, height: 48)
                                enrichmentBadgeIcon(for: e)
                            }
                            Text(e.name)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.borderSubtle, lineWidth: 1))
                    }
                }
            }
        }
        .padding(18)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.borderSubtle, lineWidth: 1.5))
        .shadow(color: Color.deepNavy.opacity(0.04), radius: 10, y: 3)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func enrichmentBadgeIcon(for e: CityEnrichment) -> some View {
        EnrichmentVectorBadge(enrichment: e)
    }

    private func fallbackTint(for type: EnrichmentType) -> Color {
        switch type {
        case .nature: return Color.themeMint
        case .resident: return Color.themeTurquoise
        case .pet: return Color.themeOrange
        case .decoration: return Color.themeLavender
        case .repair: return Color.primaryBlue
        case .landmark: return Color.themeYellow
        }
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

    @AppStorage("userName") private var userName = "בן"
    @AppStorage("monthly_budget") private var userMonthlyBudget: Double = 8000.0
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
                            HStack {
                                Text(l10n.language == .hebrew ? "שפת ממשק" : "Interface Language")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                Spacer()
                                Picker("", selection: $l10n.language) {
                                    ForEach(AppLanguage.allCases) { lang in
                                        Text("\(lang.flagEmoji) \(lang.displayName)").tag(lang)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 170)
                            }
                            .padding(.vertical, 4)

                            Divider().background(Color.borderSubtle).padding(.vertical, 4)

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
                                TextField("שם", text: $userName)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(Color.primaryBlue)
                            }
                            .padding(.vertical, 4)
                            
                            Divider().background(Color.borderSubtle).padding(.vertical, 4)
                            
                            HStack(spacing: 12) {
                                Text(l10n.language == .hebrew ? "יעד תקציב חודשי" : "Monthly Budget Target")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                Spacer()
                                HStack(spacing: 4) {
                                    Text(l10n.baseCurrency.symbol)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.primaryBlue)
                                    TextField("8000", value: $userMonthlyBudget, format: .number)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .multilineTextAlignment(.trailing)
                                        .foregroundColor(Color.deepNavy)
                                        .frame(width: 80)
                                }
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
                Button(l10n.language == .hebrew ? "מחק הכל ואפס" : "Delete & Reset", role: .destructive) {
                    for tx in allTransactions {
                        modelContext.delete(tx)
                    }
                    try? modelContext.save()
                    Haptics.notify(.warning)
                }
                Button(l10n.language == .hebrew ? "ביטול" : "Cancel", role: .cancel) {}
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
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.borderSubtle, lineWidth: 1.2))
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Bespoke Profile & Management Vector Icons (Zero Default Apple Emojis)

/// 1. Settings Precision Cog / Dial
public struct SettingsGearVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.deepNavy) { self.color = color }
    
    public var body: some View {
        ZStack {
            // 6 Gear teeth
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: 5, height: 19)
                    .rotationEffect(.degrees(Double(i) * 60))
            }
            
            // Outer gear rim
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
            
            // Center axle hole
            Circle()
                .fill(Color.cardBackground)
                .frame(width: 5.5, height: 5.5)
        }
        .frame(width: 22, height: 22)
    }
}

/// 2. Annual Vault / Double Coin Vector Token
public struct AnnualVaultVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeLavender) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Back coin
            Circle()
                .fill(color.opacity(0.6))
                .frame(width: 15, height: 15)
                .offset(x: -3.5, y: -2)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 0.8)
                        .frame(width: 15, height: 15)
                        .offset(x: -3.5, y: -2)
                )
            
            // Front primary coin
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
                .offset(x: 2.5, y: 2)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 1)
                        .frame(width: 12, height: 12)
                        .offset(x: 2.5, y: 2)
                )
            
            // Center coin glyph
            Rectangle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 2, height: 6)
                .offset(x: 2.5, y: 2)
        }
        .frame(width: 24, height: 24)
    }
}

/// 3. Metric 3-Bar Histogram
public struct BarMetricVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeTurquoise) { self.color = color }
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: 2.5) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color.opacity(0.7))
                .frame(width: 4, height: 8)
            RoundedRectangle(cornerRadius: 1)
                .fill(color.opacity(0.85))
                .frame(width: 4, height: 13)
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 4, height: 18)
        }
        .frame(width: 24, height: 24)
    }
}

/// 4. Active Streak Vector Flame
public struct StreakFlameVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeOrange) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Outer Flame Body
            FlameShape()
                .fill(color)
                .frame(width: 14, height: 18)
            
            // Inner Core Spark
            FlameShape()
                .fill(Color.white.opacity(0.85))
                .frame(width: 7, height: 9)
                .offset(y: 3)
        }
        .frame(width: 24, height: 24)
    }
}

private struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY * 0.7),
            control1: CGPoint(x: rect.maxX * 0.8, y: rect.minY + rect.height * 0.25),
            control2: CGPoint(x: rect.maxX, y: rect.maxY * 0.5)
        )
        p.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY * 0.9),
            control2: CGPoint(x: rect.midX + rect.width * 0.25, y: rect.maxY)
        )
        p.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY * 0.7),
            control1: CGPoint(x: rect.midX - rect.width * 0.25, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.maxY * 0.9)
        )
        p.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.maxY * 0.5),
            control2: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.25)
        )
        p.closeSubpath()
        return p
    }
}

/// 5. Budget Target Reticle Vector
public struct TargetReticleVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeMint) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Outer Ring
            Circle()
                .stroke(color, lineWidth: 2)
                .frame(width: 17, height: 17)
            
            // 4 Reticle Tick Lines
            Rectangle().fill(color).frame(width: 1.8, height: 4).offset(y: -8.5)
            Rectangle().fill(color).frame(width: 1.8, height: 4).offset(y: 8.5)
            Rectangle().fill(color).frame(width: 4, height: 1.8).offset(x: -8.5)
            Rectangle().fill(color).frame(width: 4, height: 1.8).offset(x: 8.5)
            
            // Center Bullseye Dot
            Circle()
                .fill(color)
                .frame(width: 5.5, height: 5.5)
        }
        .frame(width: 24, height: 24)
    }
}

/// 6. Classical Treasury / Budgets Facade
public struct TreasuryVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeLavender) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Triangular Pediment
            TriangleShape()
                .fill(color)
                .frame(width: 20, height: 7)
                .offset(y: -7)
            
            // Entablature bar
            RoundedRectangle(cornerRadius: 0.5)
                .fill(color)
                .frame(width: 19, height: 2)
                .offset(y: -3)
            
            // 3 Classical Pillars
            HStack(spacing: 3.5) {
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(color)
                    .frame(width: 2.8, height: 9)
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(color)
                    .frame(width: 2.8, height: 9)
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(color)
                    .frame(width: 2.8, height: 9)
            }
            .offset(y: 2)
            
            // Base plinth steps
            RoundedRectangle(cornerRadius: 0.8)
                .fill(color)
                .frame(width: 21, height: 2.5)
                .offset(y: 7.5)
        }
        .frame(width: 24, height: 24)
    }
}

/// 7. Recurring Fixed Expenses Calendar Flip-Pad
public struct RecurringCalendarVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeOrange) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Calendar Backplate
            RoundedRectangle(cornerRadius: 3.5)
                .fill(color)
                .frame(width: 18, height: 18)
            
            // Header Bar
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.4))
                .frame(width: 18, height: 4.5)
                .offset(y: -6.75)
            
            // 2 Binder Rings
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 2, height: 4)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 2, height: 4)
            }
            .offset(y: -9)
            
            // Circular Repeat Loop Arrow Inside
            Circle()
                .trim(from: 0.15, to: 0.95)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 8, height: 8)
                .offset(y: 1.5)
        }
        .frame(width: 24, height: 24)
    }
}

/// 8. Ingest Diagnostics Scanner Lens
public struct ScannerLensVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeYellow) { self.color = color }
    
    public var body: some View {
        ZStack {
            // Camera / Scanner Chassis
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 20, height: 15)
                .offset(y: 1)
            
            // Top Sensor Notch
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 7, height: 3)
                .offset(x: -3, y: -7.5)
            
            // Circular Optical Aperture
            Circle()
                .fill(Color.white)
                .frame(width: 9, height: 9)
                .offset(y: 1)
            
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
                .offset(y: 1)
            
            // Laser Scan Horizontal Line
            Rectangle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 16, height: 1.2)
                .offset(y: 1)
        }
        .frame(width: 24, height: 24)
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
                    
                    // Step-by-Step Instructions Card
                    VStack(alignment: .leading, spacing: 16) {
                        stepRow(
                            number: "1",
                            title: isHebrew ? "פתח את אפליקציית 'קיצורים' (Shortcuts)" : "Open the 'Shortcuts' App",
                            desc: isHebrew ? "אפליקציית ברירת המחדל של אפל המותקנת בכל מכשיר iPhone." : "The built-in Apple Shortcuts app on your iPhone."
                        )
                        
                        stepRow(
                            number: "2",
                            title: isHebrew ? "צור אוטומציה חדשה" : "Create New Automation",
                            desc: isHebrew ? "עבור ללשונית 'אוטומציה' (בתחתית) ולחץ על + בפינה." : "Tap the 'Automation' tab at the bottom, then tap + in the corner."
                        )
                        
                        stepRow(
                            number: "3",
                            title: isHebrew ? "בחר בטריגר 'עסקה' (Transaction)" : "Select 'Transaction' Trigger",
                            desc: isHebrew ? "בחר את כרטיסי ה-Apple Pay שלך, וסמן 'הפעל מיד' (Run Immediately) ללא אישור ידני." : "Select your Apple Pay cards and choose 'Run Immediately'."
                        )
                        
                        stepRow(
                            number: "4",
                            title: isHebrew ? "הוסף את הפעולה: 'הקלטת עסקת Apple Pay'" : "Add Action: 'Record Apple Pay Transaction'",
                            desc: isHebrew ? "חפש את MoneyCity והוסף את הפעולה 'הקלטת עסקת Apple Pay'." : "Search for MoneyCity and add 'Record Apple Pay Transaction'."
                        )
                        
                        // Critical mapping highlight box
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Text(verbatim: "⚡")
                                    .font(.system(size: 14))
                                Text(isHebrew ? "השלב החשוב ביותר (חיבור השדות):" : "Crucial Step (Connecting Fields):")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundColor(Color.primaryBlue)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                mappingLine(
                                    field: isHebrew ? "סכום העסקה" : "Amount",
                                    instruction: isHebrew ? "לחץ על 'קלט הקיצור' -> לחץ עליו שוב ובחר 'סכום' (Amount)" : "Tap 'Shortcut Input' -> tap again and select 'Amount'"
                                )
                                mappingLine(
                                    field: isHebrew ? "שם בית העסק" : "Merchant",
                                    instruction: isHebrew ? "לחץ על 'קלט הקיצור' -> לחץ עליו שוב ובחר 'בית עסק' (Merchant)" : "Tap 'Shortcut Input' -> tap again and select 'Merchant'"
                                )
                                mappingLine(
                                    field: isHebrew ? "תאריך ושעה" : "Date",
                                    instruction: isHebrew ? "לחץ על 'קלט הקיצור' -> בחר 'תאריך' (Date)" : "Tap 'Shortcut Input' -> select 'Date'"
                                )
                            }
                        }
                        .padding(14)
                        .background(Color.themeTurquoiseSoft.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primaryBlue.opacity(0.2), lineWidth: 1.2))
                    }
                    .padding(18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.borderSubtle, lineWidth: 1.5))
                    .shadow(color: Color.deepNavy.opacity(0.04), radius: 10, y: 3)
                    
                    // Quick Action Link
                    #if os(iOS)
                    if let url = URL(string: "shortcuts://") {
                        Link(destination: url) {
                            HStack(spacing: 8) {
                                DistrictFinanceVectorIcon(color: Color.white)
                                Text(isHebrew ? "פתח את אפליקציית קיצורים עכשיו" : "Open Shortcuts App Now")
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.primaryBlue)
                            .clipShape(Capsule())
                            .shadow(color: Color.primaryBlue.opacity(0.3), radius: 8, y: 3)
                        }
                        .padding(.top, 6)
                    }
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
    
    private func mappingLine(field: String, instruction: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("• \(field):")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(Color.deepNavy)
            Text("  \(instruction)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color.textMuted)
        }
    }
}
