import SwiftUI
import SwiftData

/// Income and per-category ceilings — the two numbers everything else in the app leans on.
public struct BudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager

    @Query(sort: \IncomeSource.createdAt) private var incomeSources: [IncomeSource]
    @Query private var budgets: [CategoryBudget]
    @Query(sort: \Transaction.timestamp, order: .reverse) private var allTransactions: [Transaction]

    @AppStorage("monthly_budget") private var userMonthlyBudget: Double = 0

    @State private var drafts: [String: String] = [:]
    @State private var overallDraft: String = ""
    @State private var newIncomeName: String = ""
    @State private var newIncomeAmount: String = ""
    @State private var showIncomeEditor = false

    private let sheetBg = Color(red: 248/255, green: 250/255, blue: 252/255)

    public init() {}

    private var isHebrew: Bool { l10n.language == .hebrew }
    private var symbol: String { l10n.baseCurrency.symbol }

    /// Categories worth a ceiling — savings is a transfer, not spending.
    private var budgetableCategories: [SpendingCategory] {
        SpendingCategory.primaryCategories.filter { $0.canonical != .savings }
    }

    private var monthTransactions: [Transaction] {
        let cal = Calendar.current
        return allTransactions.filter { cal.isDate($0.timestamp, equalTo: Date(), toGranularity: .month) }
    }

    private var income: Double { BudgetService.expectedMonthlyIncome(incomeSources) }
    private var spendByCategory: [SpendingCategory: Double] { BudgetService.spentByCategory(monthTransactions) }
    private var spentThisMonth: Double { BudgetService.totalSpent(monthTransactions) }

    /// The ceilings as they are being typed, not as they were last saved — so the header
    /// answers to the keyboard rather than lagging a save behind it.
    private var draftedCeilings: Double {
        budgetableCategories.reduce(0.0) { sum, cat in
            sum + (TransactionIngest.normalizedAmount(nil, drafts[cat.rawValue] ?? "") ?? 0)
        }
    }

    private var draftedOverall: Double {
        TransactionIngest.normalizedAmount(nil, overallDraft) ?? 0
    }

    /// The number the city, the profile ring and the recap all read. Mirrors
    /// `BudgetService.monthlySpendingBudget`, but from the drafts, so the page shows the
    /// consequence of an edit while it is being made.
    private var plannedSpending: Double {
        draftedCeilings > 0 ? draftedCeilings : draftedOverall
    }

    private enum PlanBasis { case ceilings, overall, none }

    private var planBasis: PlanBasis {
        if draftedCeilings > 0 { return .ceilings }
        if draftedOverall > 0 { return .overall }
        return .none
    }

    /// Share of the month already gone, by completed days — the same clock the city uses.
    private var monthElapsed: Double {
        CitySimulationEngine.budgetAccruedFraction(for: Date(), now: Date())
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                sheetBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        summaryCard
                        incomeCard
                        budgetsCard
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle(isHebrew ? "תקציב והכנסות" : "Budget & Income")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.text(for: "close")) { commitDrafts(); dismiss() }
                        .foregroundColor(Color.primaryBlue)
                }
                // The sheet used to commit only from the close button, so swiping it down —
                // which is how most people dismiss a sheet — threw away everything typed.
                ToolbarItem(placement: .confirmationAction) {
                    Button(isHebrew ? "שמור" : "Save") { commitDrafts(); dismiss() }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color.primaryBlue)
                }
            }
            .onAppear(perform: loadDrafts)
            // Belt and braces: a swipe-down, a background tap, or the app being backgrounded
            // all still persist what the user typed.
            .onDisappear(perform: commitDrafts)
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                figure(isHebrew ? "הכנסה חודשית" : "Monthly income", income, Color.themeMint)
                Divider().frame(height: 34)
                figure(isHebrew ? "תקציב הוצאות" : "Spending plan", plannedSpending, Color.primaryBlue)
                Divider().frame(height: 34)
                figure(isHebrew ? "הוצאת עד כה" : "Spent so far", spentThisMonth, paceColor)
            }

            // Where the plan came from. Without this the page looked like it controlled
            // something it did not, which is what made it feel broken.
            noteRow(icon: planIcon, text: planExplanation, color: planBasis == .none ? Color.themeYellow : Color.slate400)

            if plannedSpending > 0 {
                noteRow(icon: paceIcon, text: paceExplanation, color: paceColor)
            }

            if income > 0 && plannedSpending > income {
                noteRow(
                    icon: "exclamationmark.triangle.fill",
                    text: isHebrew
                        ? "התוכנית גדולה מההכנסה ב-\(l10n.format(amount: (plannedSpending - income).rounded()))"
                        : "The plan exceeds income by \(l10n.format(amount: (plannedSpending - income).rounded()))",
                    color: Color.red
                )
            } else if income > 0 && plannedSpending > 0 {
                noteRow(
                    icon: "checkmark.circle.fill",
                    text: isHebrew
                        ? "\(l10n.format(amount: (income - plannedSpending).rounded())) נשארים לחיסכון אם תעמוד בתוכנית"
                        : "\(l10n.format(amount: (income - plannedSpending).rounded())) left to save if you keep to the plan",
                    color: Color.themeMint
                )
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.slate200, lineWidth: 1))
    }

    private func noteRow(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundColor(color)
    }

    private var planIcon: String {
        switch planBasis {
        case .ceilings: return "list.bullet"
        case .overall:  return "target"
        case .none:     return "questionmark.circle.fill"
        }
    }

    private var planExplanation: String {
        switch planBasis {
        case .ceilings:
            return isHebrew
                ? "התוכנית היא סכום התקרות שהגדרת לקטגוריות. זה המספר שהעיר והפארק נמדדים מולו."
                : "The plan is the sum of the ceilings you set below. This is the number the city and the park are measured against."
        case .overall:
            return isHebrew
                ? "התוכנית היא הסכום החודשי הכולל שהגדרת. תקרה לקטגוריה תחליף אותו."
                : "The plan is the overall monthly figure you set. Any category ceiling replaces it."
        case .none:
            return isHebrew
                ? "לא הגדרת תוכנית, אז העיר נמדדת מול הממוצע של החודשים הקודמים שלך."
                : "No plan set, so the city is measured against the average of your previous months."
        }
    }

    /// Pace, not the raw total: two thirds of the budget on the fifth of the month is a very
    /// different month from two thirds on the twenty-fifth.
    private var expectedByNow: Double { plannedSpending * monthElapsed }

    private var paceIcon: String {
        if expectedByNow <= 0 { return "clock" }
        return spentThisMonth > expectedByNow ? "hare.fill" : "tortoise.fill"
    }

    private var paceColor: Color {
        guard plannedSpending > 0, expectedByNow > 0 else { return Color.deepNavy }
        let ratio = spentThisMonth / expectedByNow
        if ratio > 1.15 { return Color.red }
        if ratio > 1.0  { return Color.themeYellow }
        return Color.themeMint
    }

    private var paceExplanation: String {
        let pct = Int((monthElapsed * 100).rounded())
        guard expectedByNow > 0 else {
            return isHebrew
                ? "החודש רק התחיל — עוד אין מה למדוד מולו."
                : "The month has only just started — nothing to measure against yet."
        }
        let diff = (spentThisMonth - expectedByNow).rounded()
        if diff > 0 {
            return isHebrew
                ? "עברו \(pct)% מהחודש והוצאת \(l10n.format(amount: diff)) מעבר לקצב."
                : "\(pct)% of the month has passed and you are \(l10n.format(amount: diff)) ahead of pace."
        }
        return isHebrew
            ? "עברו \(pct)% מהחודש ואתה \(l10n.format(amount: -diff)) מתחת לקצב."
            : "\(pct)% of the month has passed and you are \(l10n.format(amount: -diff)) under pace."
    }

    private func figure(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Color.slate400)
            Text("\(l10n.format(amount: value.rounded()))")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Income

    private var incomeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isHebrew ? "מקורות הכנסה" : "Income sources")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                Spacer()
                Button { showIncomeEditor.toggle() } label: {
                    ZStack {
                        Circle()
                            .fill(Color.primaryBlue.opacity(0.12))
                            .frame(width: 26, height: 26)
                        Image(systemName: showIncomeEditor ? "minus" : "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.primaryBlue)
                    }
                }
                .buttonStyle(.plain)
            }

            if incomeSources.isEmpty && !showIncomeEditor {
                Text(isHebrew
                     ? "בלי הכנסה, כל חישוב החיסכון נשען על מספר שהאפליקציה המציאה."
                     : "Without income, the savings figure rests on a number the app invented.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(Color.slate400)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(incomeSources) { source in
                HStack(spacing: 10) {
                    Image(systemName: "banknote.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.themeMint)
                    Text(source.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("\(l10n.format(amount: source.amount.rounded()))")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                    Button {
                        modelContext.delete(source)
                        try? modelContext.save()
                        Haptics.impact(.light)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.slate300)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 6)
            }

            if showIncomeEditor {
                HStack(spacing: 8) {
                    TextField(isHebrew ? "משכורת" : "Salary", text: $newIncomeName)
                        .font(.system(size: 14, design: .rounded))
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(sheetBg).clipShape(RoundedRectangle(cornerRadius: 10))

                    #if os(iOS)
                    TextField("0", text: $newIncomeAmount)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .frame(width: 90)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(sheetBg).clipShape(RoundedRectangle(cornerRadius: 10))
                    #else
                    TextField("0", text: $newIncomeAmount)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(width: 90)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(sheetBg).clipShape(RoundedRectangle(cornerRadius: 10))
                    #endif

                    Button(isHebrew ? "הוסף" : "Add") { addIncome() }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(canAddIncome ? Color.primaryBlue : Color.slate300)
                        .disabled(!canAddIncome)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.slate200, lineWidth: 1))
    }

    private var canAddIncome: Bool {
        !newIncomeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (TransactionIngest.normalizedAmount(nil, newIncomeAmount) ?? 0) > 0
    }

    private func addIncome() {
        guard let amount = TransactionIngest.normalizedAmount(nil, newIncomeAmount), amount > 0 else { return }
        let source = IncomeSource(
            name: newIncomeName.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            currency: symbol
        )
        modelContext.insert(source)
        try? modelContext.save()
        newIncomeName = ""
        newIncomeAmount = ""
        showIncomeEditor = false
        Haptics.notify(.success)
    }

    // MARK: - Budgets

    private var budgetsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isHebrew ? "תקציב חודשי" : "Monthly budget")
                .font(.system(size: 15, weight: .black, design: .rounded))

            // This used to live alone in Settings, where nothing on this page reflected it.
            overallRow

            Text(isHebrew
                 ? "או פרט לפי קטגוריה — כל תקרה שתמלא כאן מחליפה את הסכום הכולל."
                 : "Or break it down by category — any ceiling you fill in here replaces the overall figure.")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(Color.slate400)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(budgetableCategories) { cat in
                budgetRow(cat)
                if cat != budgetableCategories.last { Divider() }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.slate200, lineWidth: 1))
    }

    private var overallRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "target")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(draftedCeilings > 0 ? Color.slate300 : Color.primaryBlue)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(isHebrew ? "סכום כולל" : "Overall")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                if draftedCeilings > 0 {
                    Text(isHebrew ? "לא בשימוש — התקרות למטה גוברות" : "Not in use — the ceilings below take over")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(Color.slate400)
                }
            }
            Spacer()
            Text(symbol)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Color.slate400)

            #if os(iOS)
            TextField("—", text: $overallDraft)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(width: 76)
                .padding(.vertical, 6)
                .background(sheetBg)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            #else
            TextField("—", text: $overallDraft)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(width: 76)
                .padding(.vertical, 6)
                .background(sheetBg)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            #endif
        }
        .opacity(draftedCeilings > 0 ? 0.55 : 1.0)
        .padding(.vertical, 5)
    }

    private func budgetRow(_ cat: SpendingCategory) -> some View {
        let spent = spendByCategory[cat.canonical] ?? 0
        let limit = TransactionIngest.normalizedAmount(nil, drafts[cat.rawValue] ?? "") ?? 0
        let usage = BudgetUsage(category: cat, limit: limit, spent: spent)

        return VStack(spacing: 7) {
            HStack(spacing: 10) {
                CategoryVectorIcon(category: cat, size: 18)
                Text(cat.localizedName(for: l10n.language))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Text(symbol)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.slate400)

                #if os(iOS)
                TextField("—", text: draftBinding(cat))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 76)
                    .padding(.vertical, 6)
                    .background(sheetBg)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                #else
                TextField("—", text: draftBinding(cat))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(width: 76)
                    .padding(.vertical, 6)
                    .background(sheetBg)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                #endif
            }

            if limit > 0 {
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(sheetBg).frame(height: 6)
                            Capsule()
                                .fill(barColor(usage.status))
                                .frame(width: max(4, geo.size.width * usage.fraction), height: 6)
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Text("\(l10n.format(amount: spent.rounded())) \(isHebrew ? "מתוך" : "of") \(l10n.format(amount: limit.rounded()))")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.slate400)
                        Spacer()
                        Text(statusLabel(usage))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(barColor(usage.status))
                    }
                }
            }
        }
        .padding(.vertical, 5)
    }

    private func draftBinding(_ cat: SpendingCategory) -> Binding<String> {
        Binding(
            get: { drafts[cat.rawValue] ?? "" },
            set: { drafts[cat.rawValue] = $0 }
        )
    }

    private func barColor(_ status: BudgetStatus) -> Color {
        switch status {
        case .over: return Color.red
        case .approaching: return Color.themeYellow
        default: return Color.themeMint
        }
    }

    private func statusLabel(_ usage: BudgetUsage) -> String {
        switch usage.status {
        case .over:
            return isHebrew ? "חריגה של \(l10n.format(amount: usage.overspend.rounded()))" : "\(l10n.format(amount: usage.overspend.rounded())) over"
        case .approaching:
            return isHebrew ? "נשאר \(l10n.format(amount: usage.remaining.rounded()))" : "\(l10n.format(amount: usage.remaining.rounded())) left"
        default:
            return isHebrew ? "נשאר \(l10n.format(amount: usage.remaining.rounded()))" : "\(l10n.format(amount: usage.remaining.rounded())) left"
        }
    }

    // MARK: - Persistence

    private func loadDrafts() {
        var map: [String: String] = [:]
        for budget in budgets where budget.monthlyLimit > 0 {
            map[budget.category.rawValue] = String(format: "%.0f", budget.monthlyLimit)
        }
        drafts = map
        overallDraft = userMonthlyBudget > 0 ? String(format: "%.0f", userMonthlyBudget) : ""
    }

    /// Written once on close rather than on every keystroke, so a half-typed "1" never
    /// becomes a ₪1 ceiling that fires an over-budget warning.
    private func commitDrafts() {
        for cat in budgetableCategories {
            let key = cat.canonical
            let typed = drafts[cat.rawValue] ?? ""
            let limit = TransactionIngest.normalizedAmount(nil, typed) ?? 0
            let existing = budgets.first { $0.category.canonical == key }

            if limit > 0 {
                if let existing {
                    existing.monthlyLimit = limit
                } else {
                    modelContext.insert(CategoryBudget(category: key, monthlyLimit: limit))
                }
            } else if let existing {
                modelContext.delete(existing)
            }
        }
        userMonthlyBudget = TransactionIngest.normalizedAmount(nil, overallDraft) ?? 0
        try? modelContext.save()
    }
}
