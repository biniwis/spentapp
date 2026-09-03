import SwiftUI

/// Chronological feed of monthly transactions with 1-tap categorization editing.
public struct TransactionFeedSheet: View {
    @Environment(\.dismiss) private var dismiss
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
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if transactions.isEmpty {
                    VStack(spacing: 12) {
                        DistrictSkylineVectorIcon(color: Color.primaryBlue)
                            .frame(width: 44, height: 44)
                            .scaleEffect(1.6)
                        Text(title != nil ? "אין עסקאות עדיין ב-\(title!)" : "אין עסקאות עדיין החודש")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        Text("כל הוצאה שתסווג לכאן תופיע כאן ותצמיח את המבנה בעיר.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(transactions) { tx in
                            HStack(spacing: 14) {
                                // Category Icon Badge
                                CategoryBadge(category: tx.category, size: 44)
                                
                                // Merchant & Time Info
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tx.merchant)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.deepNavy)
                                    
                                    HStack(spacing: 6) {
                                        Text(tx.timeString)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(Color.textMuted)
                                        Text("•")
                                            .foregroundColor(Color.borderSubtle)
                                        Text(tx.category.shortName)
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(tx.category.themeColor)
                                    }
                                }
                                
                                Spacer()
                                
                                // Amount
                                Text(tx.formattedAmount)
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
            .navigationTitle(title ?? "יומן עסקאות החודש")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("סגור") { dismiss() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color.primaryBlue)
                }
            }
            .sheet(item: $selectedTxToEdit) { tx in
                EditTransactionSheet(transaction: tx)
                    .presentationDetents([PresentationDetent.medium, PresentationDetent.large])
            }
        }
    }
}

