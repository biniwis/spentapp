import SwiftUI

/// Modern floating navigation bar with bespoke branded architectural icons
public struct FloatingBottomBar: View {
    @Binding public var activeTab: String
    public let onQuickAdd: () -> Void
    /// Fired on every tab tap, including a tap on the tab already showing — which the bar
    /// used to swallow. That re-tap is how people expect to get back to the top of a
    /// section, so the screen needs to hear about it.
    public let onTabTapped: ((String) -> Void)?
    @EnvironmentObject private var l10n: LocalizationManager

    public init(
        activeTab: Binding<String>,
        onQuickAdd: @escaping () -> Void,
        onTabTapped: ((String) -> Void)? = nil
    ) {
        self._activeTab = activeTab
        self.onQuickAdd = onQuickAdd
        self.onTabTapped = onTabTapped
    }

    public var body: some View {
        HStack(spacing: 0) {
            navButton(id: "city", label: l10n.text(for: "tab_city")) { isSel, col in
                CityTabIcon(isSelected: isSel, color: col)
            }
            
            navButton(id: "analytics", label: l10n.text(for: "tab_analytics")) { isSel, col in
                AnalyticsTabIcon(isSelected: isSel, color: col)
            }

            // Central Action Button (Green Plus Circle from New Icon Set - Balanced & Refined)
            Button(action: {
                Haptics.impact(.medium)
                onQuickAdd()
            }) {
                MoneyIcon(.plusCircle, size: 46)
                    .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 2)
            }
            .bouncyPress(scale: 0.90)
            .offset(y: -4)
            .frame(maxWidth: .infinity)

            navButton(id: "history", label: l10n.text(for: "tab_history")) { isSel, col in
                HistoryTabIcon(isSelected: isSel, color: col)
            }
            
            navButton(id: "profile", label: l10n.text(for: "tab_profile")) { isSel, col in
                ProfileTabIcon(isSelected: isSel, color: col)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 4)
        .padding(.horizontal, 24)
    }

    private func navButton<IconContent: View>(
        id: String,
        label: String,
        @ViewBuilder icon: @escaping (_ isSelected: Bool, _ color: Color) -> IconContent
    ) -> some View {
        let isSelected = activeTab == id
        let tintColor = isSelected ? Color.deepNavy : Color.textMuted
        
        return Button(action: {
            Haptics.selection()
            if activeTab != id {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
                    activeTab = id
                }
            }
            onTabTapped?(id)
        }) {
            VStack(spacing: 4) {
                icon(isSelected, tintColor)
                    .scaleEffect(isSelected ? 1.12 : 1.0)
                
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .black : .bold, design: .rounded))
                    .foregroundColor(tintColor)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .bouncyPress(scale: 0.92)
    }
}

// MARK: - Bespoke Architectural & Miniature Brand Icons (New Set)

/// 1. City Tab Icon: House / Home from New Set
private struct CityTabIcon: View {
    let isSelected: Bool
    let color: Color
    
    var body: some View {
        MoneyIcon(.home, size: 24, color: isSelected ? nil : color)
            .opacity(isSelected ? 1.0 : 0.65)
    }
}

/// 2. Analytics Tab Icon: 3-Bar Financial Growth Chart from New Set
private struct AnalyticsTabIcon: View {
    let isSelected: Bool
    let color: Color
    
    var body: some View {
        MoneyIcon(.barChart, size: 24, color: isSelected ? nil : color)
            .opacity(isSelected ? 1.0 : 0.65)
    }
}

/// 3. History Tab Icon: City Ledger / Receipt Document from New Set
private struct HistoryTabIcon: View {
    let isSelected: Bool
    let color: Color
    
    var body: some View {
        MoneyIcon(.receipt, size: 24, color: isSelected ? nil : color)
            .opacity(isSelected ? 1.0 : 0.65)
    }
}

/// 4. Profile Tab Icon: Citizen Avatar Bust from New Set
private struct ProfileTabIcon: View {
    let isSelected: Bool
    let color: Color
    
    var body: some View {
        MoneyIcon(.user, size: 24, color: isSelected ? nil : color)
            .opacity(isSelected ? 1.0 : 0.65)
    }
}
