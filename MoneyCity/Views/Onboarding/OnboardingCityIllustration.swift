import SwiftUI

/// Onboarding Step definition used across illustration and wizard
public enum OnboardingStep: Int, CaseIterable {
    case concept = 1
    case mayor = 2
    case spendingTarget = 3
    case automation = 4
    case finalReveal = 5
}

/// Continuous Miniature City Scene for SPENT Onboarding
///
/// Editorial, architectural illustration adhering to SPENT_DESIGN_CONSTITUTION.md:
/// - Sits DIRECTLY on canvas, zero enclosing frames or card borders.
/// - Layered composition with 3 depth levels (Background silhouettes, Main city architecture, Foreground nature/plaza).
/// - Clear hierarchy: substantial Mid-Rise hero building, warm lower commercial café, secondary vertical wing.
/// - Natural park & water integrated alongside urban plaza — zero road-through-water collisions.
/// - Partial street promenade that stops before nature rather than cutting across the screen.
/// - Authentic, understated civic signpost.
/// - Restrained SPENT palette: Sky Blue, SPENT Green, Carbon, warm sand/cream, coral/orange accents.
public struct OnboardingCityScene: View {
    let step: OnboardingStep
    let mayorName: String
    let targetAmountText: String
    let isRTL: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Step 1 staged reveals
    @State private var showTx1: Bool = false
    @State private var showBuilding1: Bool = false
    @State private var showTx2: Bool = false
    @State private var showBuilding2: Bool = false

    let height: CGFloat

    public init(
        step: OnboardingStep,
        mayorName: String,
        targetAmountText: String,
        isRTL: Bool = false,
        height: CGFloat = 215
    ) {
        self.step = step
        self.mayorName = mayorName
        self.targetAmountText = targetAmountText
        self.isRTL = isRTL
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let midX = width / 2
            let dir: CGFloat = isRTL ? -1.0 : 1.0

            ZStack {
                // 1. Warm base ground tone (soft foundation)
                groundFoundation(width: width)

                // 2. Background Layer: Large low-contrast architectural silhouettes (scale & depth)
                distantArchitecturalMasses(midX: midX, dir: dir)

                // 3. Middle Layer — Main City Architecture:
                // Building 3: Step 4+ Secondary Vertical Wing (normal architectural expansion)
                if step.rawValue >= OnboardingStep.automation.rawValue {
                    secondaryVerticalWing
                        .position(x: midX + dir * 42, y: 124)
                        .transition(reduceMotion ? .opacity : .offset(y: 18).combined(with: .opacity))
                }

                // Building 4: Step 5 Terrace Annex (completes rich urban skyline)
                if step.rawValue == OnboardingStep.finalReveal.rawValue {
                    terraceAnnexBuilding
                        .position(x: midX - dir * 108, y: 135)
                        .transition(reduceMotion ? .opacity : .offset(y: 16).combined(with: .opacity))
                }

                // Building 1: Main Mid-Rise Hero Building (tall, confident, approaches top edge)
                if showBuilding2 || step.rawValue > 1 {
                    mainMidriseHero
                        .position(x: midX - dir * 6, y: 108)
                        .transition(reduceMotion ? .opacity : .offset(y: 18).combined(with: .opacity))
                }

                // Building 2: Lower Commercial Building (Café / Bakery, warm cream & orange canopy)
                if showBuilding1 || step.rawValue > 1 {
                    commercialCafeBuilding
                        .position(x: midX - dir * 56, y: 140)
                        .transition(reduceMotion ? .opacity : .offset(y: 16).combined(with: .opacity))
                }

                // 4. Foreground Layer — Nature, Plaza & Water:
                // Partial Paved Promenade (under buildings, stops before park — NO collision!)
                partialPavedStreet(width: width, midX: midX, dir: dir)

                // Integrated Park & Water Landscape (Step 3+)
                if step.rawValue >= OnboardingStep.spendingTarget.rawValue {
                    integratedParkLandscape(midX: midX, dir: dir)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity))
                }

