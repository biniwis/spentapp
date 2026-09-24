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
        HStack(alignment: .center, spacing: 8) {
            Text("SPENT")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(Color.deepNavy)
                .tracking(0.5)

            #if !SWIFT_PACKAGE
            ScopeSelectorMenu()
            #endif

            Spacer()

            if RemoteConfigService.shared.isFeatureEnabled("weeklyAdditions") {
                Button {
                    onOpenCompanions()
                } label: {
                    MoneyIcon(.gift, size: 24)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.94), in: Circle())
                        .overlay(alignment: .topTrailing) {
                            if hasWeeklyReward {
                                Circle().fill(MoneyCityTheme.neonLime).frame(width: 10, height: 10)
                            }
                        }
                }
                .accessibilityLabel(l10n.isHebrew ? "מצטרפים לעיר — תוספת שבועית" : "City companions — weekly addition")
            }

            Button(action: {
                Haptics.selection()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                    isZenMode.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.94))
                        .frame(width: 38, height: 38)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
                    DioramaExpandVectorIcon(isExpanded: isZenMode, color: MoneyCityTheme.textPrimary)
                        .frame(width: 15, height: 15)
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
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
                    .fill(MoneyCityTheme.babyBlue)
                    .frame(width: 32, height: 32)
                MoneyIcon(.trophy, size: 16)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.language == .hebrew ? "העיר של \(recap.monthNameHe) מוכנה לסיכום!" : "\(recap.monthNameEn) City is Ready!")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(MoneyCityTheme.textPrimary)
                Text(l10n.language == .hebrew ? "הקש לצפייה בסיכום החודשי שלך" : "Tap to view your monthly recap")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(MoneyCityTheme.textMuted)
            }
            
            Spacer()
            
            Button(action: onOpen) {
                Text(l10n.language == .hebrew ? "צפה" : "View")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(MoneyCityTheme.jetBlack)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(MoneyCityTheme.brandPrimary)
                    .clipShape(Capsule())
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Button(action: onDismiss) {
                MoneyIcon(.xmarkCircle, size: 16, color: MoneyCityTheme.textMuted)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
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

#if !SWIFT_PACKAGE
public struct ScopeSelectorMenu: View {
    @ObservedObject private var scopeContext = AppScopeContext.shared
    @ObservedObject private var sharedStore = SharedWorkspaceStore.shared
    @EnvironmentObject private var l10n: LocalizationManager

    public init() {}

    public var body: some View {
        Menu {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    scopeContext.selectPersonal()
                }
            } label: {
                Label(
                    l10n.isHebrew ? "העיר שלי" : "My City",
                    systemImage: scopeContext.activeScope == .personal ? "checkmark" : "person"
                )
            }

            if !sharedStore.spaces.isEmpty {
                Section(l10n.isHebrew ? "מרחבים משותפים" : "Shared Spaces") {
                    ForEach(sharedStore.spaces) { space in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                scopeContext.selectShared(spaceID: space.id)
                            }
                        } label: {
                            Label(
                                space.name,
                                systemImage: scopeContext.activeScope.spaceID == space.id ? "checkmark" : "person.2"
                            )
                        }
                    }
                }
            }

            Divider()

            Button {
                sharedStore.showSetup = true
            } label: {
                Label(
                    l10n.isHebrew ? "ניהול מרחבים..." : "Manage Spaces...",
                    systemImage: "gearshape"
                )
            }
        } label: {
            HStack(spacing: 5) {
                if scopeContext.capabilities.isShared {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(MoneyCityTheme.brandPrimary)
                }
                Text(scopeContext.displayName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(scopeContext.capabilities.isShared ? MoneyCityTheme.brandPrimary : MoneyCityTheme.textSecondary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(MoneyCityTheme.textSecondary.opacity(0.7))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(scopeContext.capabilities.isShared ? MoneyCityTheme.brandPrimary.opacity(0.12) : Color.black.opacity(0.04))
            )
        }
        .accessibilityLabel(l10n.isHebrew ? "בחירת מרחב עבודה" : "Choose workspace")
    }
}
#endif
