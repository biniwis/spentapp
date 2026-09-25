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
    @State private var showAccountSwitcher = false

    public init() {}

    @ViewBuilder
    public var body: some View {
        if !sharedStore.spaces.isEmpty {
            Button {
                Haptics.selection()
                showAccountSwitcher = true
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
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .accessibilityLabel(l10n.isHebrew ? "בחירת חשבון" : "Choose account")
            .accessibilityValue(scopeContext.displayName)
            .sheet(isPresented: $showAccountSwitcher) {
                AccountSwitcherSheet(
                    scopeContext: scopeContext,
                    sharedStore: sharedStore
                )
                .environmentObject(l10n)
            }
        }
    }
}

struct AccountSwitcherSheet: View {
    @ObservedObject var scopeContext: AppScopeContext
    @ObservedObject var sharedStore: SharedWorkspaceStore
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var managingSpace: SharedSpace?

    init(scopeContext: AppScopeContext, sharedStore: SharedWorkspaceStore) {
        self.scopeContext = scopeContext
        self.sharedStore = sharedStore
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(l10n.isHebrew ? "בחירת מרחב" : "Select Space")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            Text(l10n.isHebrew ? "מעבר בין העיר האישית למרחבים משותפים" : "Switch between your personal city and shared spaces")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(Color.textSecondary)
                        }
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.deepNavy)
                                .frame(width: 32, height: 32)
                                .background(Color.white, in: Circle())
                                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Personal Account Card
                    let isPersonal = scopeContext.activeScope == .personal
                    Button {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            scopeContext.selectPersonal()
                        }
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(MoneyCityTheme.warmCream)
                                    .frame(width: 44, height: 44)
                                MoneyIcon(.user, size: 24)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l10n.isHebrew ? "העיר שלי" : "My City")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                Text(l10n.isHebrew ? "חשבון אישי" : "Personal account")
                                    .font(.system(size: 12, weight: .medium, design: .default))
                                    .foregroundColor(Color.textSecondary)
                            }
                            Spacer()
                            if isPersonal {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(MoneyCityTheme.brandPrimary)
                            }
                        }
                        .padding(16)
                        .background(isPersonal ? MoneyCityTheme.spentGreenSoft.opacity(0.55) : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.black.opacity(0.035), radius: 8, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)

                    // Shared Spaces Section
                    if !sharedStore.spaces.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(l10n.isHebrew ? "מרחבים משותפים" : "Shared Spaces")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color.textSecondary)
                                .padding(.horizontal, 20)

                            VStack(spacing: 10) {
                                ForEach(sharedStore.spaces) { space in
                                    let isSelected = scopeContext.activeScope.spaceID == space.id
                                    let spaceMembers = sharedStore.members.filter { $0.spaceID == space.id }
                                    Button {
                                        Haptics.selection()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            scopeContext.selectShared(spaceID: space.id)
                                        }
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 14) {
                                            HStack(spacing: -8) {
                                                if spaceMembers.isEmpty {
                                                    MoneyIcon(.users, size: 20, color: Color.deepNavy)
                                                        .frame(width: 44, height: 44)
                                                        .background(MoneyCityTheme.babyBlue.opacity(0.5), in: Circle())
                                                } else {
                                                    ForEach(spaceMembers.prefix(3)) { member in
                                                        SharedMemberMark(colorHex: member.colorHex, size: 36)
                                                    }
                                                }
                                            }

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(space.name)
                                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                                    .foregroundColor(Color.deepNavy)
                                                    .lineLimit(1)
                                                Text(l10n.isHebrew ? "חשבון משותף · \(space.currencyCode)" : "Shared account · \(space.currencyCode)")
                                                    .font(.system(size: 12, weight: .medium, design: .default))
                                                    .foregroundColor(Color.textSecondary)
                                            }

                                            Spacer()

                                            if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 20, weight: .semibold))
                                                    .foregroundColor(MoneyCityTheme.brandPrimary)
                                            }
                                        }
                                        .padding(16)
                                        .background(isSelected ? MoneyCityTheme.spentGreenSoft.opacity(0.55) : Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .shadow(color: Color.black.opacity(0.035), radius: 8, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // Bottom Actions
                    VStack(spacing: 8) {
                        Button {
                            dismiss()
                            sharedStore.showSetup = true
                        } label: {
                            HStack(spacing: 8) {
                                MoneyIcon(.plusCircle, size: 16, color: MoneyCityTheme.brandPrimary)
                                Text(l10n.isHebrew ? "יצירה או הצטרפות למרחב" : "Create or Join Space")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(MoneyCityTheme.brandPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(MoneyCityTheme.spentGreenSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        if let active = sharedStore.activeSpace {
                            Button {
                                managingSpace = active
                            } label: {
                                HStack(spacing: 6) {
                                    MoneyIcon(.gear, size: 14, color: Color.textSecondary)
                                    Text(l10n.isHebrew ? "ניהול מרחב: \(active.name)" : "Manage: \(active.name)")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                }
                                .foregroundColor(Color.textSecondary)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                }
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .sheet(item: $managingSpace) { space in
                SharedSpaceManagement(space: space)
                    .environmentObject(l10n)
            }
        }
        .presentationDetents([.medium, .fraction(0.7)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBackground)
    }
}

/// Member colors match the city shirts; names remain the primary identifier.
struct SharedMemberMark: View {
    let colorHex: String
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: colorHex).opacity(0.18))
            MoneyIcon(.user, size: size * 0.7, color: Color(hex: colorHex))
        }
        .frame(width: size, height: size)
        .background(Color.white, in: Circle())
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
                MoneyIcon(.user, size: 18, color: MoneyCityTheme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.04), in: Circle())
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

/// Selection uses a checkmark and soft background, no stroke. Large text stacks the choices.
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
                .background(selected ? MoneyCityTheme.spentGreenSoft : Color.white,
                            in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.02), radius: 4, y: 1)
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
