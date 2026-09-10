import SwiftUI

public struct CityTapCoachmark: View {
    public let onDismiss: () -> Void
    @EnvironmentObject private var l10n: LocalizationManager

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                MoneyIcon(.home, size: 30)
                    .padding(10)
                    .background(Color.spentGreenSoft, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.isHebrew ? "מכירים את העיר" : "Meet your city")
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.textSecondary)
                    Text(l10n.isHebrew ? "לכל בניין יש סיפור" : "Every building has a story")
                        .font(.headline).foregroundStyle(Color.deepNavy)
                }
                Spacer(minLength: 0)
            }
            Text(l10n.isHebrew
                 ? "הקש על הבניין המסומן בעיר כדי לגלות אילו הוצאות בנו אותו."
                 : "Tap the marked building to discover the expenses behind it.")
                .font(.subheadline).foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(l10n.isHebrew ? "אגלה בעצמי" : "I'll explore on my own", action: onDismiss)
            .font(.subheadline.weight(.semibold)).foregroundStyle(Color.deepNavy)
            .frame(minHeight: 44)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.borderSubtle, lineWidth: 1))
        .shadow(color: Color.deepNavy.opacity(0.07), radius: 16, y: 6)
        .padding(.horizontal, 16)
    }
}

public struct RecurringExpensesCoachmark: View {
    public let onAddRecurring: () -> Void
    public let onDismiss: () -> Void
    @EnvironmentObject private var l10n: LocalizationManager

    public init(onAddRecurring: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.onAddRecurring = onAddRecurring
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                MoneyIcon(.receipt, size: 26, color: Color.primaryBlue)
                    .padding(10)
                    .background(Color.primaryBlue.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.isHebrew ? "שגרת העיר" : "City routine")
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.textSecondary)
                    Text(l10n.isHebrew ? "יש לך הוצאות קבועות?" : "Have fixed expenses?")
                        .font(.headline).foregroundStyle(Color.deepNavy)
                }
                Spacer(minLength: 0)
            }
            Text(l10n.isHebrew
                 ? "שכירות, מנויים או חשבונות חודשיים? הוסף אותם כעת כדי שהעיר תחשב אותם אוטומטית בכל חודש."
                 : "Rent, subscriptions, or fixed bills? Add them so your city accounts for them automatically.")
                .font(.subheadline).foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(action: onAddRecurring) {
                    Text(l10n.isHebrew ? "הוספת הוצאות קבועות" : "Add fixed expenses")
                        .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.deepNavy, in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Text(l10n.isHebrew ? "אולי אחר כך" : "Maybe later")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.borderSubtle, lineWidth: 1))
        .shadow(color: Color.deepNavy.opacity(0.07), radius: 16, y: 6)
        .padding(.horizontal, 16)
    }
}

public struct FirstTransactionCard: View {
    public let isViewingPastMonth: Bool
    public let onReturnToCurrentMonth: () -> Void
    public let onAddExpense: () -> Void
    @EnvironmentObject private var l10n: LocalizationManager

    public init(
        isViewingPastMonth: Bool,
        onReturnToCurrentMonth: @escaping () -> Void,
        onAddExpense: @escaping () -> Void
    ) {
        self.isViewingPastMonth = isViewingPastMonth
        self.onReturnToCurrentMonth = onReturnToCurrentMonth
        self.onAddExpense = onAddExpense
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                MoneyIcon(.citySkyline, size: 36).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(isViewingPastMonth
                         ? (l10n.isHebrew ? "אין הוצאות בחודש הזה" : "No expenses this month")
                         : (l10n.isHebrew ? "העיר מחכה לסיפור שלך" : "Your city is ready for your story"))
                        .font(.headline).foregroundStyle(Color.deepNavy)
                    Text(isViewingPastMonth
                         ? (l10n.isHebrew ? "אפשר לחזור לחודש הנוכחי ולהמשיך לבנות את העיר שלך." : "Return to this month to continue your city's story.")
                         : (l10n.isHebrew ? "הוסף הוצאה שכבר ביצעת וראה איפה היא מופיעה בעיר."
                         : "Add a purchase you've made and see where it appears in your city."))
                        .font(.subheadline).foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button {
                if isViewingPastMonth { onReturnToCurrentMonth() } else { onAddExpense() }
            } label: {
                Text(isViewingPastMonth ? (l10n.isHebrew ? "חזרה לחודש הנוכחי" : "Back to this month")
                     : (l10n.isHebrew ? "הוספת הוצאה" : "Add an expense"))
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.deepNavy, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
    }
}
