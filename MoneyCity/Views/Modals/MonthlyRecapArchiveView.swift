import SwiftUI
import SwiftData

/// Archive of all past monthly recaps, accessible from the Profile screen.
public struct MonthlyRecapArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection
    @EnvironmentObject private var l10n: LocalizationManager
    @Query(sort: \Transaction.timestamp, order: .reverse) private var allTransactions: [Transaction]
    @AppStorage("monthly_budget") private var userMonthlyBudget: Double = 0
    @Query private var categoryBudgets: [CategoryBudget]
    
    private var effectiveMonthlyBudget: Double {
        BudgetService.monthlySpendingBudget(
            categoryBudgets: categoryBudgets,
            overallBudget: userMonthlyBudget
        )
    }
    
    @State private var selectedRecap: MonthlyRecap? = nil
    var onNavigateToCity: ((Date) -> Void)? = nil
    
    private var availableMonths: [Date] {
        MonthlyRecapService.availableRecapMonths(from: allTransactions)
    }
    
    public init(onNavigateToCity: ((Date) -> Void)? = nil) {
        self.onNavigateToCity = onNavigateToCity
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 248/255, green: 250/255, blue: 252/255).ignoresSafeArea()
                
                if availableMonths.isEmpty {
                    VStack(spacing: 12) {
                        MoneyIcon(.calendar, size: 44)
                        Text(l10n.language == .hebrew ? "אין עדיין סיכומים חודשיים" : "No Monthly Recaps Yet")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        Text(l10n.language == .hebrew ? "הסיכום החודשי הראשון שלך יופיע בסיום החודש" : "Your first recap will appear at the end of the month")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color.textMuted)
                    }
                    .padding(32)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            ForEach(availableMonths, id: \.self) { monthDate in
                                if isCurrentMonthInProgress(monthDate) {
                                    currentMonthInProgressCard(monthDate)
                                } else {
                                    let recap = MonthlyRecapService.generateRecap(
                                        for: monthDate,
                                        allTransactions: allTransactions,
                                        monthlyBudget: effectiveMonthlyBudget
                                    )
                                    
                                    Button {
                                        selectedRecap = recap
                                    } label: {
                                        completedRecapCard(recap)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle(l10n.language == .hebrew ? "ארכיון סיכומים" : "Recaps Archive")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.language == .hebrew ? "סגור" : "Close") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.primaryBlue)
                }
            }
            .fullScreenCover(item: $selectedRecap) { recap in
                MonthlyRecapSheet(
                    recap: recap,
                    onNavigateToCity: { targetDate in
                        dismiss()
                        onNavigateToCity?(targetDate)
                    }
                )
                .environmentObject(l10n)
            }
        }
    }
    
    // MARK: - Postcard Cards
    
    private func completedRecapCard(_ recap: MonthlyRecap) -> some View {
        let palette = ArchiveCityPalette.forDate(recap.date)
        let seed = stableSeed(for: recap.monthId)
        let isRTL = layoutDirection == .rightToLeft
        let monthTitle = l10n.language == .hebrew ? recap.monthNameHe : recap.monthNameEn
        let vibeTitle = l10n.language == .hebrew ? recap.cityVibe.titleHe : recap.cityVibe.titleEn
        let countText = l10n.language == .hebrew ? "\(recap.transactionCount) עסקאות" : "\(recap.transactionCount) visits"
        let spentText = l10n.format(amount: recap.totalSpent)
        
        return HStack(alignment: .bottom, spacing: 0) {
            // Text area (calm, legible, high-contrast)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text(monthTitle)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    
                    MoneyIcon(isRTL ? .chevronLeft : .chevronRight, size: 10)
                        .foregroundColor(Color.borderSubtle)
                }
                
                Text(vibeTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .padding(.top, 3)
                
                Spacer(minLength: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(spentText)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    
                    Text(countText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textMuted)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            
            // Illustrated miniature city (growing directly from the bottom edge)
            ArchiveCityArtwork(
                mode: .completed(vibe: recap.cityVibe.type, seed: seed),
                palette: palette,
                isRTL: isRTL
            )
            .frame(width: 165, height: 138, alignment: .bottom)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 138)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(palette.roofPrimary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.deepNavy.opacity(0.04), radius: 8, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(monthTitle), \(vibeTitle), \(l10n.language == .hebrew ? "הוצאות" : "spent") \(spentText), \(countText)")
        .accessibilityHint(l10n.language == .hebrew ? "הקש פעמיים לפתיחת סיכום חודשי" : "Double tap to open monthly recap")
    }

    private func currentMonthInProgressCard(_ monthDate: Date) -> some View {
        let palette = ArchiveCityPalette.forDate(monthDate)
        let monthId = MonthlyRecapService.monthId(for: monthDate)
        let seed = stableSeed(for: monthId.isEmpty ? "current" : monthId)
        let isRTL = layoutDirection == .rightToLeft
        let monthTitle = monthName(monthDate)
        let inProgressLabel = l10n.language == .hebrew ? "נבנה כעת" : "In progress"
        let statusTitle = l10n.language == .hebrew ? "העיר עדיין נבנית" : "The city is still growing"
        let statusSubtitle = l10n.language == .hebrew ? "הסיכום יהיה מוכן בסוף החודש" : "Your recap will be ready at month end"
        
        return HStack(alignment: .bottom, spacing: 0) {
            // Text area
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(monthTitle)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                }
                
                Text(inProgressLabel)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.spentGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.spentGreen.opacity(0.12))
                    .clipShape(Capsule())
                    .padding(.top, 6)
                
                Spacer(minLength: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    
                    Text(statusSubtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            
            // Illustrated miniature city under construction
            ArchiveCityArtwork(
                mode: .construction(seed: seed),
                palette: palette,
                isRTL: isRTL
            )
            .frame(width: 165, height: 138, alignment: .bottom)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 138)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(palette.roofPrimary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.deepNavy.opacity(0.04), radius: 8, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(monthTitle), \(statusTitle), \(statusSubtitle)")
    }

    private func isCurrentMonthInProgress(_ date: Date) -> Bool {
        let cal = Calendar.current
        guard cal.isDate(date, equalTo: Date(), toGranularity: .month) else { return false }
        let status = MonthlyRecapService.checkRecapWindow()
        return !(status.isActive && status.isFinalDayOfCurrentMonth)
    }

    private func monthName(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: l10n.language == .hebrew ? "he_IL" : "en_US")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date)
    }
    
    private func stableSeed(for id: String) -> Int {
        id.utf8.reduce(17) { (($0 &* 31) &+ Int($1)) & 0x7fffffff }
    }
}

