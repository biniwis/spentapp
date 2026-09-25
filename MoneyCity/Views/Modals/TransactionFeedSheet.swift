import SwiftUI
import SwiftData

/// Chronological feed of monthly transactions with 1-tap categorization editing.
public struct TransactionFeedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager
    public let title: String?
    @Query private var storedTransactions: [Transaction]
    private let personalTransactions: [Transaction]
    private let suppliedExpenses: [ExpenseSnapshot]?
    #if !SWIFT_PACKAGE
    @ObservedObject private var scope = AppScopeContext.shared
    @State private var editingShared: SharedExpense?
    #endif
    private var transactions: [ExpenseSnapshot] {
        #if !SWIFT_PACKAGE
        if let suppliedExpenses, scope.activeScope.isShared {
            let ids = Set(suppliedExpenses.map(\.id))
            return scope.allExpenses(personalTransactions: []).filter { ids.contains($0.id) }
        }
        #endif
        return suppliedExpenses ?? personalTransactions.map(ExpenseSnapshot.init)
    }
    
    @State private var selectedTxToEdit: Transaction? = nil
    
    public init(
        title: String? = nil,
        transactions: [Transaction]
    ) {
        self.title = title
        self.personalTransactions = transactions
        self.suppliedExpenses = nil
    }
    
    public init(title: String? = nil, expenses: [ExpenseSnapshot]) {
        self.title = title
        self.personalTransactions = []
        self.suppliedExpenses = expenses
    }

    private var isHebrew: Bool { l10n.language == .hebrew }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if transactions.isEmpty {
                    ScrollView {
                        SpentEmptyState(icon: .receipt,
                            title: isHebrew ? "כאן יופיע הסיפור שמאחורי המספרים" : "The story behind the numbers goes here",
                            message: isHebrew ? "עדיין אין עסקאות בתצוגה הזו. הוצאות שישויכו לכאן יופיעו עם שם העסק, הסכום והתאריך."
                                : "There are no transactions in this view yet. Matching expenses will appear with their merchant, amount and date.",
                            actionTitle: isHebrew ? "חזרה" : "Go back",
                            action: { dismiss() })
                            .padding(.top, 40)
                    }
                } else {
                    List {
                        ForEach(transactions) { tx in
                            HStack(spacing: 14) {
                                // Subcategory Icon Badge
                                CategoryBadge(transaction: tx, size: 44)
                                
                                // Merchant & Time Info
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(displayMerchantTitle(for: tx))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.deepNavy)
                                    
                                    HStack(spacing: 6) {
                                        Text(tx.timeString)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(Color.textMuted)
                                        Text("•")
                                            .foregroundColor(Color.borderSubtle)
                                        Text(tx.category.localizedShortName(for: l10n.language))
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(tx.category.themeColor)
                                    }
                                    #if !SWIFT_PACKAGE
                                    if let payer = scope.participants.first(where: { $0.id == tx.paidBy }) {
                                        HStack(spacing: 4) {
                                            SharedMemberMark(colorHex: payer.colorHex, size: 18)
                                            Text(payer.name)
                                                .font(.caption2.weight(.medium))
                                                .foregroundStyle(MoneyCityTheme.textSecondary)
                                        }
                                        .accessibilityElement(children: .ignore)
                                        .accessibilityLabel((isHebrew ? "שילם/ה: " : "Paid by: ") + payer.name)
                                    }
                                    #endif
                                }
                                
                                Spacer()
                                
                                // Amount
                                Text(l10n.formatScoped(amount: tx.amount))
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                            }
                            .listRowBackground(Color.cardBackground)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                #if !SWIFT_PACKAGE
                                if let spaceID = scope.activeScope.spaceID {
                                    editingShared = SharedWorkspaceStore.shared.expenses.first { $0.id == tx.id && $0.spaceID == spaceID }
                                } else {
                                    selectedTxToEdit = storedTransactions.first { $0.id == tx.id }
                                }
                                #else
                                selectedTxToEdit = storedTransactions.first { $0.id == tx.id }
                                #endif
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let tx = transactions[index]
                                #if !SWIFT_PACKAGE
                                if let spaceID = scope.activeScope.spaceID {
                                    let store = SharedWorkspaceStore.shared
                                    if let expense = store.expenses.first(where: { $0.id == tx.id && $0.spaceID == spaceID }) {
                                        do { try store.deleteExpense(expense) }
                                        catch { store.errorMessage = error.localizedDescription }
                                    }
                                    continue
                                }
                                #endif
                                if let original = storedTransactions.first(where: { $0.id == tx.id }) {
                                    DatabaseService.shared.context.delete(original)
                                }
                            }
                            try? DatabaseService.shared.context.save()
                        }
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #endif
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.appBackground)
            .navigationTitle(title ?? (isHebrew ? "יומן עסקאות החודש" : "Monthly Transactions"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isHebrew ? "סגור" : "Close") { dismiss() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color.primaryBlue)
                }
            }
            #if !SWIFT_PACKAGE
            .sheet(item: $editingShared) { expense in
                if let space = scope.currentSpace {
                    SharedExpenseEditor(space: space, expense: expense).environmentObject(l10n)
                }
            }
            #endif
            .sheet(item: $selectedTxToEdit) { tx in
                EditTransactionSheet(transaction: tx)
                    .presentationDetents([PresentationDetent.medium, PresentationDetent.large])
                    .environmentObject(l10n)
            }
        }
    }

    private func displayMerchantTitle(for tx: ExpenseSnapshot) -> String {
        let rawMerchant = tx.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let cat = tx.category

        let isGeneric = rawMerchant.isEmpty
            || rawMerchant == cat.displayName
            || rawMerchant == cat.displayNameEn
            || rawMerchant == cat.shortName
            || rawMerchant == cat.rawValue
            || rawMerchant == "ללא שם"
            || rawMerchant.caseInsensitiveCompare("Unnamed") == .orderedSame

        if isGeneric {
            let subName = SubcategoryBreakdownService.shared.subcategoryName(for: tx, isHebrew: isHebrew)
            if !subName.isEmpty && subName != cat.displayName {
                return subName
            }
            if let note = tx.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty, !note.contains("זיכוי") {
                return note
            }
            return subName.isEmpty ? cat.displayName : subName
        }

        return rawMerchant
    }
}
