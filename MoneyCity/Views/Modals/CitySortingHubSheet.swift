import SwiftUI
import SwiftData

/// Interactive, gamified Sorting & Triage Hub for miscellaneous and uncategorized expenses.
/// Tapping a category assigns the expense to its true building and cleans up the Hub.
public struct CitySortingHubSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager
    
    public let transactions: [Transaction]
    public let onUpdateCategory: (Transaction, SpendingCategory) -> Void
    
    @State private var sortedTxIds: Set<UUID> = []
    
    public init(
        transactions: [Transaction],
        onUpdateCategory: @escaping (Transaction, SpendingCategory) -> Void
    ) {
        self.transactions = transactions
        self.onUpdateCategory = onUpdateCategory
    }
    
    private var isHebrew: Bool { l10n.language == .hebrew }
    
    private var pendingTransactions: [Transaction] {
        transactions.filter { !sortedTxIds.contains($0.id) && $0.category == .other }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.cardBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if pendingTransactions.isEmpty {
                        cleanHubEmptyState
                    } else {
                        VStack(spacing: 0) {
                            hubHeaderSummary
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .padding(.bottom, 12)
                            
                            ScrollView {
                                LazyVStack(spacing: 14) {
                                    ForEach(pendingTransactions) { tx in
                                        parcelCard(for: tx)
                                            .transition(
                                                .asymmetric(
                                                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                                    removal: .opacity.combined(with: .scale(scale: 0.8)).combined(with: .offset(y: -20))
                                                )
                                            )
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 32)
                            }
                        }
                    }
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isHebrew ? "סגור" : "Close") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color.primaryBlue)
                }
                
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        MoneyIcon(.shoppingBag, size: 16)
                        Text(isHebrew ? "עסקאות לא מסווגות" : "Uncategorized Transactions")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                    }
                }
            }
        }
    }
    
    // MARK: - Hub Header Summary
    private var hubHeaderSummary: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.themeOrange.opacity(0.14))
                    .frame(width: 48, height: 48)
                MoneyIcon(.shoppingBag, size: 24)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(isHebrew ? "עסקאות שמחכות לסיווג" : "Transactions to Categorize")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                
                Text(isHebrew
                     ? "סווג כל עסקה לקטגוריה הנכונה בלחיצה אחת."
                     : "Assign each transaction to a category with a single tap.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Badge Counter
            Text("\(pendingTransactions.count)")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.themeOrange)
                .clipShape(Capsule())
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.deepNavy.opacity(0.04), radius: 8, y: 2)
    }
    
    // MARK: - Single Parcel Card
    private func parcelCard(for tx: Transaction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top Row: Parcel Tag, Merchant, Amount
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.themeOrangeSoft)
                        .frame(width: 42, height: 42)
                    MoneyIcon(.shoppingBag, size: 20)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tx.merchant)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                        .lineLimit(1)
                    
                    Text(tx.timeString)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textMuted)
                }
                
                Spacer()
                
                Text(l10n.baseCurrency.symbol + String(format: "%.0f", tx.amount))
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
            }
            
            Divider()
                .background(Color.borderSubtle.opacity(0.6))
            
            // 1-Tap Category Pills Scroll / Grid
            VStack(alignment: .leading, spacing: 6) {
                Text(isHebrew ? "לאיזו קטגוריה להעביר?" : "Choose a Category")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryQuickButton(tx: tx, cat: .food, label: isHebrew ? "אוכל" : "Food", color: Color.themeTurquoise)
                        categoryQuickButton(tx: tx, cat: .shopping, label: isHebrew ? "קניות" : "Shop", color: Color.themeLavender)
                        categoryQuickButton(tx: tx, cat: .housing, label: isHebrew ? "בית" : "Home", color: Color.primaryBlue)
                        categoryQuickButton(tx: tx, cat: .transport, label: isHebrew ? "תחבורה" : "Transport", color: Color.themeOrange)
                        categoryQuickButton(tx: tx, cat: .entertainment, label: isHebrew ? "בילויים" : "Entertainment", color: Color.themeOrange)
                        categoryQuickButton(tx: tx, cat: .health, label: isHebrew ? "בריאות" : "Health", color: Color.themeMint)
                        categoryQuickButton(tx: tx, cat: .subscriptions, label: isHebrew ? "מנויים" : "Subscriptions", color: Color.themeLavender)
                        categoryQuickButton(tx: tx, cat: .finance, label: isHebrew ? "פיננסים" : "Finance", color: Color.deepNavy)
                        categoryQuickButton(tx: tx, cat: .miscellaneous, label: isHebrew ? "שונות" : "Misc", color: Color(red: 139/255, green: 92/255, blue: 246/255))
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.deepNavy.opacity(0.04), radius: 6, y: 2)
    }
    
    private func categoryQuickButton(tx: Transaction, cat: SpendingCategory, label: String, color: Color) -> some View {
        Button(action: {
            Haptics.impact(.medium)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                sortedTxIds.insert(tx.id)
                onUpdateCategory(tx, cat)
            }
        }) {
            HStack(spacing: 5) {
                CategoryVectorIcon(category: cat, size: 14)
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Clean Hub Empty State
    private var cleanHubEmptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.themeMint.opacity(0.15))
                    .frame(width: 130, height: 130)
                
                Circle()
                    .fill(Color.themeMint.opacity(0.30))
                    .frame(width: 90, height: 90)
                
                MoneyIcon(.checkCircle, size: 52)
            }
            
            VStack(spacing: 8) {
                Text(isHebrew ? "הכול מסווג" : "You're All Caught Up")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                
                Text(isHebrew
                     ? "כל העסקאות שויכו לקטגוריות מתאימות. אין עסקאות שממתינות לסיווג."
                     : "All transactions have been categorized. You're completely caught up.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: { dismiss() }) {
                HStack(spacing: 6) {
                    Text(isHebrew ? "חזרה לעיר" : "Back to City")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.primaryBlue)
                .clipShape(Capsule())
                .padding(.horizontal, 36)
            }
            .padding(.top, 12)
            
            Spacer()
        }
    }
}
