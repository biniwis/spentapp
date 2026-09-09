import SwiftUI

/// Chronological feed of monthly transactions with 1-tap categorization editing.
public struct TransactionFeedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager
    public let title: String?
    public let transactions: [Transaction]
    
    @State private var selectedTxToEdit: Transaction? = nil
    
    public init(
        title: String? = nil,
        transactions: [Transaction]
    ) {
        self.title = title
        self.transactions = transactions
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
                                }
                                
                                Spacer()
                                
                                // Amount
                                Text(l10n.format(amount: tx.amount))
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                            }
                            .listRowBackground(Color.cardBackground)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTxToEdit = tx
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let tx = transactions[index]
                                DatabaseService.shared.context.delete(tx)
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
            .sheet(item: $selectedTxToEdit) { tx in
                EditTransactionSheet(transaction: tx)
                    .presentationDetents([PresentationDetent.medium, PresentationDetent.large])
                    .environmentObject(l10n)
            }
        }
    }

    private func displayMerchantTitle(for tx: Transaction) -> String {
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
