import SwiftUI

/// Compact Bottom Sheet / Peek for the Nature Reserve (שמורת הטבע).
/// Answers immediately: "Where do I stand this month against my planned spending pace?"
public struct ReserveModalView: View {
    public let snapshot: ReserveSnapshot
    public let onClose: () -> Void
    public let onOpenBudgetSetup: () -> Void

    @EnvironmentObject private var l10n: LocalizationManager

    public init(
        snapshot: ReserveSnapshot,
        onClose: @escaping () -> Void,
        onOpenBudgetSetup: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        self.onClose = onClose
        self.onOpenBudgetSetup = onOpenBudgetSetup
    }

    private var isHebrew: Bool { l10n.language == .hebrew }

    private var statusColor: Color {
        switch snapshot.state {
        case .noBudget:  return Color(red: 107/255, green: 114/255, blue: 128/255)
        case .calm:      return Color(red: 16/255, green: 185/255, blue: 129/255)
        case .balanced:  return Color(red: 34/255, green: 197/255, blue: 94/255)
        case .active:    return Color(red: 245/255, green: 158/255, blue: 11/255)
        case .busy:      return Color.deepNavy
        }
    }

    private var statusBgColor: Color {
        statusColor.opacity(0.12)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header Row
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.themeMintSoft)
                        .frame(width: 40, height: 40)
                    MoneyIcon(.leaf, size: 20, color: Color(red: 16/255, green: 185/255, blue: 129/255))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isHebrew ? "שמורת הטבע" : "Nature Sanctuary")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    Text(isHebrew ? "קצב ההוצאות של החודש" : "Monthly spending pace")
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(Color.textSecondary)
                }

                Spacer()

                Button(action: onClose) {
                    MoneyIcon(.xmarkCircle, size: 20, color: Color.textSecondary)
                }
                .buttonStyle(.plain)
                .bouncyPress(scale: 0.92)
            }

            if snapshot.hasBudget {
                budgetedPaceContent
            } else {
                noBudgetContent
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 6)
        .padding(.horizontal, 16)
    }

    // MARK: - Budgeted Pace Content
    @ViewBuilder
    private var budgetedPaceContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Hero Figures Row: ₪X מתוך ₪Y
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(l10n.format(amount: snapshot.monthlySpent))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                Text(isHebrew ? "מתוך \(l10n.format(amount: snapshot.monthlyBudget))" : "of \(l10n.format(amount: snapshot.monthlyBudget))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textSecondary)

                Spacer()

                // State Badge
                Text(snapshot.state.localizedTitle(isHebrew: isHebrew))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusBgColor)
                    .clipShape(Capsule())
            }

            // Dual Progress Comparison: Time elapsed vs Budget spent
            VStack(spacing: 8) {
                progressRow(
                    label: isHebrew ? "נוצל מהתקציב" : "Budget spent",
                    percent: Int(round(snapshot.budgetUsageRatio * 100)),
                    ratio: min(1.0, snapshot.budgetUsageRatio),
                    color: statusColor
                )

                progressRow(
                    label: isHebrew ? "מהחודש עבר" : "Month elapsed",
                    percent: Int(round(snapshot.monthProgressRatio * 100)),
                    ratio: snapshot.monthProgressRatio,
                    color: Color(red: 156/255, green: 163/255, blue: 175/255)
                )
            }
            .padding(12)
            .background(Color(red: 249/255, green: 250/255, blue: 251/255))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Explanatory note & remainder
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.state.localizedDescription(isHebrew: isHebrew))
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(Color.textSecondary)
                }

                Spacer()

                if snapshot.remainingBudget > 0 {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(isHebrew ? "נותר בתקציב" : "Remaining in budget")
                            .font(.system(size: 11, weight: .medium, design: .default))
                            .foregroundColor(Color.textSecondary)
                        Text(l10n.format(amount: snapshot.remainingBudget))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                    }
                }
            }
        }
    }

    private func progressRow(label: String, percent: Int, ratio: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundColor(Color.textSecondary)
                Spacer()
                Text("\(percent)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(red: 229/255, green: 231/255, blue: 235/255))
                        .frame(height: 6)
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * CGFloat(min(1.0, max(0.0, ratio))), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - No Budget Content
    @ViewBuilder
    private var noBudgetContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isHebrew
                 ? "כדי שהפארק ישקף את קצב החודש, אפשר להגדיר כמה בערך תרצה להוציא בכל חודש."
                 : "To have the park reflect your monthly pace, set your estimated monthly spending.")
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundColor(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onOpenBudgetSetup) {
                HStack(spacing: 6) {
                    MoneyIcon(.sliders, size: 16, color: .white)
                    Text(isHebrew ? "הגדרת תקציב" : "Set monthly budget")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.deepNavy)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .bouncyPress(scale: 0.96)
        }
    }
}
