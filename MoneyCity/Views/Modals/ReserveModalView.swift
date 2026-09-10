import SwiftUI

/// What the nature reserve knows about itself.
public struct ReserveSnapshot: Sendable {
    public let savedThisMonth: Double
    public let health: Double
    public let monthElapsed: Double
    public let spentThisMonth: Double
    public let plannedSpending: Double
    /// How many everyday categories the user put a ceiling on. Zero means the plan covers
    /// the whole month, so the card can say so rather than implying a narrower scope.
    public let budgetedCategoryCount: Int

    public init(
        savedThisMonth: Double,
        health: Double,
        monthElapsed: Double,
        spentThisMonth: Double,
        plannedSpending: Double,
        budgetedCategoryCount: Int
    ) {
        self.savedThisMonth = savedThisMonth
        self.health = health
        self.monthElapsed = monthElapsed
        self.spentThisMonth = spentThisMonth
        self.plannedSpending = plannedSpending
        self.budgetedCategoryCount = budgetedCategoryCount
    }
}

/// The reserve's own card.
///
/// Every other building answers "how much did I spend here". The reserve answers the exact
/// opposite — what stayed put — and it is the only thing in the city that carries over between
/// months. Handing it the spending card meant three fields that were either meaningless
/// (a visit count for a park) or actively wrong (a "trend" on money that was never spent).
public struct ReserveModalView: View {
    public let snapshot: ReserveSnapshot
    public let onClose: () -> Void
    public let onShowFeed: () -> Void
    @EnvironmentObject private var l10n: LocalizationManager

    public init(
        snapshot: ReserveSnapshot,
        onClose: @escaping () -> Void,
        onShowFeed: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        self.onClose = onClose
        self.onShowFeed = onShowFeed
    }

    private var isHebrew: Bool { l10n.language == .hebrew }
    private let reserveGreen = Color(red: 16/255, green: 185/255, blue: 129/255)

    /// The condition of the land, in words. The number itself means nothing to anyone.
    private var conditionText: String {
        switch snapshot.health {
        case 0.95...:     return isHebrew ? "פורחת" : "Flourishing"
        case 0.80..<0.95: return isHebrew ? "משגשגת" : "Thriving"
        case 0.68..<0.80: return isHebrew ? "מטופחת" : "Well kept"
        case 0.45..<0.68: return isHebrew ? "מתחילה להתייבש" : "Drying out"
        default:          return isHebrew ? "יבשה" : "Parched"
        }
    }

    private var conditionColor: Color {
        if snapshot.health >= 0.78 { return reserveGreen }
        if snapshot.health >= 0.55 { return Color.themeYellow }
        return Color.red
    }

    /// The number is now one thing: money the user recorded moving into savings this month.
    /// It used to add "budget you have not spent" on top, which is not money anyone holds and
    /// is why nobody could tell what the figure meant.
    private var basisText: String {
        if snapshot.savedThisMonth > 0 {
            return isHebrew
                ? "מה שסימנת החודש כחיסכון או השקעה"
                : "what you tagged as savings or investment this month"
        }
        // An empty figure should say how to fill it, not just that it is empty.
        return isHebrew
            ? "אין החודש. סמן הפקדה או השקעה בקטגוריה הזו והיא תופיע כאן."
            : "None this month. Tag a deposit or investment with this category and it appears here."
    }

    /// Straight-line projection, and only once enough of the month has gone by to mean anything.
    private var projection: Double? {
        guard snapshot.monthElapsed >= 0.20, snapshot.savedThisMonth > 0 else { return nil }
        return snapshot.savedThisMonth / snapshot.monthElapsed
    }

    private var sanctuaryNoteRow: some View {
        HStack(spacing: 8) {
            MoneyIcon(.leaf, size: 14)
            Text(isHebrew
                 ? "שמורת הטבע והחיסכון צומחת עם כל שקל שנשמר או הופקד ליעד. לחץ על התפריט המיוחד לניהול יעדים והפקדות."
                 : "The Nature Sanctuary grows with every shekel saved or deposited into goals. Tap below to manage goals.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            figuresRow
            sanctuaryNoteRow

            Divider().background(Color(red: 243/255, green: 244/255, blue: 246/255))
            footerRow
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 4)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            onShowFeed()
        }
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.themeMintSoft)
                    .frame(width: 44, height: 44)
                CategoryVectorIcon(category: .savings, size: 24)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(isHebrew ? "שמורת הטבע והחיסכון" : "Nature & Savings Reserve")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                Text(isHebrew ? "מצב החודש הזה" : "How this month is going")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textMuted)
            }

            Spacer()

            Button(action: onClose) {
                MoneyIcon(.xmarkCircle, size: 20)
                    .frame(width: 32, height: 32)
                    .background(Color.appBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .highPriorityGesture(TapGesture().onEnded { onClose() })
        }
    }

    private var figuresRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(SpendingCategory.savings.displayName(for: l10n.language))
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                Text("\(l10n.format(amount: snapshot.savedThisMonth.rounded()))")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(basisText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().frame(height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(isHebrew ? "מצב השמורה" : "Condition")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                Text(conditionText)
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundColor(conditionColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(isHebrew ? "מתאפס בכל חודש — הקרקע נשארת" : "Resets each month — the land stays")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footerRow: some View {
        HStack(spacing: 8) {
            if let projected = projection {
                Text(isHebrew ? "בקצב הזה:" : "At this rate:")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                Text(isHebrew
                     ? "\(l10n.format(amount: projected.rounded())) עד סוף החודש"
                     : "\(l10n.format(amount: projected.rounded())) by month end")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(reserveGreen)
                    .lineLimit(1)
            } else {
                Text(isHebrew ? "כל שקל שלא יוצא נשאר כאן" : "Every shekel that stays put lands here")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onShowFeed) {
                HStack(spacing: 5) {
                    MoneyIcon(.leaf, size: 14)
                    Text(isHebrew ? "תפריט השמורה ויעדים" : "Sanctuary & Goals")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Text(verbatim: isHebrew ? "‹" : "›")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(reserveGreen)
                .clipShape(Capsule())
                .shadow(color: reserveGreen.opacity(0.25), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .bouncyPress(scale: 0.94)
        }
    }
}
