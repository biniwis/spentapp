import SwiftUI

/// Modern floating navigation bar with bespoke branded architectural icons
@MainActor
public struct FloatingBottomBar: View {
    @Binding public var activeTab: String
    public let onQuickAdd: () -> Void
    public let onLongPressAdd: (() -> Void)?
    /// Fired on every tab tap, including a tap on the tab already showing — which the bar
    /// used to swallow. That re-tap is how people expect to get back to the top of a
    /// section, so the screen needs to hear about it.
    public let onTabTapped: ((String) -> Void)?
    @EnvironmentObject private var l10n: LocalizationManager

    @State private var isPlusSquished = false
    @State private var didFireLongPress = false
    @State private var pressTimer: Timer? = nil

    public init(
        activeTab: Binding<String>,
        onQuickAdd: @escaping () -> Void,
        onTabTapped: ((String) -> Void)? = nil,
        onLongPressAdd: (() -> Void)? = nil
    ) {
        self._activeTab = activeTab
        self.onQuickAdd = onQuickAdd
        self.onTabTapped = onTabTapped
        self.onLongPressAdd = onLongPressAdd
    }

    public var body: some View {
        HStack(spacing: 0) {
            navButton(id: "city", label: l10n.text(for: "tab_city")) { _, _ in
                MoneyIcon(.home, size: 24)
            }
            
            navButton(id: "analytics", label: l10n.text(for: "tab_analytics")) { _, _ in
                MoneyIcon(.barChart, size: 24)
            }

            // Central Action Button (Lucky Green Plus Circle - Tactile Long Press)
            ZStack {
                MoneyIcon(.plusCircle, size: 48)
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
            }
            .scaleEffect(isPlusSquished ? 0.86 : 1.0)
            .animation(.spring(response: 0.20, dampingFraction: 0.65), value: isPlusSquished)
            .offset(y: -4)
            .frame(maxWidth: .infinity)
            .contentShape(Circle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPlusSquished {
                            isPlusSquished = true
                            didFireLongPress = false
                            Haptics.impact(.light)
                            pressTimer?.invalidate()
                            let timer = Timer(timeInterval: 0.32, repeats: false) { _ in
                                DispatchQueue.main.async {
                                    didFireLongPress = true
                                    Haptics.impact(.medium)
                                    onLongPressAdd?()
                                }
                            }
                            RunLoop.main.add(timer, forMode: .common)
                            pressTimer = timer
                        }
                    }
                    .onEnded { _ in
                        pressTimer?.invalidate()
                        pressTimer = nil
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                            isPlusSquished = false
                        }
                        if !didFireLongPress {
                            Haptics.impact(.light)
                            onQuickAdd()
                        }
                        didFireLongPress = false
                    }
            )

            navButton(id: "history", label: l10n.text(for: "tab_history")) { _, _ in
                MoneyIcon(.receipt, size: 24)
            }
            
            navButton(id: "profile", label: l10n.text(for: "tab_profile")) { _, _ in
                MoneyIcon(.user, size: 24)
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
        let tintColor = isSelected ? MoneyCityTheme.textPrimary : MoneyCityTheme.textMuted
        
        return Button(action: {
            Haptics.selection()
            if activeTab != id {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
                    activeTab = id
                }
            }
            onTabTapped?(id)
        }) {
            VStack(spacing: 3) {
                icon(isSelected, tintColor)
                    .grayscale(isSelected ? 0.0 : 1.0)
                    .opacity(isSelected ? 1.0 : 0.38)
                    .scaleEffect(isSelected ? 1.08 : 1.0)
                    .animation(.spring(response: 0.32, dampingFraction: 0.75), value: isSelected)
                
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .black : .semibold, design: .rounded))
                    .foregroundColor(tintColor)
                    .animation(.spring(response: 0.32, dampingFraction: 0.75), value: isSelected)

                // Clean minimal indicator dot
                Circle()
                    .fill(isSelected ? MoneyCityTheme.jetBlack : Color.clear)
                    .frame(width: 3.5, height: 3.5)
                    .animation(.spring(response: 0.32, dampingFraction: 0.75), value: isSelected)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .bouncyPress(scale: 0.92)
    }
}