// MARK: - Curated Palette System (Rooted in SPENT Visual Language)

private struct ArchiveCityPalette: Sendable {
    let cardBackground: Color
    let buildingPrimary: Color
    let buildingSecondary: Color
    let roofPrimary: Color
    let roofSecondary: Color
    let window: Color
    let treeLight: Color
    let treeDark: Color
    let ground: Color
    let road: Color
    let accent: Color
    let constructionAccent: Color

    static let palettes: [ArchiveCityPalette] = [
        // 0: Mint / Emerald (Transport & Savings inspired — #22C55E / #10B981)
        ArchiveCityPalette(
            cardBackground: Color(hex: "F2FAF5"),
            buildingPrimary: Color(hex: "FFFFFF"),
            buildingSecondary: Color(hex: "E1F5E9"),
            roofPrimary: Color(hex: "22C55E"),
            roofSecondary: Color(hex: "15803D"),
            window: Color(hex: "D1FAE5"),
            treeLight: Color(hex: "4ADE80"),
            treeDark: Color(hex: "16A34A"),
            ground: Color(hex: "DCFCE7"),
            road: Color(hex: "CBD5E1"),
            accent: Color(hex: "10B981"),
            constructionAccent: Color(hex: "F97316")
        ),
        // 1: Azure / Sky (Housing & Subscriptions inspired — #258CF4)
        ArchiveCityPalette(
            cardBackground: Color(hex: "F0F7FF"),
            buildingPrimary: Color(hex: "FFFFFF"),
            buildingSecondary: Color(hex: "DBEAFE"),
            roofPrimary: Color(hex: "258CF4"),
            roofSecondary: Color(hex: "1D4ED8"),
            window: Color(hex: "BAE6FD"),
            treeLight: Color(hex: "34D399"),
            treeDark: Color(hex: "059669"),
            ground: Color(hex: "E0F2FE"),
            road: Color(hex: "CBD5E1"),
            accent: Color(hex: "0284C7"),
            constructionAccent: Color(hex: "EA580C")
        ),
        // 2: Warm Peach / Amber (Food & Commerce inspired — #F97316 / #FFC529)
        ArchiveCityPalette(
            cardBackground: Color(hex: "FFF6F0"),
            buildingPrimary: Color(hex: "FFFFFF"),
            buildingSecondary: Color(hex: "FFEDD5"),
            roofPrimary: Color(hex: "F97316"),
            roofSecondary: Color(hex: "C2410C"),
            window: Color(hex: "FEF3C7"),
            treeLight: Color(hex: "4ADE80"),
            treeDark: Color(hex: "15803D"),
            ground: Color(hex: "FFEDD5"),
            road: Color(hex: "E2E8F0"),
            accent: Color(hex: "FFC529"),
            constructionAccent: Color(hex: "F97316")
        ),
        // 3: Soft Rose / Coral (Health & Shopping inspired — #FB7185 / #FF5757)
        ArchiveCityPalette(
            cardBackground: Color(hex: "FFF1F4"),
            buildingPrimary: Color(hex: "FFFFFF"),
            buildingSecondary: Color(hex: "FFE4E6"),
            roofPrimary: Color(hex: "FB7185"),
            roofSecondary: Color(hex: "BE123C"),
            window: Color(hex: "FCE7F3"),
            treeLight: Color(hex: "86EFAC"),
            treeDark: Color(hex: "16A34A"),
            ground: Color(hex: "FFE4E6"),
            road: Color(hex: "E2E8F0"),
            accent: Color(hex: "FF5757"),
            constructionAccent: Color(hex: "F97316")
        ),
        // 4: Lavender / Iris (Entertainment & Misc inspired — #A855F7 / #8B5CF6)
        ArchiveCityPalette(
            cardBackground: Color(hex: "F7F3FF"),
            buildingPrimary: Color(hex: "FFFFFF"),
            buildingSecondary: Color(hex: "EDE9FE"),
            roofPrimary: Color(hex: "A855F7"),
            roofSecondary: Color(hex: "7E22CE"),
            window: Color(hex: "EDE9FE"),
            treeLight: Color(hex: "6EE7B7"),
            treeDark: Color(hex: "059669"),
            ground: Color(hex: "EDE9FE"),
            road: Color(hex: "CBD5E1"),
            accent: Color(hex: "8B5CF6"),
            constructionAccent: Color(hex: "F97316")
        ),
        // 5: Golden Late Summer (Sun & Energy inspired — #FFC529 / #D97706)
        ArchiveCityPalette(
            cardBackground: Color(hex: "FEF9EC"),
            buildingPrimary: Color(hex: "FFFFFF"),
            buildingSecondary: Color(hex: "FEF3C7"),
            roofPrimary: Color(hex: "FFC529"),
            roofSecondary: Color(hex: "D97706"),
            window: Color(hex: "FEF9C3"),
            treeLight: Color(hex: "A3E635"),
            treeDark: Color(hex: "4D7C0F"),
            ground: Color(hex: "FEF9C3"),
            road: Color(hex: "E5E7EB"),
            accent: Color(hex: "D97706"),
            constructionAccent: Color(hex: "EA580C")
        )
    ]

