import SwiftUI
import SwiftData

/// Goals the user is saving toward, and the deposits that move them.
public struct SavingsGoalsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager

    @Query(sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]

    @State private var showAdd = false
    @State private var newName = ""
    @State private var newTarget = ""
    @State private var newIcon = "🎯"
    @State private var depositing: SavingsGoal? = nil
    @State private var depositAmount = ""

    private let sheetBg = Color(red: 248/255, green: 250/255, blue: 252/255)
    private let icons = ["🎯", "✈️", "🏠", "🚗", "💻", "🎓", "💍", "🛋️"]

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
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
            }
            .navigationTitle(isHebrew ? "יעדי חיסכון" : "Savings Goals")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.text(for: "close")) { dismiss() }
                        .foregroundColor(Color.primaryBlue)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { withAnimation { showAdd.toggle() } } label: {
                        ZStack {
                            Circle()
                                .fill(Color.primaryBlue.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Text(verbatim: showAdd ? "✕" : "+")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Color.primaryBlue)
                        }
                    }
                }
            }
            .alert(
                isHebrew ? "הפקדה ליעד" : "Add to goal",
                isPresented: Binding(get: { depositing != nil }, set: { if !$0 { depositing = nil } })
            ) {
                TextField("0", text: $depositAmount)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                Button(isHebrew ? "הפקד" : "Deposit") { commitDeposit() }
                Button(l10n.text(for: "cancel"), role: .cancel) { depositing = nil; depositAmount = "" }
            } message: {
                Text(isHebrew
                     ? "הסכום יירשם גם כהפקדה לחיסכון ויגדיל את הפארק בעיר."
                     : "This is also recorded as a savings transfer and grows the city's park.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🎯").font(.system(size: 44, design: .rounded))
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
                        Text(icon)
                            .font(.system(size: 20, design: .rounded))
                            .frame(width: 36, height: 36)
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
                Text(goal.icon).font(.system(size: 24, design: .rounded))
                VStack(alignment: .leading, spacing: 1) {
                    Text(goal.name)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                    Text("\(symbol)\(Int(goal.savedAmount.rounded())) \(isHebrew ? "מתוך" : "of") \(symbol)\(Int(goal.targetAmount.rounded()))")
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
                    Text(isHebrew ? "נשאר \(symbol)\(Int(left.rounded()))" : "\(symbol)\(Int(left.rounded())) to go")
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
        newName = ""; newTarget = ""; newIcon = "🎯"
        withAnimation { showAdd = false }
        Haptics.notify(.success)
    }

    private func commitDeposit() {
        guard let goal = depositing,
              let amount = TransactionIngest.normalizedAmount(nil, depositAmount),
              amount > 0
        else { depositing = nil; return }

        goal.savedAmount += amount

        // A deposit is a real transfer, so it is recorded as one rather than living only
        // on the goal — otherwise the city's savings park would not move.
        modelContext.insert(SavingsGoalService.makeDepositTransaction(
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
