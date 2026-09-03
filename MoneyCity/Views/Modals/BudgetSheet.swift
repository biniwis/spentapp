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

    @State private var drafts: [String: String] = [:]
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
    private var totalBudgeted: Double { budgets.reduce(0) { $0 + $1.monthlyLimit } }
    private var usages: [BudgetUsage] { BudgetService.usages(budgets: budgets, transactions: monthTransactions) }
    private var spendByCategory: [SpendingCategory: Double] { BudgetService.spentByCategory(monthTransactions) }

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
        let unbudgeted = income - totalBudgeted
        return VStack(spacing: 12) {
            HStack {
                figure(isHebrew ? "הכנסה חודשית" : "Monthly income", income, Color.themeMint)
                Divider().frame(height: 34)
                figure(isHebrew ? "סך מתוקצב" : "Budgeted", totalBudgeted, Color.primaryBlue)
            }

            if income > 0 {
                HStack(spacing: 6) {
                    Image(systemName: unbudgeted >= 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(unbudgeted >= 0
                         ? (isHebrew ? "\(l10n.format(amount: unbudgeted.rounded())) עוד לא מתוקצבים" : "\(l10n.format(amount: unbudgeted.rounded())) not yet budgeted")
                         : (isHebrew ? "התקציבים חורגים מההכנסה ב-\(l10n.format(amount: -unbudgeted.rounded()))" : "Budgets exceed income by \(l10n.format(amount: -unbudgeted.rounded()))"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Spacer()
                }
                .foregroundColor(unbudgeted >= 0 ? Color.themeMint : Color.red)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.slate200, lineWidth: 1))
    }

    private func figure(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Color.slate400)
            Text("\(l10n.format(amount: value.rounded()))")
                .font(.system(size: 21, weight: .black, design: .rounded))
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
            Text(isHebrew ? "תקציב חודשי לפי קטגוריה" : "Monthly budget by category")
                .font(.system(size: 15, weight: .black, design: .rounded))

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
        try? modelContext.save()
    }
}
