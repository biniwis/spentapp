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
/// Editorial, architectural 2D/2.5D illustration adhering to SPENT_DESIGN_CONSTITUTION.md:
/// - Sits DIRECTLY on canvas, zero enclosing frames or card borders.
/// - Architectural building language: flat canopies, stepped mid-rises, asymmetric pavilions.
/// - Diverse landscaped tree forms (stretched ovals, overlapping circles, pencil cypresses).
/// - Subtly toned, narrower roadway that bleeds off-screen without dominating.
/// - Authentic civic signpost integrated into the urban ground.
/// - Restrained, confident SPENT palette: Sky Blue, SPENT Green, Carbon, warm sand/cream, coral/orange accents.
/// - High damping, mature motion settling. Full Reduce Motion support.
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

    // Step 5 car animation
    @State private var carDriveOffset: CGFloat = -180

    let height: CGFloat

    public init(
        step: OnboardingStep,
        mayorName: String,
        targetAmountText: String,
        isRTL: Bool = false,
        height: CGFloat = 180
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

            ZStack {
                // 1. Warm ground plane tint (edge-to-edge)
                groundPlane(width: width)

                // 2. Distant architectural silhouette skyline (depth & scale contrast)
                distantSkyline(midX: midX)

                // 3. Step 5 Landmark Spire (architectural highlight rising in background)
                if step.rawValue == OnboardingStep.finalReveal.rawValue {
                    landmarkSpire
                        .position(x: midX + (isRTL ? -112 : 112), y: 68)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }

                // 4. Step 3+ Landscaped Park & Pond (organic lawn, pond, architectural tree clusters)
                if step.rawValue >= OnboardingStep.spendingTarget.rawValue {
                    parkLandscapingArea
                        .position(x: midX + (isRTL ? -68 : 68), y: 136)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
                }

                // 5. Buildings:
                // Building A: Retail / Café (horizontal pavilion, flat cantilever canopy, storefront glass)
                if showBuilding1 || step.rawValue > 1 {
                    cafeRetailPavilion
                        .position(x: midX + (isRTL ? 72 : -72), y: 98)
                        .transition(reduceMotion ? .opacity : .offset(y: 16).combined(with: .opacity))
                }

                // Building B: Mid-rise Commercial (stepped masses, azure accent, rhythmic fenestration)
                if showBuilding2 || step.rawValue > 1 {
                    midriseBuilding
                        .position(x: midX + (isRTL ? 12 : -12), y: 84)
                        .transition(reduceMotion ? .opacity : .offset(y: 16).combined(with: .opacity))
                }

                // Building D: Automation Pavilion (Step 4+ angled modernist geometry, green roof)
                if step.rawValue >= OnboardingStep.automation.rawValue {
                    automationPavilion
                        .position(x: midX + (isRTL ? -52 : 52), y: 94)
                        .transition(reduceMotion ? .opacity : .offset(y: 16).combined(with: .opacity))
                }

                // 6. Street trees with distinct silhouettes
                streetTreesLayer(midX: midX)

                // 7. Subtle Narrower Roadway (edge-to-edge bleed, softer tone)
                roadway(width: width, midX: midX)

                // 8. Step 2+ Civic Signpost (authentic urban signage, no floating pill)
                if step.rawValue >= OnboardingStep.mayor.rawValue {
                    civicSignpost
                        .position(x: midX + (isRTL ? -84 : 84), y: 48)
                        .transition(reduceMotion ? .opacity : .offset(y: 8).combined(with: .opacity))
                }

                // 9. Step 1 Animated transaction tags (subtle tags, mature typography)
                if step == .concept {
                    transactionTagsLayer(midX: midX)
                }

                // 10. Step 5 Small city vehicle
                if step == .finalReveal {
                    smallCityVehicle
                        .position(x: midX + carDriveOffset, y: 126)
                }
            }
        }
        .frame(height: height)
        .clipped()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onAppear {
            runStep1Sequence()
            runStep5Car()
        }
        .onChange(of: step) { _, newStep in
            if newStep == .concept {
                runStep1Sequence()
            }
            if newStep == .finalReveal {
                runStep5Car()
            }
        }
    }

    // MARK: - 1. Ground Plane
    private func groundPlane(width: CGFloat) -> some View {
        Rectangle()
            .fill(Color(red: 243/255, green: 241/255, blue: 236/255).opacity(0.65))
            .frame(width: width + 60, height: 68)
            .position(x: width / 2, y: 146)
    }

    // MARK: - 2. Distant Skyline (Depth & Layering)
    private func distantSkyline(midX: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 16) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 228/255, green: 232/255, blue: 238/255))
                .frame(width: 34, height: 50)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 232/255, green: 236/255, blue: 242/255))
                .frame(width: 26, height: 68)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 226/255, green: 230/255, blue: 236/255))
                .frame(width: 38, height: 44)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 230/255, green: 234/255, blue: 240/255))
                .frame(width: 30, height: 58)
        }
        .position(x: midX, y: 90)
        .opacity(0.8)
    }

    // MARK: - 3. Roadway (Narrower, Softer)
    private func roadway(width: CGFloat, midX: CGFloat) -> some View {
        ZStack {
            // Soft roadway asphalt
            Rectangle()
                .fill(Color(red: 224/255, green: 227/255, blue: 232/255))
                .frame(width: width + 60, height: 20)
                .position(x: midX, y: 126)

            // Minimal center dash
            Path { path in
                path.move(to: CGPoint(x: -20, y: 126))
                path.addLine(to: CGPoint(x: width + 20, y: 126))
            }
            .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, dash: [6, 8]))

            // Crosswalk zebra marking
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 2, height: 14)
                }
            }
            .position(x: midX + (isRTL ? 44 : -44), y: 126)
        }
    }

    // MARK: - 4. Building A — Café / Retail Pavilion
    private var cafeRetailPavilion: some View {
        VStack(spacing: 0) {
            // Flat cantilever canopy with thin warm orange accent
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.themeOrange)
                    .frame(width: 58, height: 4)
                Spacer(minLength: 0)
            }
            .frame(width: 60)

            // Facade body (sand/cream tone with large storefront glass)
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 254/255, green: 243/255, blue: 232/255))
                    .frame(width: 54, height: 32)

                HStack(spacing: 4) {
                    // Glass storefront display pane 1
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(red: 254/255, green: 215/255, blue: 170/255).opacity(0.8))
                        .frame(width: 14, height: 18)

                    // Glass storefront display pane 2
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(red: 254/255, green: 215/255, blue: 170/255).opacity(0.8))
                        .frame(width: 14, height: 18)

                    // Entry opening
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(red: 154/255, green: 52/255, blue: 18/255))
                        .frame(width: 10, height: 22)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }
        }
        .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1.5)
    }

    // MARK: - 5. Building B — Mid-Rise Commercial
    private var midriseBuilding: some View {
        VStack(spacing: 0) {
            // Offset upper penthouse floor
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 239/255, green: 246/255, blue: 255/255))
                    .frame(width: 36, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.primaryBlue.opacity(0.15), lineWidth: 1)
                    )
                Spacer(minLength: 0)
            }
            .frame(width: 48)

            // Primary facade block
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 245/255, green: 248/255, blue: 254/255))
                    .frame(width: 48, height: 44)

                // Architectural Sky Blue accent lintel
                Rectangle()
                    .fill(Color(red: 37/255, green: 99/255, blue: 235/255))
                    .frame(width: 48, height: 3.5)

                // Fenestration array
                VStack(spacing: 4) {
                    HStack(spacing: 5) {
                        windowSquare
                        windowSquare
                        windowSquare
                    }
                    HStack(spacing: 5) {
                        windowSquare
                        windowSquare
                        windowSquare
                    }
                }
                .offset(y: 10)
            }
        }
        .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1.5)
    }

    private var windowSquare: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color(red: 191/255, green: 219/255, blue: 254/255))
            .frame(width: 7, height: 7)
    }

    // MARK: - 6. Building D — Automation Pavilion
    private var automationPavilion: some View {
        VStack(spacing: 0) {
            // Modern angled roofline
            HStack(spacing: 0) {
                Spacer()
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.spentGreen)
                    .frame(width: 42, height: 4)
            }
            .frame(width: 46)

            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 240/255, green: 253/255, blue: 244/255))
                    .frame(width: 44, height: 38)

                // Vertical architectural louvers
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(red: 187/255, green: 247/255, blue: 208/255))
                        .frame(width: 5, height: 24)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(red: 187/255, green: 247/255, blue: 208/255))
                        .frame(width: 5, height: 24)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(red: 187/255, green: 247/255, blue: 208/255))
                        .frame(width: 5, height: 24)
                }

                // Minimal lightning badge
                Circle()
                    .fill(Color.white)
                    .frame(width: 13, height: 13)
                    .shadow(color: Color.black.opacity(0.06), radius: 2, y: 1)
                    .overlay(
                        MoneyIcon(.lightning, size: 8, color: Color.spentGreen)
                    )
                    .offset(y: 10)
            }
        }
        .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1.5)
    }

    // MARK: - 7. Building C — Landmark Spire (Step 5)
    private var landmarkSpire: some View {
        VStack(spacing: 0) {
            // Architectural needle
            Rectangle()
                .fill(Color.deepNavy)
                .frame(width: 1.5, height: 16)

            // Stepped purple crown
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(red: 147/255, green: 51/255, blue: 234/255))
                .frame(width: 22, height: 8)

            // Tower stem
            Rectangle()
                .fill(Color(red: 245/255, green: 243/255, blue: 252/255))
                .frame(width: 18, height: 56)
                .overlay(
                    VStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { _ in
                            Rectangle()
                                .fill(Color(red: 221/255, green: 204/255, blue: 253/255))
                                .frame(width: 8, height: 2.5)
                        }
                    }
                )
        }
        .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1.5)
    }

    // MARK: - 8. Landscaped Park & Pond (Step 3+)
    private var parkLandscapingArea: some View {
        ZStack {
            // Organic curved lawn
            Ellipse()
                .fill(Color(red: 209/255, green: 250/255, blue: 229/255))
                .frame(width: 92, height: 42)

            // Miniature lake
            Ellipse()
                .fill(Color(red: 186/255, green: 230/255, blue: 253/255))
                .frame(width: 38, height: 16)
                .offset(x: 6, y: 1)

            // Diverse tree types
            stretchedCanopyTree(color: Color.spentGreen)
                .offset(x: -24, y: -6)
            overlappingCanopyTree(c1: Color(red: 16/255, green: 185/255, blue: 129/255), c2: Color(red: 5/255, green: 150/255, blue: 105/255))
                .offset(x: 26, y: -2)
            pencilCypressTree(color: Color(red: 4/255, green: 120/255, blue: 87/255))
                .offset(x: -6, y: 8)
        }
    }

    // MARK: - 9. Street Trees Layer (Diverse Architectural Silhouettes)
    private func streetTreesLayer(midX: CGFloat) -> some View {
        ZStack {
            // Type 1: Stretched rounded canopy near café
            stretchedCanopyTree(color: Color.spentGreen)
                .position(x: midX + (isRTL ? 116 : -116), y: 106)

            // Type 3: Pencil cypress near mid-rise
            if showBuilding2 || step.rawValue > 1 {
                pencilCypressTree(color: Color(red: 5/255, green: 150/255, blue: 105/255))
                    .position(x: midX + (isRTL ? -22 : 22), y: 102)
            }

            // Type 2: Overlapping canopy tree along avenue (Step 4+)
            if step.rawValue >= OnboardingStep.automation.rawValue {
                overlappingCanopyTree(c1: Color.spentGreen, c2: Color(red: 16/255, green: 185/255, blue: 129/255))
                    .position(x: midX + (isRTL ? 34 : -34), y: 112)
            }
        }
    }

    // Tree Type 1: Vertically stretched rounded canopy
    private func stretchedCanopyTree(color: Color) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(color)
                .frame(width: 16, height: 24)
            Rectangle()
                .fill(Color(red: 120/255, green: 90/255, blue: 70/255))
                .frame(width: 2.5, height: 6)
        }
    }

    // Tree Type 2: Two overlapping organic circles
    private func overlappingCanopyTree(c1: Color, c2: Color) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(c2).frame(width: 14, height: 14).offset(x: -3, y: 2)
                Circle().fill(c1).frame(width: 16, height: 16).offset(x: 2, y: -2)
            }
            Rectangle()
                .fill(Color(red: 120/255, green: 90/255, blue: 70/255))
                .frame(width: 2.5, height: 5)
        }
    }

    // Tree Type 3: Small narrow cypress-like form
    private func pencilCypressTree(color: Color) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(color)
                .frame(width: 8, height: 26)
            Rectangle()
                .fill(Color(red: 120/255, green: 90/255, blue: 70/255))
                .frame(width: 2, height: 4)
        }
    }

    // MARK: - 10. Civic Signpost (Step 2+)
    private var civicSignpost: some View {
        let cleanName = mayorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = cleanName.isEmpty ? (isRTL ? "ראש העיר" : "Mayor") : cleanName

        return VStack(spacing: 0) {
            // Elegant civic board
            VStack(spacing: 1) {
                Text(isRTL ? "ראש העיר" : "MAYOR")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                Text(displayName)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(Color(red: 254/255, green: 252/255, blue: 246/255))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color(red: 217/255, green: 119/255, blue: 6/255).opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)

            // Post planting sign firmly into the ground
            Rectangle()
                .fill(Color(red: 140/255, green: 120/255, blue: 100/255))
                .frame(width: 2, height: 12)
        }
    }

    // MARK: - 11. Transaction Tags (Step 1)
    private func transactionTagsLayer(midX: CGFloat) -> some View {
        ZStack {
            if showTx1 {
                subtleTransactionBadge(amount: "₪28", label: isRTL ? "קפה" : "Coffee")
                    .position(x: midX + (isRTL ? 72 : -72), y: showBuilding1 ? 54 : 34)
                    .opacity(showBuilding1 ? 0.95 : 1.0)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }

            if showTx2 {
                subtleTransactionBadge(amount: "₪86", label: isRTL ? "אוכל" : "Dining")
                    .position(x: midX + (isRTL ? 12 : -12), y: showBuilding2 ? 44 : 24)
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

    // MARK: - 12. Small City Vehicle (Step 5)
    private var smallCityVehicle: some View {
        HStack(spacing: 0) {
            ZStack {
                // Window canopy
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 12, height: 5)
                    .offset(y: -2.5)

                // Compact chassis
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(red: 239/255, green: 68/255, blue: 68/255))
                    .frame(width: 18, height: 6)

                // Wheels
                HStack(spacing: 8) {
                    Circle().fill(Color.deepNavy).frame(width: 3, height: 3)
                    Circle().fill(Color.deepNavy).frame(width: 3, height: 3)
                }
                .offset(y: 3)
            }
        }
    }

    // MARK: - Motion Sequences (High Damping, Polished)
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

    private func runStep5Car() {
        if reduceMotion {
            carDriveOffset = isRTL ? -15 : 15
            return
        }

        carDriveOffset = isRTL ? 160 : -160
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: false)) {
            carDriveOffset = isRTL ? -160 : 160
        }
    }
}
