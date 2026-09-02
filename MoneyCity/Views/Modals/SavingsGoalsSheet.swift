import SwiftUI
import SwiftData

/// Goals the user is saving toward, and the deposits that move them.
public struct SavingsGoalsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager

    @Query(sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]

    /// Deposits are the record of truth for goal progress, so the sheet has to see them.
    @Query(filter: #Predicate<Transaction> { $0.savingsGoalId != nil })
    private var goalDeposits: [Transaction]

    @State private var showAdd = false
    @State private var newName = ""
    @State private var newTarget = ""
    @State private var newIcon = "target"
    @State private var depositing: SavingsGoal? = nil
    @State private var depositAmount = ""

    private let sheetBg = Color(red: 248/255, green: 250/255, blue: 252/255)
    private let icons = ["target", "airplane", "house.fill", "car.fill", "laptopcomputer", "graduationcap.fill", "gift.fill", "cart.fill"]

    public init() {}

    private var isHebrew: Bool { l10n.language == .hebrew }
    private var symbol: String { l10n.baseCurrency.symbol }

    public var body: some View {
        NavigationStack {
            ZStack {
                sheetBg.ignoresSafeArea()

                if goals.isEmpty && !showAdd {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            if showAdd { addCard }
                            ForEach(goals) { goal in
                                goalCard(goal)
                            }
                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 16).padding(.top, 12)
                    }
                }
            }
            .onAppear {
                if SavingsGoalService.reconcile(goals: goals, transactions: goalDeposits) {
                    try? modelContext.save()
                }
            }
            .navigationTitle(isHebrew ? "יעדי חיסכון" : "Savings Goals")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isHebrew ? "סגור" : "Close") { dismiss() }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { withAnimation { showAdd.toggle() } } label: {
                        Image(systemName: showAdd ? "xmark" : "plus")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
            }
            .sheet(item: $depositing) { goal in
                depositSheet(goal)
            }
        }
    }

    private func depositSheet(_ goal: SavingsGoal) -> some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(goal.name)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                Text(isHebrew ? "כמה ברצונך להפקיד?" : "How much to deposit?")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Color.slate400)

                HStack(spacing: 6) {
                    Text(symbol)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                    #if os(iOS)
                    TextField("0", text: $depositAmount)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                    #else
                    TextField("0", text: $depositAmount)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                    #endif
                }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Button {
                    commitDeposit()
                } label: {
                    Text(isHebrew ? "הפקד ליעד" : "Deposit to goal")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.themeMint))
                }
                .buttonStyle(.plain)
                .disabled((Double(depositAmount) ?? 0) <= 0)

                Spacer()
            }
            .padding(16)
            .background(sheetBg.ignoresSafeArea())
            .navigationTitle(isHebrew ? "הפקדה ליעד" : "Deposit")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isHebrew ? "ביטול" : "Cancel") { depositing = nil }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text(isHebrew
                     ? "הסכום יירשם גם כהפקדה לחיסכון ויגדיל את הפארק בעיר."
                     : "This is also recorded as a savings transfer and grows the city's park.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(Color.primaryBlue)
            Text(isHebrew ? "אין עדיין יעדים" : "No goals yet")
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(isHebrew
                 ? "יעד נותן סיבה לפתוח את האפליקציה גם כשלא קנית כלום."
                 : "A goal gives you a reason to open the app on a day you bought nothing.")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(Color.slate400)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button { withAnimation { showAdd = true } } label: {
                Text(isHebrew ? "יעד ראשון" : "Add a goal")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(Capsule().fill(Color.primaryBlue))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(isHebrew ? "טיול ליפן" : "Trip to Japan", text: $newName)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(sheetBg).clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 8) {
                Text(symbol)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(Color.primaryBlue)
                #if os(iOS)
                TextField("0", text: $newTarget)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                #else
                TextField("0", text: $newTarget)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                #endif
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(sheetBg).clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 8) {
                ForEach(icons, id: \.self) { icon in
                    Button { newIcon = icon } label: {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(newIcon == icon ? Color.primaryBlue : Color.slate400)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle().fill(newIcon == icon ? Color.primaryBlue.opacity(0.14) : Color.clear)
                            )
                            .overlay(Circle().stroke(newIcon == icon ? Color.primaryBlue : Color.clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button(isHebrew ? "צור" : "Create") { createGoal() }
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(canCreate ? Color.primaryBlue : Color.slate300)
                    .disabled(!canCreate)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.primaryBlue.opacity(0.35), lineWidth: 1))
    }

    private func goalCard(_ goal: SavingsGoal) -> some View {
        let fraction = SavingsGoalService.fraction(saved: goal.savedAmount, target: goal.targetAmount)
        let left = SavingsGoalService.remaining(saved: goal.savedAmount, target: goal.targetAmount)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icons.contains(goal.icon) || goal.icon.contains(".") ? goal.icon : "target")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.primaryBlue)
                    .frame(width: 36, height: 36)
                    .background(Color.primaryBlue.opacity(0.1))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(goal.name)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                    Text("\(l10n.format(amount: goal.savedAmount.rounded())) \(isHebrew ? "מתוך" : "of") \(l10n.format(amount: goal.targetAmount.rounded()))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.slate400)
                }
                Spacer()
                if goal.isComplete {
                    Text(isHebrew ? "הושלם" : "Done")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(Color.themeMint)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Color.themeMint.opacity(0.12))
                        .clipShape(Capsule())
                } else {
                    Button {
                        depositAmount = ""
                        depositing = goal
                    } label: {
                        Text(isHebrew ? "הפקדה" : "Deposit")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(Color.primaryBlue))
                    }
                    .buttonStyle(.plain)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(sheetBg).frame(height: 8)
                    Capsule()
                        .fill(goal.isComplete ? Color.themeMint : Color.primaryBlue)
                        .frame(width: max(6, geo.size.width * fraction), height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(goal.isComplete ? Color.themeMint : Color.primaryBlue)
                Spacer()
                if !goal.isComplete {
                    Text(isHebrew ? "נשאר \(l10n.format(amount: left.rounded()))" : "\(l10n.format(amount: left.rounded())) to go")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.slate400)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.slate200, lineWidth: 1))
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(goal)
                try? modelContext.save()
                Haptics.notify(.warning)
            } label: {
                Text(isHebrew ? "מחק יעד" : "Delete goal")
            }
        }
    }

    // MARK: - Actions

    private var canCreate: Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (TransactionIngest.normalizedAmount(nil, newTarget) ?? 0) > 0
    }

    private func createGoal() {
        guard let target = TransactionIngest.normalizedAmount(nil, newTarget), target > 0 else { return }
        modelContext.insert(SavingsGoal(
            name: newName.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: newIcon,
            targetAmount: target,
            currency: symbol
        ))
        try? modelContext.save()
        newName = ""; newTarget = ""; newIcon = "target"
        withAnimation { showAdd = false }
        Haptics.notify(.success)
    }

    private func commitDeposit() {
        guard let goal = depositing,
              let amount = TransactionIngest.normalizedAmount(nil, depositAmount),
              amount > 0
        else { depositing = nil; return }

        // A goal that has never been reconciled banks what it holds now, so this deposit
        // adds to it instead of being counted twice on the next pass.
        if !goal.baselineCaptured {
            goal.unlinkedBaseline = goal.savedAmount
            goal.baselineCaptured = true
        }
        goal.savedAmount += amount

        // A deposit is a real transfer, so it is recorded as one rather than living only
        // on the goal — otherwise the city's savings park would not move.
        modelContext.insert(SavingsGoalService.makeDepositTransaction(
            goalId: goal.id,
            goalName: goal.name,
            amount: amount,
            currency: goal.currency
        ))

        // Finishing a goal earns a landmark through the same machinery the weekly
        // progress rewards already use.
        if goal.isComplete && goal.completedAt == nil {
            goal.completedAt = Date()
            modelContext.insert(SavingsGoalService.makeCompletionEnrichment(for: goal))
            Haptics.notify(.success)
        } else {
            Haptics.impact(.medium)
        }

        try? modelContext.save()
        depositing = nil
        depositAmount = ""
    }
}
