import SwiftUI

/// Chronological feed of monthly transactions with 1-tap categorization editing.
public struct TransactionFeedSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let title: String?
    public let transactions: [Transaction]
    public let onUpdateCategory: (Transaction, SpendingCategory) -> Void
    
    @State private var selectedTxToEdit: Transaction? = nil
    
    public init(
        title: String? = nil,
        transactions: [Transaction],
        onUpdateCategory: @escaping (Transaction, SpendingCategory) -> Void
    ) {
        self.title = title
        self.transactions = transactions
        self.onUpdateCategory = onUpdateCategory
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

/// Mini modal for switching a category in 1 tap
struct EditCategoryModal: View {
    @Environment(\.dismiss) private var dismiss
    let transaction: Transaction
    let onSelected: (SpendingCategory) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("שינוי קטגוריה עבור \(transaction.merchant)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                .padding(.top, 20)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(SpendingCategory.primaryCategories) { cat in
                    Button(action: {
                        onSelected(cat)
                        dismiss()
                    }) {
                        HStack(spacing: 6) {
                            CategoryVectorIcon(category: cat, size: 16)
                            Text(cat.shortName)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(cat.themeColor.opacity(0.4), lineWidth: 1)
                                    )
                                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .presentationDetents([.fraction(0.35)])
        .presentationBackground(Color(red: 248/255, green: 250/255, blue: 252/255))
    }
}
