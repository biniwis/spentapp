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
                        MoneyIcon(.calendar, size: 44)
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
                                if isCurrentMonthInProgress(monthDate) {
                                    currentMonthInProgressRow(monthDate)
                                } else {
                                    let recap = MonthlyRecapService.generateRecap(
                                        for: monthDate,
                                        allTransactions: allTransactions,
                                        monthlyBudget: effectiveMonthlyBudget
                                    )
                                    
                                    Button {
                                        selectedRecap = recap
                                    } label: {
                                        recapRow(recap)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle(l10n.language == .hebrew ? "ארכיון סיכומים" : "Recaps Archive")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.language == .hebrew ? "סגור" : "Close") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.primaryBlue)
                }
            }
            .fullScreenCover(item: $selectedRecap) { recap in
                MonthlyRecapSheet(
                    recap: recap,
                    onNavigateToCity: { targetDate in
                        dismiss()
                        onNavigateToCity?(targetDate)
                    }
                )
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
                MoneyIcon(recap.cityVibe.moneyIcon, size: 22)
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
            
            MoneyIcon(l10n.language == .hebrew ? .chevronLeft : .chevronRight, size: 12)
                .foregroundColor(Color.borderSubtle)
                .padding(.leading, 4)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.deepNavy.opacity(0.03), radius: 8, y: 2)
    }

    private func isCurrentMonthInProgress(_ date: Date) -> Bool {
        let cal = Calendar.current
        guard cal.isDate(date, equalTo: Date(), toGranularity: .month) else { return false }
        let status = MonthlyRecapService.checkRecapWindow()
        return !(status.isActive && status.isFinalDayOfCurrentMonth)
    }

    private func monthName(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: l10n.language == .hebrew ? "he_IL" : "en_US")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date)
    }

    private func currentMonthInProgressRow(_ monthDate: Date) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 243/255, green: 244/255, blue: 246/255))
                    .frame(width: 48, height: 48)
                MoneyIcon(.citySkyline, size: 22, color: Color.textSecondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(monthName(monthDate))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                Text(l10n.language == .hebrew
                     ? "העיר עדיין נבנית... הסיכום יהיה זמין בסוף החודש 🏙️"
                     : "City is still growing... Recap arrives at month end 🏙️")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Text(l10n.language == .hebrew ? "נבנה כעת" : "In progress")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color(red: 243/255, green: 244/255, blue: 246/255))
                .clipShape(Capsule())
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.deepNavy.opacity(0.03), radius: 8, y: 2)
    }
}
