import SwiftUI
import SwiftData

/// Dedicated Special Menu for the Nature & Savings Sanctuary ("שמורת הטבע והחיסכון").
///
/// Unlike standard building inspector cards which focus on expenses and visit counts,
/// the Nature Reserve represents financial stability, savings growth, and forward-looking goals.
/// Strictly follows the borderless, pure typographical editorial style (no box strokes or card frames).
public struct ReserveSanctuarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager

    @Query(sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]
    @Query(filter: #Predicate<Transaction> { $0.savingsGoalId != nil })
    private var goalDeposits: [Transaction]
    @Query(sort: \Transaction.timestamp, order: .reverse)
    private var allTransactions: [Transaction]

    // Goal creation state
    @State private var showAddGoal = false
    @State private var newGoalName = ""
    @State private var newGoalTarget = ""
    @State private var newGoalIcon = "target"

    // Deposit state
    @State private var depositingGoal: SavingsGoal? = nil
    @State private var depositAmount = ""
    @State private var showSavingsFeed = false

    private let reserveGreen = Color(red: 16/255, green: 185/255, blue: 129/255)
    private let reserveDark = Color(red: 6/255, green: 95/255, blue: 70/255)
    private let sheetBg = Color(red: 250/255, green: 252/255, blue: 250/255)

    private var isHebrew: Bool { l10n.language == .hebrew }
    private var symbol: String { l10n.baseCurrency.symbol }

    public init() {}

    /// Transactions tagged as savings this calendar month
    private var thisMonthSavingsTransactions: [Transaction] {
        let cal = Calendar.current
        let now = Date()
        return allTransactions.filter { tx in
            tx.category == .savings && cal.isDate(tx.timestamp, equalTo: now, toGranularity: .month)
        }
    }

    private var savedThisMonth: Double {
        thisMonthSavingsTransactions.reduce(0) { $0 + $1.amount }
    }

    private var totalInAllGoals: Double {
        goals.reduce(0) { $0 + $1.savedAmount }
    }

    /// Sanctuary condition description
    private var conditionText: String {
        if savedThisMonth > 1000 || totalInAllGoals > 5000 {
            return isHebrew ? "פורחת ומשגשגת 🌿" : "Flourishing & Thriving 🌿"
        } else if savedThisMonth > 0 || totalInAllGoals > 0 {
            return isHebrew ? "מטופחת וירוקה 🌱" : "Well Kept & Green 🌱"
        } else {
            return isHebrew ? "קרקע מוכנה לנביטה 🌾" : "Ready to Sprout 🌾"
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                sheetBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        headerHeroSection
                        Divider().background(Color.borderSubtle.opacity(0.7))
                        reserveStatsRow
                        Divider().background(Color.borderSubtle.opacity(0.7))
                        quickActionsBar
                        Divider().background(Color.borderSubtle.opacity(0.7))
                        savingsGoalsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(isHebrew ? "הפארק" : "The Park")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isHebrew ? "סגור" : "Close") { dismiss() }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showAddGoal.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            MoneyIcon(showAddGoal ? .xmarkCircle : .plusCircle, size: 16)
                            Text(isHebrew ? (showAddGoal ? "ביטול" : "יעד חדש") : (showAddGoal ? "Cancel" : "New Goal"))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(reserveGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(reserveGreen.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
            .sheet(item: $depositingGoal) { goal in
                depositSheet(goal)
            }
            .sheet(isPresented: $showSavingsFeed) {
                TransactionFeedSheet(
                    title: isHebrew ? "היסטוריית חיסכון" : "Savings History",
                    transactions: allTransactions.filter { $0.category == .savings || $0.savingsGoalId != nil }
                )
            }
            .onAppear {
                if SavingsGoalService.reconcile(goals: goals, transactions: goalDeposits) {
                    DatabaseService.safeSave(modelContext)
                }
            }
        }
    }

    // ── Header Hero: Sanctuary Status ──
    private var headerHeroSection: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(reserveGreen.opacity(0.14))
                    .frame(width: 58, height: 58)
                CategoryVectorIcon(category: .savings, size: 30)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(conditionText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(reserveDark)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(reserveGreen.opacity(0.15))
                        .clipShape(Capsule())

                    Spacer()
                }

                Text(isHebrew ? "הפארק" : "The Park")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                Text(isHebrew
                     ? "הפארק משתנה לפי התקציב והחיסכון שלך."
                     : "The park changes with your budget and savings.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .lineSpacing(2)
            }
        }
        .padding(.top, 4)
    }

    // ── Reserve Growth & Stability Metrics (Clean Typography, Zero Box Strokes) ──
    private var reserveStatsRow: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(isHebrew ? "נחסך החודש" : "Saved This Month")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                Text(l10n.format(amount: savedThisMonth.rounded()))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(reserveGreen)
                Text(isHebrew ? "הפקדות והשקעות" : "Deposits & funds")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.borderSubtle.opacity(0.7))
                .frame(width: 1, height: 44)
                .padding(.horizontal, 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(isHebrew ? "סך הכל ביעדים" : "In All Goals")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                Text(l10n.format(amount: totalInAllGoals.rounded()))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                Text(isHebrew ? "\(goals.count) יעדים מוגדרים" : "\(goals.count) active goals")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // ── Quick Action Pills (No Card Borders) ──
    private var quickActionsBar: some View {
        HStack(spacing: 12) {
            Button {
                if let first = goals.first {
                    depositingGoal = first
                } else {
                    withAnimation { showAddGoal = true }
                }
            } label: {
                HStack(spacing: 6) {
                    MoneyIcon(.plusCircle, size: 16)
                    Text(isHebrew ? "הפקדה ליעד" : "Deposit to Goal")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(reserveGreen)
                .clipShape(Capsule())
                .shadow(color: reserveGreen.opacity(0.25), radius: 6, y: 2)
            }
            .buttonStyle(.plain)

            Button {
                showSavingsFeed = true
            } label: {
                HStack(spacing: 6) {
                    MoneyIcon(.clock, size: 16)
                    Text(isHebrew ? "היסטוריית חיסכון" : "Savings History")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color.deepNavy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.appBackground)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // ── Savings Goals Section ──
    private var savingsGoalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(isHebrew ? "יעדי חיסכון" : "Savings Goals")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                Spacer()

                if !goals.isEmpty {
                    Text("\(goals.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color.textMuted)
                }
            }

            if showAddGoal {
                inlineAddGoalForm
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if goals.isEmpty && !showAddGoal {
                emptyGoalsState
            } else {
                VStack(spacing: 16) {
                    ForEach(goals) { goal in
                        goalRowItem(goal)
                    }
                }
            }
        }
    }

    // ── Individual Goal Row (Editorial, Borderless) ──
    private func goalRowItem(_ goal: SavingsGoal) -> some View {
        let fraction = SavingsGoalService.fraction(saved: goal.savedAmount, target: goal.targetAmount)
        let left = SavingsGoalService.remaining(saved: goal.savedAmount, target: goal.targetAmount)
        let pct = Int((fraction * 100).rounded())

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(reserveGreen.opacity(0.12))
                        .frame(width: 36, height: 36)
                    MoneyIcon(goal.isComplete ? .checkCircle : .target, size: 18)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    Text(goal.isComplete
                         ? (isHebrew ? "היעד הושלם בהצלחה! 🎉" : "Goal completed! 🎉")
                         : (isHebrew ? "נותרו \(l10n.format(amount: left.rounded())) ליעד" : "\(l10n.format(amount: left.rounded())) remaining"))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(goal.isComplete ? reserveGreen : Color.textMuted)
                }

                Spacer()

                // Quick deposit button
                Button {
                    depositingGoal = goal
                } label: {
                    HStack(spacing: 3) {
                        MoneyIcon(.plusCircle, size: 12)
                        Text(isHebrew ? "הפקד" : "Deposit")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(reserveGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(reserveGreen.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: isHebrew ? .trailing : .leading) {
                    Capsule()
                        .fill(Color.appBackground)
                        .frame(height: 7)
                    Capsule()
                        .fill(goal.isComplete ? reserveGreen : Color.deepNavy)
                        .frame(width: max(6, geo.size.width * CGFloat(fraction)), height: 7)
                }
            }
            .frame(height: 7)

            HStack {
                Text("\(l10n.format(amount: goal.savedAmount.rounded())) / \(l10n.format(amount: goal.targetAmount.rounded()))")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                Spacer()
                Text("\(pct)%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(goal.isComplete ? reserveGreen : Color.deepNavy)
            }
        }
        .padding(.vertical, 4)
    }

    // ── Inline Add Goal Form (Borderless) ──
    private var inlineAddGoalForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isHebrew ? "הגדרת יעד חיסכון חדש" : "Set Up New Savings Goal")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)

            TextField(isHebrew ? "שם היעד (למשל: קרן ביטחון, חופשה, רכב)" : "Goal name (e.g. Emergency Fund, Trip)", text: $newGoalName)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .padding(10)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 8) {
                TextField(isHebrew ? "סכום יעד" : "Target amount", text: $newGoalTarget)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .padding(10)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button {
                    saveNewGoal()
                } label: {
                    Text(isHebrew ? "שמור יעד" : "Save")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(reserveGreen)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(newGoalName.trimmingCharacters(in: .whitespaces).isEmpty || (Double(newGoalTarget) ?? 0) <= 0)
                .opacity((newGoalName.trimmingCharacters(in: .whitespaces).isEmpty || (Double(newGoalTarget) ?? 0) <= 0) ? 0.4 : 1.0)
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // ── Empty State ──
    private var emptyGoalsState: some View {
        VStack(alignment: .center, spacing: 8) {
            MoneyIcon(.leaf, size: 36)
            Text(isHebrew ? "טרם הגדרת יעדי חיסכון" : "No savings goals defined yet")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
            Text(isHebrew
                 ? "הגדר יעד לקרן חירום, חופשה או השקעה — והפארק יצמח יחד איתו."
                 : "Set a goal for emergencies, vacation, or investments — and watch the park grow.")
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundColor(Color.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button {
                withAnimation { showAddGoal = true }
            } label: {
                Text(isHebrew ? "+ הוסף את היעד הראשון" : "+ Add First Goal")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundColor(reserveGreen)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(reserveGreen.opacity(0.12))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // ── Deposit Sheet ──
    private func depositSheet(_ goal: SavingsGoal) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text(isHebrew ? "הפקדה ליעד:" : "Deposit into:")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textMuted)
                    Text(goal.name)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                }
                .padding(.top, 24)

                HStack(spacing: 4) {
                    Text(symbol)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(reserveGreen)
                    TextField("0", text: $depositAmount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                        .frame(maxWidth: 180)
                }
                .frame(maxWidth: .infinity)

                Spacer()

                Button {
                    applyDeposit(to: goal)
                } label: {
                    Text(isHebrew ? "בצע הפקדה לחיסכון" : "Confirm Deposit")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(reserveGreen)
                        .clipShape(Capsule())
                        .shadow(color: reserveGreen.opacity(0.25), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .disabled((Double(depositAmount) ?? 0) <= 0)
                .opacity((Double(depositAmount) ?? 0) <= 0 ? 0.4 : 1.0)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isHebrew ? "ביטול" : "Cancel") {
                        depositingGoal = nil
                        depositAmount = ""
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.fraction(0.45)])
        #endif
    }

    private func saveNewGoal() {
        let trimmed = newGoalName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let target = Double(newGoalTarget), target > 0 else { return }
        let goal = SavingsGoal(
            name: trimmed,
            icon: newGoalIcon,
            targetAmount: target,
            currency: symbol
        )
        modelContext.insert(goal)
        DatabaseService.safeSave(modelContext)
        newGoalName = ""
        newGoalTarget = ""
        withAnimation { showAddGoal = false }
        Haptics.notify(.success)
    }

    private func applyDeposit(to goal: SavingsGoal) {
        guard let amt = Double(depositAmount), amt > 0 else { return }
        if !goal.baselineCaptured {
            goal.unlinkedBaseline = goal.savedAmount
            goal.baselineCaptured = true
        }
        goal.savedAmount += amt
        let tx = SavingsGoalService.makeDepositTransaction(
            goalId: goal.id,
            goalName: goal.name,
            amount: amt,
            currency: goal.currency
        )
        modelContext.insert(tx)
        if goal.isComplete && goal.completedAt == nil {
            goal.completedAt = Date()
            modelContext.insert(SavingsGoalService.makeCompletionEnrichment(for: goal))
            Haptics.notify(.success)
        } else {
            Haptics.impact(.medium)
        }
        DatabaseService.safeSave(modelContext)
        depositingGoal = nil
        depositAmount = ""
    }
}
