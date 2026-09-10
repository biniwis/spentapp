import SwiftUI


/// 1. Settings Precision Cog / Dial
public struct SettingsGearVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.deepNavy) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.gear, size: 22, color: color)
    }
}

/// 2. Annual Vault / Double Coin Vector Token
public struct AnnualVaultVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeLavender) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.coins, size: 24, color: color)
    }
}

/// 3. Metric 3-Bar Histogram
public struct BarMetricVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeTurquoise) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.barChart, size: 24, color: color)
    }
}

/// 4. Active Streak Vector Flame
public struct StreakFlameVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeOrange) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.flame, size: 24, color: color)
    }
}

/// 5. Budget Target Reticle Vector
public struct TargetReticleVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeMint) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.target, size: 24, color: color)
    }
}

/// 6. Classical Treasury / Budgets Facade
public struct TreasuryVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeLavender) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.trophy, size: 24, color: color)
    }
}

/// 7. Recurring Fixed Expenses Calendar Flip-Pad
public struct RecurringCalendarVectorIcon: View {
    public let color: Color
    public init(color: Color = Color.themeOrange) { self.color = color }
    
    public var body: some View {
        MoneyIcon(.calendar, size: 24, color: color)
    }
}


/// 9. Bespoke City Enrichment Vector Badges
public struct EnrichmentVectorBadge: View {
    public let enrichment: CityEnrichment
    
    public var body: some View {
        let name = enrichment.name.lowercased()
        
        if name.contains("סקורה") || name.contains("sakura") || name.contains("פרח") {
            // Sakura Botanical Tree
            ZStack {
                Circle().fill(Color(red: 244/255, green: 114/255, blue: 182/255)).frame(width: 14, height: 14).offset(x: -4, y: -2)
                Circle().fill(Color(red: 251/255, green: 146/255, blue: 60/255).opacity(0.8)).frame(width: 12, height: 12).offset(x: 4, y: -3)
                Circle().fill(Color(red: 236/255, green: 72/255, blue: 153/255)).frame(width: 15, height: 15).offset(x: 0, y: -5)
                RoundedRectangle(cornerRadius: 1).fill(Color(red: 120/255, green: 53/255, blue: 15/255)).frame(width: 3.5, height: 9).offset(y: 6)
            }
            .frame(width: 28, height: 28)
        } else if name.contains("ספסל") || name.contains("bench") {
            // Park Bench
            ZStack {
                // Backrest
                RoundedRectangle(cornerRadius: 1).fill(Color(red: 180/255, green: 83/255, blue: 9/255)).frame(width: 18, height: 4).offset(y: -4)
                // Seat slat
                RoundedRectangle(cornerRadius: 1).fill(Color(red: 217/255, green: 119/255, blue: 6/255)).frame(width: 20, height: 3).offset(y: 1)
                // Legs
                HStack(spacing: 12) {
                    Rectangle().fill(Color.deepNavy).frame(width: 2, height: 7)
                    Rectangle().fill(Color.deepNavy).frame(width: 2, height: 7)
                }
                .offset(y: 5)
            }
            .frame(width: 28, height: 28)
        } else if name.contains("פנס") || name.contains("lamp") {
            // Victorian Street Lantern
            ZStack {
                Rectangle().fill(Color.deepNavy).frame(width: 2, height: 16).offset(y: 4)
                TriangleShape().fill(Color.deepNavy).frame(width: 11, height: 5).offset(y: -7)
                RoundedRectangle(cornerRadius: 1).fill(Color(red: 251/255, green: 191/255, blue: 36/255)).frame(width: 8, height: 8).offset(y: -2)
            }
            .frame(width: 28, height: 28)
        } else if name.contains("חתול") || name.contains("כלב") || name.contains("ג'ינג'י") || name.contains("pet") {
            // City Pet Mascot
            ZStack {
                // Head
                Circle().fill(Color(red: 245/255, green: 158/255, blue: 11/255)).frame(width: 15, height: 15)
                // Pointed ears
                HStack(spacing: 7) {
                    TriangleShape().fill(Color(red: 217/255, green: 119/255, blue: 6/255)).frame(width: 5, height: 5)
                    TriangleShape().fill(Color(red: 217/255, green: 119/255, blue: 6/255)).frame(width: 5, height: 5)
                }
                .offset(y: -8)
                // White muzzle
                Circle().fill(Color.white).frame(width: 6, height: 4).offset(y: 2)
            }
            .frame(width: 28, height: 28)
        } else if name.contains("ערוגה") || name.contains("פרחים") || name.contains("flower") {
            // Flowerbed Planter
            ZStack {
                // Planter Box
                RoundedRectangle(cornerRadius: 2).fill(Color(red: 5/255, green: 150/255, blue: 105/255)).frame(width: 20, height: 7).offset(y: 5)
                // 3 Floral Stems
                HStack(spacing: 3) {
                    Circle().fill(Color(red: 236/255, green: 72/255, blue: 153/255)).frame(width: 5.5, height: 5.5)
                    Circle().fill(Color(red: 239/255, green: 68/255, blue: 68/255)).frame(width: 6, height: 6).offset(y: -2)
                    Circle().fill(Color(red: 245/255, green: 158/255, blue: 11/255)).frame(width: 5.5, height: 5.5)
                }
                .offset(y: -2)
            }
            .frame(width: 28, height: 28)
        } else {
            DistrictParkVectorIcon(color: Color.themeMint)
                .scaleEffect(0.9)
        }
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


