import SwiftUI
import SwiftData

/// Detailed Merchant Profile and History deep-dive sheet.
public struct MerchantDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager
    @Query(sort: \Transaction.timestamp, order: .reverse) private var allTransactions: [Transaction]
    
    let merchantName: String
    
    @State private var selectedCategory: SpendingCategory = .food
    /// Starts false and is set from storage on appear. It used to be hardcoded to true, so
    /// the switch claimed a rule existed whether or not one did.
    @State private var rememberCategory: Bool = false
    @State private var editingTx: Transaction? = nil
    @State private var ruleStatus: String? = nil
    
    public init(merchantName: String) {
        self.merchantName = merchantName
    }
    
    private var merchantTransactions: [Transaction] {
        allTransactions.filter {
            $0.merchant.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(merchantName.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }
    }
    
    private var totalSpent: Double {
        merchantTransactions.reduce(0) { $0 + $1.amount }
    }
    
    private var visitCount: Int {
        merchantTransactions.count
    }
    
    private var avgSpent: Double {
        visitCount > 0 ? totalSpent / Double(visitCount) : 0
    }
    
    private var inferredCategory: SpendingCategory {
        merchantTransactions.first?.category ?? .food
    }
    
    public var body: some View {
        ZStack {
            Color(red: 248/255, green: 250/255, blue: 252/255).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Drag Handle
                Capsule()
                    .fill(Color.slate200)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                
                // Top Bar
                HStack {
                    Button(action: { dismiss() }) {
                        Text(l10n.language == .hebrew ? "סגור" : "Close")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Color.textMuted)
                    }
                    Spacer()
                    Text(l10n.language == .hebrew ? "פרטי בית עסק" : "Merchant Details")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    Spacer()
                    Color.clear.frame(width: 44, height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 12)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // Merchant Hero Header
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(selectedCategory.themeColor.opacity(0.15))
                                    .frame(width: 68, height: 68)
                                CategoryVectorIcon(category: selectedCategory, color: selectedCategory.themeColor, size: 32)
                            }
                            
                            VStack(spacing: 4) {
                                Text(merchantName)
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                    .multilineTextAlignment(.center)
                                
                                Text(l10n.language == .hebrew ? "היית כאן \(visitCount) פעמים" : "You've been here \(visitCount) times")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.textSecondary)
                            }
                        }
                        .padding(.top, 6)
                        
                        // 3 Key Stats
                        HStack(spacing: 12) {
                            statBox(
                                title: l10n.language == .hebrew ? "ביקורים" : "Visits",
                                value: "\(visitCount)",
                                color: Color.themeLavender
                            )
                            statBox(
                                title: l10n.language == .hebrew ? "סך הכל" : "Total Spent",
                                value: l10n.format(amount: totalSpent),
                                color: Color.primaryBlue
                            )
                            statBox(
                                title: l10n.language == .hebrew ? "ממוצע" : "Average",
                                value: l10n.format(amount: avgSpent),
                                color: Color.themeTurquoise
                            )
                        }
                        .padding(.horizontal, 16)
                        
                        // Category & Rule Memory Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text(l10n.language == .hebrew ? "שיוך קטגוריה וזיכרון" : "Category & Memory")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            
                            VStack(spacing: 12) {
                                // Category Pill Selection
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(SpendingCategory.allCases, id: \.self) { cat in
                                            let isSel = selectedCategory == cat
                                            Button(action: {
                                                Haptics.selection()
                                                selectedCategory = cat
                                                applyCategoryChange(cat)
                                            }) {
                                                HStack(spacing: 6) {
                                                    CategoryVectorIcon(category: cat, color: isSel ? .white : cat.themeColor, size: 14)
                                                    Text(cat.displayName)
                                                        .font(.system(size: 12, weight: isSel ? .bold : .semibold, design: .rounded))
                                                }
                                                .foregroundColor(isSel ? .white : Color.deepNavy)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(isSel ? Color.primaryBlue : Color(red: 241/255, green: 245/255, blue: 249/255))
                                                .clipShape(Capsule())
                                            }
                                            .bouncyPress(scale: 0.94)
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                }
                                
                                Divider().background(Color.borderSubtle)
                                
                                // Remember Checkbox / Rule
                                Toggle(isOn: $rememberCategory) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(l10n.language == .hebrew ? "זכור קטגוריה זו תמיד" : "Always remember this category")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(Color.deepNavy)
                                        Text(l10n.language == .hebrew ? "עסקאות עתידיות ב-\(merchantName) יסווגו אוטומטית" : "Future transactions at \(merchantName) will auto-categorize")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(Color.textMuted)
                                    }
                                }
                                .tint(Color.primaryBlue)
                                // Turning it off used to do nothing at all, and the
                                // confirmation was written to a flag no view ever read, so
                                // flipping the switch either way gave no feedback.
                                .onChange(of: rememberCategory) { _, val in
                                    if val {
                                        DatabaseService.shared.rememberCorrection(
                                            merchant: merchantName,
                                            category: selectedCategory
                                        )
                                        setRuleStatus(l10n.language == .hebrew
                                                      ? "נשמר — עסקאות עתידיות יסווגו אוטומטית"
                                                      : "Saved — future transactions will be categorised automatically")
                                    } else {
                                        DatabaseService.shared.forgetMerchant(merchantName)
                                        setRuleStatus(l10n.language == .hebrew
                                                      ? "הכלל נמחק — לא נסווג יותר אוטומטית"
                                                      : "Rule removed — no longer categorised automatically")
                                    }
                                }

                                if let status = ruleStatus {
                                    Text(status)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color.themeMint)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .transition(.opacity)
                                }
                            }
                            .padding(14)
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.borderSubtle, lineWidth: 1.2))
                        }
                        .padding(.horizontal, 16)
                        
                        // Transaction History List
                        VStack(alignment: .leading, spacing: 12) {
                            Text(l10n.language == .hebrew ? "היסטוריית עסקאות (\(visitCount))" : "Transaction History (\(visitCount))")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            
                            VStack(spacing: 0) {
                                ForEach(Array(merchantTransactions.enumerated()), id: \.element.id) { idx, tx in
                                    Button(action: {
                                        editingTx = tx
                                    }) {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(tx.formattedDate)
                                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                                    .foregroundColor(Color.deepNavy)
                                                Text(tx.category.displayName)
                                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                                    .foregroundColor(tx.category.themeColor)
                                            }
                                            
                                            Spacer()
                                            
                                            Text(l10n.format(amount: tx.amount))
                                                .font(.system(size: 15, weight: .black, design: .rounded))
                                                .foregroundColor(Color.deepNavy)
                                            
                                            Image(systemName: l10n.language == .hebrew ? "chevron.left" : "chevron.right")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(Color.borderSubtle)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                    }
                                    
                                    if idx < merchantTransactions.count - 1 {
                                        Divider().background(Color.borderSubtle).padding(.leading, 14)
                                    }
                                }
                            }
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.borderSubtle, lineWidth: 1.2))
                        }
                        .padding(.horizontal, 16)
                        
                        Spacer(minLength: 30)
                    }
                }
            }
        }
        .onAppear {
            // Read the actual rule rather than assuming one. If a rule exists its category is
            // the truth for this merchant; otherwise fall back to what the transactions imply.
            if let rule = DatabaseService.shared.merchantRule(for: merchantName) {
                selectedCategory = rule.category
                rememberCategory = true
            } else {
                selectedCategory = inferredCategory
                rememberCategory = false
            }
        }
        .sheet(item: $editingTx) { tx in
            EditTransactionSheet(transaction: tx)
                .presentationDetents([.medium, .large])
                .environmentObject(l10n)
        }
    }
    
    /// Shows a line of feedback and clears it again. The previous confirmation set a flag no
    /// view rendered, so saving a rule looked exactly like doing nothing.
    private func setRuleStatus(_ text: String) {
        withAnimation(.easeOut(duration: 0.2)) { ruleStatus = text }
        Haptics.impact(.light)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.2)) { ruleStatus = nil }
        }
    }

    private func statBox(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Color.textMuted)
            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundColor(Color.deepNavy)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.borderSubtle, lineWidth: 1.2))
    }
    
    private func applyCategoryChange(_ cat: SpendingCategory) {
        for tx in merchantTransactions {
            tx.category = cat
            tx.isConfirmed = true
            tx.confidenceScore = 1.0
        }
        try? modelContext.save()
        if rememberCategory {
            DatabaseService.shared.rememberCorrection(merchant: merchantName, category: cat)
        }
        Haptics.impact(.light)
    }
}
