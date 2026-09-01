import SwiftUI

/// Modern floating navigation bar with bespoke branded architectural icons
public struct FloatingBottomBar: View {
    @Binding public var activeTab: String
    public let onQuickAdd: () -> Void
    @EnvironmentObject private var l10n: LocalizationManager

    public init(activeTab: Binding<String>, onQuickAdd: @escaping () -> Void) {
        self._activeTab = activeTab
        self.onQuickAdd = onQuickAdd
    }

    public var body: some View {
        HStack(spacing: 0) {
            navButton(id: "city", label: l10n.text(for: "tab_city")) { isSel, col in
                CityTabIcon(isSelected: isSel, color: col)
            }
            
            navButton(id: "analytics", label: l10n.text(for: "tab_analytics")) { isSel, col in
                AnalyticsTabIcon(isSelected: isSel, color: col)
            }

            // Central Royal Blue action button
            Button(action: {
                Haptics.impact(.medium)
                onQuickAdd()
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: MoneyCityTheme.radiusSmall + 5, style: .continuous)
                        .fill(Color.primaryBlue)
                        .frame(width: 52, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: MoneyCityTheme.radiusSmall + 5, style: .continuous)
                                .fill(MoneyCityTheme.edgeBlue)
                                .frame(width: 52, height: 52)
                                .offset(y: MoneyCityTheme.edgeThickness)
                        )
                        .cityFloat()
                    
                    // Tactile Bold Plus Symbol
                    ZStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white)
                            .frame(width: 18, height: 3.5)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white)
                            .frame(width: 3.5, height: 18)
                    }
                }
            }
            .bouncyPress(scale: 0.88)
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
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: MoneyCityTheme.radiusHero, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MoneyCityTheme.radiusHero, style: .continuous)
                .stroke(Color.borderSubtle, lineWidth: 1)
        )
        .cityFloat()
        .padding(.horizontal, 20)
    }

    private func navButton<IconContent: View>(
        id: String,
        label: String,
        @ViewBuilder icon: @escaping (_ isSelected: Bool, _ color: Color) -> IconContent
    ) -> some View {
        let isSelected = activeTab == id
        let tintColor = isSelected ? Color.primaryBlue : Color.textMuted
        
        return Button(action: {
            if activeTab != id {
                Haptics.selection()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
                    activeTab = id
                }
            }
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

// MARK: - Bespoke Architectural & Miniature Brand Icons

/// 1. City Tab Icon: Isometric Floating Diorama Island with twin towers and park tree
private struct CityTabIcon: View {
    let isSelected: Bool
    let color: Color
    
    var body: some View {
        ZStack {
            // Isometric base platform diamond
            IsometricTileShape()
                .fill(color.opacity(isSelected ? 0.22 : 0.12))
                .frame(width: 22, height: 10)
                .offset(y: 5)
            
            // Twin Skyline Towers
            HStack(alignment: .bottom, spacing: 2) {
                // Left tower
                VStack(spacing: 1.5) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color)
                        .frame(width: 6.5, height: 12)
                }
                
                // Right tower (taller with antenna)
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(color)
                        .frame(width: 1.2, height: 2.5)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color)
                        .frame(width: 7.5, height: 14)
                }
            }
            .offset(x: -3, y: -2)
            
            // Botanical diorama tree on the right
            VStack(spacing: 0) {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                Rectangle()
                    .fill(color)
                    .frame(width: 1.5, height: 3)
            }
            .offset(x: 7, y: 1.5)
        }
        .frame(width: 26, height: 24)
    }
}

/// 2. Analytics Tab Icon: 3-Bar Financial Growth Chart with Upward Trend Arrow
private struct AnalyticsTabIcon: View {
    let isSelected: Bool
    let color: Color
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 3 Ascending Metric Bars
            HStack(alignment: .bottom, spacing: 3) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color.opacity(isSelected ? 0.75 : 0.6))
                    .frame(width: 4, height: 7)
                
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color.opacity(isSelected ? 0.9 : 0.8))
                    .frame(width: 4, height: 11)
                
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: 4, height: 16)
            }
            .offset(y: 2)
            
            // Ascending Trend Line
            Path { path in
                path.move(to: CGPoint(x: 2, y: 15))
                path.addLine(to: CGPoint(x: 10, y: 9))
                path.addLine(to: CGPoint(x: 20, y: 2))
            }
            .stroke(color, style: StrokeStyle(lineWidth: isSelected ? 2.0 : 1.5, lineCap: .round))
            
            // Trend arrow peak dot
            Circle()
                .fill(color)
                .frame(width: 3.5, height: 3.5)
                .offset(x: 9, y: -10)
        }
        .frame(width: 26, height: 24)
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct IsometricTileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// 3. History Tab Icon: City Ledger Document with Folded Corner and Rule Lines
private struct HistoryTabIcon: View {
    let isSelected: Bool
    let color: Color
    
    var body: some View {
        ZStack {
            // Main document sheet
            RoundedRectangle(cornerRadius: 3.5)
                .fill(color)
                .frame(width: 15, height: 19)
            
            // 3 Horizontal Rule Lines
            VStack(alignment: .leading, spacing: 2.2) {
                RoundedRectangle(cornerRadius: 0.8)
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 9, height: 1.8)
                
                RoundedRectangle(cornerRadius: 0.8)
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 7, height: 1.8)
                
                RoundedRectangle(cornerRadius: 0.8)
                    .fill(Color.white.opacity(isSelected ? 0.95 : 0.7))
                    .frame(width: 4.5, height: 1.8)
            }
            .offset(x: -0.5, y: -0.5)
            
            // Bottom Right Verified Seal Dot
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 3.5, height: 3.5)
                .offset(x: 3.5, y: 5)
        }
        .frame(width: 26, height: 24)
    }
}

/// 4. Profile Tab Icon: Mayor Identity Shield & Citizen Silhouette
private struct ProfileTabIcon: View {
    let isSelected: Bool
    let color: Color
    
    var body: some View {
        ZStack {
            // Shield Crest Outer Frame
            RoundedRectangle(cornerRadius: 7)
                .stroke(color, lineWidth: isSelected ? 2.0 : 1.6)
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isSelected ? color.opacity(0.12) : Color.clear)
                )
            
            // Citizen Head & Shoulders Silhouette
            VStack(spacing: 1.5) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                
                Capsule()
                    .fill(color)
                    .frame(width: 11, height: 4)
            }
            .offset(y: 0.5)
        }
        .frame(width: 26, height: 24)
    }
}
