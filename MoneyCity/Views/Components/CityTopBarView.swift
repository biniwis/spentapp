import SwiftUI

/// Top navigation bar for the city tab: SPENT branding, companion gift shortcut with badge, and Zen mode toggle.
public struct CityTopBarView: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let hasWeeklyReward: Bool
    let allowsCompanions: Bool
    @Binding var isZenMode: Bool
    let onOpenCompanions: () -> Void

    public init(
        hasWeeklyReward: Bool,
        allowsCompanions: Bool = true,
        isZenMode: Binding<Bool>,
        onOpenCompanions: @escaping () -> Void
    ) {
        self.hasWeeklyReward = hasWeeklyReward
        self.allowsCompanions = allowsCompanions
        self._isZenMode = isZenMode
        self.onOpenCompanions = onOpenCompanions
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("SPENT")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(Color.deepNavy)
                .tracking(0.5)


            Spacer()

            if allowsCompanions && RemoteConfigService.shared.isFeatureEnabled("weeklyAdditions") {
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
            AccountIdentityLabel(
                title: scopeContext.displayName,
                subtitle: scopeContext.activeScope.isShared
                    ? (l10n.isHebrew ? "חשבון משותף" : "Shared account")
                    : (l10n.isHebrew ? "חשבון אישי" : "Personal account"),
                members: scopeContext.participants,
                showsChevron: true
            )
        }
        .frame(minHeight: 44)
        .accessibilityLabel(l10n.isHebrew ? "בחירת חשבון" : "Choose account")
        .accessibilityValue(scopeContext.displayName)
    }
}

/// Member colors match the city shirts; names remain the primary identifier.
struct SharedMemberMark: View {
    let colorHex: String
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: "tshirt.fill")
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(Color(hex: colorHex))
            .frame(width: size, height: size)
            .background(Color(hex: colorHex).opacity(0.10), in: Circle())
            .overlay(Circle().stroke(MoneyCityTheme.appBackground, lineWidth: 2))
            .accessibilityHidden(true)
    }
}

/// Same identity treatment in the shell and on the pinned expense destination.
struct AccountIdentityLabel: View {
    let title: String
    let subtitle: String
    let members: [SharedMember]
    var showsChevron = false

    var body: some View {
        HStack(spacing: 10) {
            if members.isEmpty {
                Image(systemName: "person.crop.circle")
                    .font(.title3)
                    .foregroundStyle(MoneyCityTheme.textSecondary)
                    .frame(width: 36, height: 36)
            } else {
                HStack(spacing: -8) {
                    ForEach(members.prefix(2)) { member in
                        SharedMemberMark(colorHex: member.colorHex, size: 32)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(MoneyCityTheme.textSecondary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MoneyCityTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MoneyCityTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Selection uses a checkmark and border, not color alone. Large text stacks the choices.
struct SharedPayerSelection: View {
    let title: String
    let members: [SharedMember]
    @Binding var selection: String
    var isEnabled = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MoneyCityTheme.textPrimary)
            if dynamicTypeSize.isAccessibilitySize || members.count > 2 {
                VStack(spacing: 8) { choices }
            } else {
                HStack(spacing: 8) { choices }
            }
        }
    }

    private var choices: some View {
        ForEach(members) { member in
            let selected = selection == member.id
            Button {
                Haptics.selection()
                selection = member.id
            } label: {
                HStack(spacing: 8) {
                    SharedMemberMark(colorHex: member.colorHex)
                    Text(member.name)
                        .font(.subheadline.weight(selected ? .semibold : .regular))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? MoneyCityTheme.brandPrimary : MoneyCityTheme.textMuted)
                }
                .foregroundStyle(MoneyCityTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(selected ? MoneyCityTheme.brandPrimary.opacity(0.06) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? MoneyCityTheme.brandPrimary : MoneyCityTheme.borderSubtle, lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.55)
            .accessibilityLabel(member.name)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }
}

#Preview("Shared identity · RTL") {
    let spaceID = UUID()
    let members = [
        SharedMember(id: "one", spaceID: spaceID, name: "בנימין", colorHex: "#5653E8", isActive: true),
        SharedMember(id: "two", spaceID: spaceID, name: "מאיה", colorHex: "#FF6446", isActive: true)
    ]
    VStack(alignment: .leading, spacing: 24) {
        AccountIdentityLabel(title: "הבית שלנו", subtitle: "חשבון משותף", members: members, showsChevron: true)
        Divider()
        SharedPayerSelection(title: "מי שילם?", members: members, selection: .constant("one"))
    }
    .padding(20)
    .background(MoneyCityTheme.appBackground)
    .environment(\.layoutDirection, .rightToLeft)
}
#endif