    static func forDate(_ date: Date) -> ArchiveCityPalette {
        let cal = Calendar(identifier: .gregorian)
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        let idx = abs(year * 12 + month) % palettes.count
        return palettes[idx]
    }
}

// MARK: - Native SwiftUI City Artwork

private struct ArchiveCityArtwork: View {
    enum Mode {
        case completed(vibe: MonthlyRecap.VibeType, seed: Int)
        case construction(seed: Int)
    }

    let mode: Mode
    let palette: ArchiveCityPalette
    let isRTL: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            // Ground foundation layer
            ArchiveGroundPlane(palette: palette)
            
            // Skyline composition based on vibe or construction state
            HStack(alignment: .bottom, spacing: -2) {
                switch mode {
                case .completed(let vibe, let seed):
                    completedSkyline(vibe: vibe, seed: seed)
                case .construction(let seed):
                    constructionSkyline(seed: seed)
                }
            }
            .padding(.horizontal, 6)
            // Orient skyline composition to step down naturally toward card text
            .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .clipped()
    }

    @ViewBuilder
    private func completedSkyline(vibe: MonthlyRecap.VibeType, seed: Int) -> some View {
        let s = seed % 100
        switch vibe {
        case .quiet:
            // 2 modest buildings + 3 trees, serene and spacious
            ArchiveTree(palette: palette, height: 26)
            ArchivePitchedBuilding(palette: palette, width: 28, height: 42 + CGFloat(s % 8), roofH: 10)
            ArchiveTree(palette: palette, height: 32)
            ArchiveFlatBuilding(palette: palette, width: 34, height: 36 + CGFloat((s / 2) % 6))
            ArchiveTree(palette: palette, height: 24)
            Spacer(minLength: 0)

        case .growing:
            // 3 buildings + 2 trees, balanced small city
            ArchiveTree(palette: palette, height: 26)
            ArchiveSlantedBuilding(palette: palette, width: 26, height: 50 + CGFloat(s % 8))
            ArchiveFlatBuilding(palette: palette, width: 36, height: 68 + CGFloat((s / 2) % 8))
            ArchivePitchedBuilding(palette: palette, width: 30, height: 40 + CGFloat(s % 6), roofH: 11)
            ArchiveTree(palette: palette, height: 30)

        case .busy:
            // 4-5 buildings, layered energetic skyline
            ArchiveTree(palette: palette, height: 24)
            ArchivePitchedBuilding(palette: palette, width: 26, height: 46 + CGFloat(s % 8), roofH: 10)
            ArchiveFlatBuilding(palette: palette, width: 32, height: 72 + CGFloat((s / 2) % 8))
            ArchiveSlantedBuilding(palette: palette, width: 28, height: 58 + CGFloat(s % 6))
            ArchiveFlatBuilding(palette: palette, width: 30, height: 44 + CGFloat((s / 3) % 6))
            ArchiveTree(palette: palette, height: 28)

        case .recordMetropolis:
            // Landmark tower with supporting buildings
            ArchiveTree(palette: palette, height: 24)
            ArchivePitchedBuilding(palette: palette, width: 28, height: 46 + CGFloat(s % 6), roofH: 10)
            ArchiveLandmarkTower(palette: palette, height: 88 + CGFloat(s % 8))
            ArchiveFlatBuilding(palette: palette, width: 32, height: 62 + CGFloat((s / 2) % 8))
            ArchiveSlantedBuilding(palette: palette, width: 26, height: 42 + CGFloat(s % 6))
            ArchiveTree(palette: palette, height: 26)

        case .greenMonth:
            // 2 buildings with lush park foliage (4-5 trees)
            ArchiveTree(palette: palette, height: 24)
            ArchiveTree(palette: palette, height: 34)
            ArchivePitchedBuilding(palette: palette, width: 30, height: 44 + CGFloat(s % 8), roofH: 11)
            ArchiveTree(palette: palette, height: 30)
            ArchiveFlatBuilding(palette: palette, width: 32, height: 48 + CGFloat((s / 2) % 6))
            ArchiveTree(palette: palette, height: 28)
            ArchiveTree(palette: palette, height: 22)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func constructionSkyline(seed: Int) -> some View {
        let s = seed % 100
        // 1 finished small building + 1 exposed framework + 1 construction crane + trees
        ArchiveTree(palette: palette, height: 24)
        ArchivePitchedBuilding(palette: palette, width: 26, height: 42 + CGFloat(s % 6), roofH: 10)
        ArchiveConstructionFrame(palette: palette, width: 34, height: 54 + CGFloat(s % 8))
        ArchiveCrane(palette: palette, height: 66)
        ArchiveTree(palette: palette, height: 28)
        Spacer(minLength: 0)
    }
}

// MARK: - Architectural Shape Primitives

private struct ArchiveGroundPlane: View {
    let palette: ArchiveCityPalette

    var body: some View {
        VStack(spacing: 0) {
            // Road strip
            Rectangle()
                .fill(palette.road.opacity(0.85))
                .frame(height: 3)
            // Ground lawn base meeting the very bottom card edge
            Rectangle()
                .fill(palette.ground)
                .frame(height: 9)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ArchivePitchedBuilding: View {
    let palette: ArchiveCityPalette
    let width: CGFloat
    let height: CGFloat
    let roofH: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Gable roof with subtle 2-tone depth
            GeometryReader { geo in
                Path { p in
                    p.move(to: CGPoint(x: geo.size.width / 2, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    p.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(palette.roofPrimary)
                .overlay(
                    Path { p in
                        p.move(to: CGPoint(x: geo.size.width / 2, y: 0))
                        p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        p.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(palette.roofSecondary.opacity(0.35))
                )
            }
            .frame(width: width + 4, height: roofH)
            
            // Facade with side plane and windows
            ZStack(alignment: .trailing) {
                Rectangle()
                    .fill(palette.buildingPrimary)
                
                // Side shade column
                Rectangle()
                    .fill(palette.buildingSecondary)
                    .frame(width: width * 0.28)
                
                // Window grid
                VStack(spacing: 5) {
                    ForEach(0..<max(2, Int(height / 18)), id: \.self) { _ in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(palette.window)
                                .frame(width: 4, height: 6)
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(palette.window)
                                .frame(width: 4, height: 6)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: width, height: height)
        }
    }
}

private struct ArchiveFlatBuilding: View {
    let palette: ArchiveCityPalette
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Parapet bar
            RoundedRectangle(cornerRadius: 1)
                .fill(palette.roofPrimary)
                .frame(width: width + 2, height: 3.5)
            
            // Building facade
            ZStack(alignment: .trailing) {
                Rectangle()
                    .fill(palette.buildingPrimary)
                
                Rectangle()
                    .fill(palette.buildingSecondary)
                    .frame(width: width * 0.26)
                
                VStack(spacing: 5) {
                    ForEach(0..<max(2, Int(height / 16)), id: \.self) { _ in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(palette.window)
                                .frame(width: 4.5, height: 5.5)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(palette.window)
                                .frame(width: 4.5, height: 5.5)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: width, height: height)
        }
    }
}

private struct ArchiveSlantedBuilding: View {
    let palette: ArchiveCityPalette
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Angled roof wedge
            GeometryReader { geo in
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    p.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(palette.roofPrimary)
            }
            .frame(width: width, height: 8)
            
            ZStack(alignment: .trailing) {
                Rectangle()
                    .fill(palette.buildingPrimary)
                
                Rectangle()
                    .fill(palette.buildingSecondary)
                    .frame(width: width * 0.28)
                
                VStack(spacing: 6) {
                    ForEach(0..<max(2, Int(height / 17)), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(palette.window)
                            .frame(width: width * 0.44, height: 4.5)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: width, height: height)
        }
    }
}

private struct ArchiveLandmarkTower: View {
    let palette: ArchiveCityPalette
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Spire needle
            Rectangle()
                .fill(palette.accent)
                .frame(width: 2, height: 10)
            
            // Tower roof cap
            GeometryReader { geo in
                Path { p in
                    p.move(to: CGPoint(x: geo.size.width / 2, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    p.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(palette.roofPrimary)
            }
            .frame(width: 18, height: 9)
            
            // Stepped tower shaft
            ZStack(alignment: .trailing) {
                Rectangle()
                    .fill(palette.buildingPrimary)
                
                Rectangle()
                    .fill(palette.buildingSecondary)
                    .frame(width: 6)
                
                VStack(spacing: 6) {
                    ForEach(0..<max(3, Int(height / 15)), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(palette.window)
                            .frame(width: 3.5, height: 7)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 22, height: height)
        }
    }
}

private struct ArchiveConstructionFrame: View {
    let palette: ArchiveCityPalette
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            // Concrete base and columns
            HStack(spacing: 0) {
                Rectangle()
                    .fill(palette.buildingSecondary)
                    .frame(width: 3.5)
                Spacer()
                Rectangle()
                    .fill(palette.buildingSecondary)
                    .frame(width: 3.5)
            }
            .frame(width: width, height: height)
            
            // Horizontal floor girders
            VStack(spacing: height / 3 - 3) {
                // Top orange safety railing
                Rectangle()
                    .fill(palette.constructionAccent)
                    .frame(width: width + 2, height: 2.5)
                
                Rectangle()
                    .fill(palette.buildingSecondary)
                    .frame(width: width, height: 2.5)
                
                Rectangle()
                    .fill(palette.buildingSecondary)
                    .frame(width: width, height: 3)
            }
            .frame(width: width, height: height)
        }
    }
}

private struct ArchiveCrane: View {
    let palette: ArchiveCityPalette
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Vertical mast
            Rectangle()
                .fill(palette.constructionAccent)
                .frame(width: 3, height: height)
                .offset(x: -24)
            
            // Horizontal boom and counterweight
            VStack(alignment: .trailing, spacing: 0) {
                HStack(spacing: 0) {
                    // Counterweight rear block
                    Rectangle()
                        .fill(Color.deepNavy.opacity(0.75))
                        .frame(width: 8, height: 5)
                    
                    // Front extending jib
                    Rectangle()
                        .fill(palette.constructionAccent)
                        .frame(width: 32, height: 2.5)
                }
                
                // Hoist cable and hook
                HStack {
                    Spacer()
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.deepNavy.opacity(0.45))
                            .frame(width: 1, height: 18)
                        Rectangle()
                            .fill(palette.constructionAccent)
                            .frame(width: 4, height: 3)
                    }
                    .padding(.trailing, 6)
                }
            }
        }
        .frame(width: 42, height: height)
    }
}

private struct ArchiveTree: View {
    let palette: ArchiveCityPalette
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Canopy: 2-tone overlapping rounded crown
            ZStack {
                Circle()
                    .fill(palette.treeDark)
                    .frame(width: height * 0.72, height: height * 0.72)
                    .offset(x: 1, y: 1)
                Circle()
                    .fill(palette.treeLight)
                    .frame(width: height * 0.68, height: height * 0.68)
            }
            
            // Trunk
            Rectangle()
                .fill(Color(hex: "78716C"))
                .frame(width: 2.5, height: max(6, height * 0.28))
        }
    }
}
