import SwiftUI
import SwiftData

/// Archive of all past monthly recaps, accessible from the Profile screen.
public struct MonthlyRecapArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager
    @Query(sort: \Transaction.timestamp, order: .reverse) private var allTransactions: [Transaction]
    @AppStorage("monthly_budget") private var userMonthlyBudget: Double = 0
    @Query private var categoryBudgets: [CategoryBudget]
    
    private var effectiveMonthlyBudget: Double {
        BudgetService.monthlySpendingBudget(
            categoryBudgets: categoryBudgets,
            overallBudget: userMonthlyBudget
        )
    }
    
    @State private var selectedRecap: MonthlyRecap? = nil
    var onNavigateToCity: ((Date) -> Void)? = nil
    
    private var availableMonths: [Date] {
        MonthlyRecapService.availableRecapMonths(from: allTransactions)
    }
    
    public init(onNavigateToCity: ((Date) -> Void)? = nil) {
        self.onNavigateToCity = onNavigateToCity
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 248/255, green: 250/255, blue: 252/255).ignoresSafeArea()
                
                if availableMonths.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 44))
                            .foregroundColor(Color.textMuted)
                        Text(l10n.language == .hebrew ? "אין עדיין סיכומים חודשיים" : "No Monthly Recaps Yet")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        Text(l10n.language == .hebrew ? "הסיכום החודשי הראשון שלך יופיע בסיום החודש" : "Your first recap will appear at the end of the month")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color.textMuted)
                    }
                    .padding(32)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(availableMonths, id: \.self) { monthDate in
                                let recap = MonthlyRecapService.generateRecap(
                                    for: monthDate,
                                    allTransactions: allTransactions,
                                    monthlyBudget: effectiveMonthlyBudget
                                )
                                
                                Button(action: {
                                    Haptics.impact(.light)
                                    selectedRecap = recap
                                }) {
                                    recapRow(recap)
                                }
                                .bouncyPress(scale: 0.96)
                            }
                            Spacer(minLength: 40)
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle(l10n.language == .hebrew ? "סיכומים חודשיים" : "Monthly Recaps")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.language == .hebrew ? "סגור" : "Close") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                }
            }
            .sheet(item: $selectedRecap) { recap in
                MonthlyRecapSheet(recap: recap) { targetDate in
                    dismiss()
                    onNavigateToCity?(targetDate)
                }
                .presentationDetents([.large])
                .environmentObject(l10n)
            }
        }
    }
    
    private func recapRow(_ recap: MonthlyRecap) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.themeLavenderSoft)
                    .frame(width: 48, height: 48)
                Image(systemName: recap.cityVibe.badgeIcon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.themeLavender)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(l10n.language == .hebrew ? recap.monthNameHe : recap.monthNameEn)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                
                Text(l10n.language == .hebrew ? recap.cityVibe.titleHe : recap.cityVibe.titleEn)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textMuted)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(l10n.format(amount: recap.totalSpent))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                
                Text(l10n.language == .hebrew ? "\(recap.transactionCount) עסקאות" : "\(recap.transactionCount) visits")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
            }
            
            Image(systemName: l10n.language == .hebrew ? "chevron.left" : "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.borderSubtle)
                .padding(.leading, 4)
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.borderSubtle, lineWidth: 1.2))
        .shadow(color: Color.deepNavy.opacity(0.03), radius: 8, y: 2)
    }
}
