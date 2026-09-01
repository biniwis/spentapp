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
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.themeOrange)
                        Text(isHebrew ? "מרכז המיון והדואר" : "City Sorting Hub")
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
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.themeOrange)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(isHebrew ? "חבילות והוצאות שממתינות למיון" : "Packages Waiting for Sorting")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                
                Text(isHebrew
                     ? "סווג כל חבילה למבנה הנכון בעיר בלחיצה אחת כדי לפנות את המרכז."
                     : "Assign each package to its city district with a single tap to clear the hub.")
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
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.borderSubtle, lineWidth: 1.2))
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
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.themeOrange)
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
                Text(isHebrew ? "לאיזה רובע ומבנה להעביר?" : "Move to which district?")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryQuickButton(tx: tx, cat: .food, icon: "fork.knife", label: isHebrew ? "אוכל" : "Food", color: Color.themeTurquoise)
                        categoryQuickButton(tx: tx, cat: .shopping, icon: "bag.fill", label: isHebrew ? "קניות" : "Shop", color: Color.themeLavender)
                        categoryQuickButton(tx: tx, cat: .housing, icon: "house.fill", label: isHebrew ? "בית" : "Home", color: Color.primaryBlue)
                        categoryQuickButton(tx: tx, cat: .transport, icon: "car.fill", label: isHebrew ? "תחבורה" : "Transit", color: Color.themeOrange)
                        categoryQuickButton(tx: tx, cat: .health, icon: "heart.fill", label: isHebrew ? "בריאות" : "Health", color: Color.themeMint)
                        categoryQuickButton(tx: tx, cat: .subscriptions, icon: "tv.fill", label: isHebrew ? "מנויים" : "Subs", color: Color.themeLavender)
                        categoryQuickButton(tx: tx, cat: .finance, icon: "creditcard.fill", label: isHebrew ? "פיננסים" : "Finance", color: Color.deepNavy)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.borderSubtle, lineWidth: 1.2))
        .shadow(color: Color.deepNavy.opacity(0.04), radius: 6, y: 2)
    }
    
    private func categoryQuickButton(tx: Transaction, cat: SpendingCategory, icon: String, label: String, color: Color) -> some View {
        Button(action: {
            Haptics.impact(.medium)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                sortedTxIds.insert(tx.id)
                onUpdateCategory(tx, cat)
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
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
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundColor(Color.themeMint)
            }
            
            VStack(spacing: 8) {
                Text(isHebrew ? "מרכז המיון נקי ומסודר!" : "Sorting Hub is Spotless!")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                
                Text(isHebrew
                     ? "כל ההוצאות חולקו בהצלחה למבנים הנכונים בעיר. אין חבילות שממתינות למיון."
                     : "All expenses are assigned to their proper city buildings. No packages waiting.")
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