                // Urban Trees along plaza / street edge
                plazaTreesLayer(midX: midX, dir: dir)

                // 5. Authentic Civic Signpost (Step 2+)
                if step.rawValue >= OnboardingStep.mayor.rawValue {
                    civicSignpost
                        .position(x: midX - dir * 26, y: 156)
                        .transition(reduceMotion ? .opacity : .offset(y: 8).combined(with: .opacity))
                }

                // 6. Step 1 Animated transaction tags
                if step == .concept {
                    transactionTagsLayer(midX: midX, dir: dir)
                }
            }
        }
        .frame(height: height)
        .clipped()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onAppear {
            runStep1Sequence()
        }
        .onChange(of: step) { _, newStep in
            if newStep == .concept {
                runStep1Sequence()
            }
        }
    }

    // MARK: - 1. Soft Base Foundation
    private func groundFoundation(width: CGFloat) -> some View {
        Rectangle()
            .fill(Color(red: 247/255, green: 245/255, blue: 240/255).opacity(0.8))
            .frame(width: width + 60, height: 60)
            .position(x: width / 2, y: 185)
    }

    // MARK: - 2. Distant Architectural Masses (1-2 large subtle silhouettes, depth & scale)
    private func distantArchitecturalMasses(midX: CGFloat, dir: CGFloat) -> some View {
        ZStack {
            // Silhouette A: Tall, wide primary background mass approaching the upper edge
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: 232/255, green: 236/255, blue: 242/255))
                .frame(width: 74, height: 138)
                .position(x: midX + dir * 18, y: 98)

            // Silhouette B: Stepped secondary volume creating natural setback rhythm
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(red: 236/255, green: 240/255, blue: 245/255))
                .frame(width: 52, height: 96)
                .position(x: midX - dir * 42, y: 119)
        }
        .opacity(0.88)
    }

    // MARK: - 3. Building 1 — Main Mid-Rise Hero Building
    private var mainMidriseHero: some View {
        VStack(spacing: 0) {
            // Rooftop setback volume (approaches top edge)
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 241/255, green: 245/255, blue: 252/255))
                    .frame(width: 44, height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.primaryBlue.opacity(0.2), lineWidth: 1)
                    )
                Spacer(minLength: 0)
            }
            .frame(width: 66)

            // Primary architectural block
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color(red: 248/255, green: 250/255, blue: 254/255))
                    .frame(width: 66, height: 95)

                // Bold SPENT Primary Blue architectural cornice / band
                Rectangle()
                    .fill(Color.primaryBlue)
                    .frame(width: 66, height: 4.5)

                // Fenestration grid: 3 columns x 4 rows
                VStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { _ in
                        HStack(spacing: 7) {
                            windowPane
                            windowPane
                            windowPane
                        }
                    }
                }
                .offset(y: 14)
            }
        }
        .shadow(color: Color.black.opacity(0.045), radius: 4, y: 2)
    }

    private var windowPane: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color(red: 219/255, green: 234/255, blue: 254/255))
            .frame(width: 10, height: 10)
    }

    // MARK: - 4. Building 2 — Lower Commercial Building (Café / Retail)
    private var commercialCafeBuilding: some View {
        VStack(spacing: 0) {
            // Cantilevered flat canopy with warm orange/coral accent stripe
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.themeOrange)
                    .frame(width: 74, height: 4.5)
                Spacer(minLength: 0)
            }
            .frame(width: 76)

            // Facade body: warm cream / sand with expansive storefront glass
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 254/255, green: 246/255, blue: 236/255))
                    .frame(width: 72, height: 49)

                HStack(spacing: 5) {
                    // Large display window 1
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(red: 254/255, green: 228/255, blue: 198/255).opacity(0.85))
                        .frame(width: 20, height: 28)

                    // Large display window 2
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(red: 254/255, green: 228/255, blue: 198/255).opacity(0.85))
                        .frame(width: 20, height: 28)

                    // Warm timber entrance doorway
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(red: 154/255, green: 52/255, blue: 18/255))
                        .frame(width: 14, height: 34)
                }
                .padding(.horizontal, 5)
                .padding(.bottom, 3)
            }
        }
        .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1.5)
    }

    // MARK: - 5. Building 3 — Secondary Vertical Wing (Step 4+)
    private var secondaryVerticalWing: some View {
        VStack(spacing: 0) {
            // Calm SPENT Green top band
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.spentGreen)
                .frame(width: 46, height: 4)

            // Crisp architectural body
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 243/255, green: 247/255, blue: 251/255))
                    .frame(width: 46, height: 82)

                // Vertical architectural fenestration
                HStack(spacing: 6) {
                    VStack(spacing: 6) {
                        verticalWindowSlot
                        verticalWindowSlot
                        verticalWindowSlot
                    }
                    VStack(spacing: 6) {
                        verticalWindowSlot
                        verticalWindowSlot
                        verticalWindowSlot
                    }
                }
                .offset(y: 12)
            }
        }
        .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1.5)
    }

    private var verticalWindowSlot: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color(red: 204/255, green: 225/255, blue: 245/255))
            .frame(width: 9, height: 14)
    }

    // MARK: - 6. Building 4 — Terrace Annex (Step 5)
    private var terraceAnnexBuilding: some View {
        VStack(spacing: 0) {
            // Minimal wooden pergola / roofline
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { _ in
                    Rectangle()
                        .fill(Color(red: 180/255, green: 145/255, blue: 115/255))
                        .frame(width: 6, height: 3)
                }
            }
            .frame(width: 48, height: 4)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 250/255, green: 248/255, blue: 244/255))
                    .frame(width: 48, height: 58)

                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(red: 225/255, green: 236/255, blue: 248/255))
                        .frame(width: 14, height: 22)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(red: 225/255, green: 236/255, blue: 248/255))
                        .frame(width: 14, height: 22)
                }
                .padding(.bottom, 6)
            }
        }
        .shadow(color: Color.black.opacity(0.035), radius: 3, y: 1.5)
    }

    // MARK: - 7. Partial Paved Street / Promenade (Under buildings only — stops before nature!)
    private func partialPavedStreet(width: CGFloat, midX: CGFloat, dir: CGFloat) -> some View {
        let streetStartX: CGFloat = isRTL ? (width + 30) : -30
        let streetEndX: CGFloat = midX + dir * 20
        let streetWidth = abs(streetStartX - streetEndX)
        let streetCenterX = (streetStartX + streetEndX) / 2

        return ZStack(alignment: .top) {
            // Paved asphalt / promenade surface
            Rectangle()
                .fill(Color(red: 232/255, green: 235/255, blue: 240/255))
                .frame(width: streetWidth, height: 18)

            // Thin curb / sidewalk separator
            Rectangle()
                .fill(Color(red: 215/255, green: 219/255, blue: 226/255))
                .frame(width: streetWidth, height: 1.5)
        }
        .position(x: streetCenterX, y: 167)
    }

    // MARK: - 8. Integrated Park & Water (Step 3+ — wider organic shape, nestled pond, no road collision)
    private func integratedParkLandscape(midX: CGFloat, dir: CGFloat) -> some View {
        let parkCenterX = midX + dir * 105

        return ZStack {
            // Sweeping organic green lawn
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 220/255, green: 248/255, blue: 234/255))
                .frame(width: 155, height: 52)
                .position(x: parkCenterX, y: 172)

            // Miniature nestled lake / water shape
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 186/255, green: 230/255, blue: 253/255))
                .frame(width: 70, height: 22)
                .position(x: parkCenterX + dir * 12, y: 175)

            // Natural park trees nestled in the landscape
            stretchedCanopyTree(color: Color.spentGreen)
                .position(x: parkCenterX - dir * 42, y: 150)

            pencilCypressTree(color: Color(red: 4/255, green: 120/255, blue: 87/255))
                .position(x: parkCenterX + dir * 48, y: 154)

            overlappingCanopyTree(c1: Color.spentGreen, c2: Color(red: 16/255, green: 185/255, blue: 129/255))
                .position(x: parkCenterX + dir * 10, y: 144)
        }
    }

    // MARK: - 9. Urban Trees Layer (Along plaza & street edge)
    private func plazaTreesLayer(midX: CGFloat, dir: CGFloat) -> some View {
        ZStack {
            // Tree near commercial café edge
            stretchedCanopyTree(color: Color.spentGreen)
                .position(x: midX - dir * 98, y: 146)

            // Slender cypress between commercial café and mid-rise hero
            if showBuilding2 || step.rawValue > 1 {
                pencilCypressTree(color: Color(red: 5/255, green: 150/255, blue: 105/255))
                    .position(x: midX - dir * 28, y: 142)
            }
        }
    }

    // Tree Type 1: Stretched rounded canopy
    private func stretchedCanopyTree(color: Color) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(color)
                .frame(width: 18, height: 26)
            Rectangle()
                .fill(Color(red: 130/255, green: 100/255, blue: 80/255))
                .frame(width: 2.5, height: 6)
        }
    }

    // Tree Type 2: Overlapping canopy
    private func overlappingCanopyTree(c1: Color, c2: Color) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(c2).frame(width: 15, height: 15).offset(x: -3, y: 2)
                Circle().fill(c1).frame(width: 17, height: 17).offset(x: 2, y: -2)
            }
            Rectangle()
                .fill(Color(red: 130/255, green: 100/255, blue: 80/255))
                .frame(width: 2.5, height: 5)
        }
    }

    // Tree Type 3: Narrow architectural cypress
    private func pencilCypressTree(color: Color) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(color)
                .frame(width: 9, height: 28)
            Rectangle()
                .fill(Color(red: 130/255, green: 100/255, blue: 80/255))
                .frame(width: 2, height: 5)
        }
    }

    // MARK: - 10. Civic Signpost (Step 2+)
    private var civicSignpost: some View {
        let cleanName = mayorName.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(spacing: 0) {
            VStack(spacing: 1.5) {
                if cleanName.isEmpty {
                    Text(isRTL ? "ראש העיר" : "MAYOR")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                } else {
                    Text(isRTL ? "ראש העיר" : "MAYOR")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundColor(Color.textMuted)
                    Text(cleanName)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(Color(red: 254/255, green: 252/255, blue: 246/255))
            .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .stroke(Color(red: 217/255, green: 119/255, blue: 6/255).opacity(0.3), lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)

            Rectangle()
                .fill(Color(red: 140/255, green: 120/255, blue: 100/255))
                .frame(width: 2, height: 10)
        }
    }

    // MARK: - 11. Transaction Badges (Step 1)
    private func transactionTagsLayer(midX: CGFloat, dir: CGFloat) -> some View {
        ZStack {
            if showTx1 {
                subtleTransactionBadge(amount: "₪28", label: isRTL ? "קפה" : "Coffee")
                    .position(x: midX - dir * 56, y: showBuilding1 ? 100 : 70)
                    .opacity(showBuilding1 ? 0.95 : 1.0)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }

            if showTx2 {
                subtleTransactionBadge(amount: "₪86", label: isRTL ? "אוכל" : "Dining")
                    .position(x: midX - dir * 6, y: showBuilding2 ? 55 : 30)
                    .opacity(showBuilding2 ? 0.95 : 1.0)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func subtleTransactionBadge(amount: String, label: String) -> some View {
        Text("\(amount) · \(label)")
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .foregroundColor(Color.deepNavy)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.borderSubtle, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
    }

    // MARK: - Motion Sequences (High Damping)
    private func runStep1Sequence() {
        if reduceMotion {
            showTx1 = true
            showBuilding1 = true
            showTx2 = true
            showBuilding2 = true
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                showTx1 = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            Haptics.selection()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) {
                showBuilding1 = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                showTx2 = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.88) {
            Haptics.selection()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) {
                showBuilding2 = true
            }
        }
    }
}
