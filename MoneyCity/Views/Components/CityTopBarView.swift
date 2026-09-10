import SwiftUI

/// Top navigation bar for the city tab: SPENT branding, companion gift shortcut with badge, and Zen mode toggle.
public struct CityTopBarView: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let hasWeeklyReward: Bool
    @Binding var isZenMode: Bool
    let onOpenCompanions: () -> Void

    public init(
        hasWeeklyReward: Bool,
        isZenMode: Binding<Bool>,
        onOpenCompanions: @escaping () -> Void
    ) {
        self.hasWeeklyReward = hasWeeklyReward
        self._isZenMode = isZenMode
        self.onOpenCompanions = onOpenCompanions
    }

    public var body: some View {
        HStack(alignment: .center) {
            Text("SPENT")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(Color.deepNavy)
                .tracking(0.5)

            Spacer()

            Button {
                onOpenCompanions()
            } label: {
                MoneyIcon(.gift, size: 24)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.94), in: Circle())
                    .overlay(alignment: .topTrailing) {
                        if hasWeeklyReward {
                            Circle().fill(Color.themeMint).frame(width: 10, height: 10)
                        }
                    }
            }
            .accessibilityLabel(l10n.isHebrew ? "מצטרפים לעיר — הפרס השבועי" : "City companions — weekly reward")

            Button(action: {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    isZenMode.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.94))
                        .frame(width: 38, height: 38)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
                    DioramaExpandVectorIcon(isExpanded: isZenMode, color: Color.deepNavy)
                        .frame(width: 15, height: 15)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }
}

/// Banner that informs the user the previous month's city is ready for recap.
public struct CityNewMonthRecapBanner: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let recap: MonthlyRecap
    let onOpen: () -> Void
    let onDismiss: () -> Void

    public init(
        recap: MonthlyRecap,
        onOpen: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.recap = recap
        self.onOpen = onOpen
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.spentGreenSoft)
                    .frame(width: 32, height: 32)
                MoneyIcon(.trophy, size: 16, color: Color.spentGreen)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.language == .hebrew ? "העיר של \(recap.monthNameHe) מוכנה לסיכום!" : "\(recap.monthNameEn) City is Ready!")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                Text(l10n.language == .hebrew ? "הקש לצפייה בסיכום החודשי שלך" : "Tap to view your monthly recap")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
            }
            
            Spacer()
            
            Button(action: onOpen) {
                Text(l10n.language == .hebrew ? "צפה" : "View")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.spentGreen)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Button(action: onDismiss) {
                MoneyIcon(.xmarkCircle, size: 16, color: Color.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
        .padding(.horizontal, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// Hero KPI row displaying total spend with rolling number animation.
public struct CityHeroKpiRow: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let spentValue: Double

    public init(spentValue: Double) {
        self.spentValue = spentValue
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RollingNumberText(
                value: spentValue,
                format: { (amt: Double) -> String in l10n.format(amount: amt) }
            )

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}
