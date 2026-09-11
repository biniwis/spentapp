import SwiftUI

/// Onboarding step definition used by the wizard and illustration.
public enum OnboardingStep: Int, CaseIterable {
    case concept = 1
    case mayor = 2
    case spendingTarget = 3
    case automation = 4
    case finalReveal = 5
}

/// A single art-directed vector city scene for SPENT onboarding.
///
/// Important implementation rule:
/// this is one 390×215 illustration with shared coordinates. SwiftUI controls
/// reveal/motion; the visual design itself lives in the Canvas paths below.
public struct OnboardingCityScene: View {
    let step: OnboardingStep
    let mayorName: String
    let targetAmountText: String
    let isRTL: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showTx1 = false
    @State private var showCommercial = false
    @State private var showTx2 = false
    @State private var showHero = false

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
            let widthScale = geo.size.width / VectorCityLayer.designWidth
            let compact = geo.size.height < 170
            let compactScale = geo.size.height / 150
            let sceneScale = compact ? min(widthScale, compactScale) : widthScale
            let renderedWidth = VectorCityLayer.designWidth * sceneScale
            let xOffset = (geo.size.width - renderedWidth) / 2
            let yOffset: CGFloat = compact ? -24 : 0

            ZStack(alignment: .topLeading) {
                artwork
                    .scaleEffect(x: isRTL ? -1 : 1, y: 1, anchor: .center)

                if step.rawValue >= OnboardingStep.mayor.rawValue {
                    mayorPlaque
                        .position(x: mirroredX(70), y: 157)
                }

                if step == .concept {
                    transactionLabels
                }
            }
            .frame(
                width: VectorCityLayer.designWidth,
                height: VectorCityLayer.designHeight,
                alignment: .topLeading
            )
            .scaleEffect(sceneScale, anchor: .topLeading)
            .offset(x: xOffset, y: yOffset)
        }
        .frame(height: height)
        .clipped()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onAppear {
            runConceptSequence()
        }
        .onChange(of: step) { _, newStep in
            if newStep == .concept {
                runConceptSequence()
            }
        }
    }

    private var artwork: some View {
        let concept = step == .concept
        let commercialVisible = !concept || showCommercial
        let heroVisible = !concept || showHero
        let parkVisible = step.rawValue >= OnboardingStep.spendingTarget.rawValue
        let secondaryVisible = step.rawValue >= OnboardingStep.automation.rawValue
        let finalVisible = step == .finalReveal
        let motion: Animation = reduceMotion
            ? .linear(duration: 0.01)
            : .spring(response: 0.36, dampingFraction: 0.88)

        return ZStack {
            VectorCityLayer(kind: .background)
            VectorCityLayer(kind: .plaza)

            VectorCityLayer(kind: .park)
                .opacity(parkVisible ? 1 : 0)
                .scaleEffect(
                    x: parkVisible ? 1 : 0.88,
                    y: parkVisible ? 1 : 0.92,
                    anchor: .bottomTrailing
                )

            VectorCityLayer(kind: .secondary)
                .opacity(secondaryVisible ? 1 : 0)
                .offset(y: secondaryVisible ? 0 : 16)

            VectorCityLayer(kind: .hero)
                .opacity(heroVisible ? 1 : 0)
                .scaleEffect(x: 1, y: heroVisible ? 1 : 0.02, anchor: .bottom)

            VectorCityLayer(kind: .annex)
                .opacity(finalVisible ? 1 : 0)
                .offset(y: finalVisible ? 0 : 14)

            VectorCityLayer(kind: .commercial)
                .opacity(commercialVisible ? 1 : 0)
                .scaleEffect(x: 1, y: commercialVisible ? 1 : 0.02, anchor: .bottom)

            VectorCityLayer(kind: .urbanTree)
                .opacity(heroVisible ? 1 : 0)
                .scaleEffect(heroVisible ? 1 : 0.1, anchor: .bottom)

            VectorCityLayer(kind: .parkTrees)
                .opacity(parkVisible ? 1 : 0)
                .scaleEffect(parkVisible ? 1 : 0.2, anchor: .bottom)

            VectorCityLayer(kind: .finalFoliage)
                .opacity(finalVisible ? 1 : 0)
                .scaleEffect(finalVisible ? 1 : 0.2, anchor: .bottom)
        }
        .frame(width: VectorCityLayer.designWidth, height: VectorCityLayer.designHeight)
        .animation(motion, value: commercialVisible)
        .animation(motion, value: heroVisible)
        .animation(motion, value: parkVisible)
        .animation(motion, value: secondaryVisible)
        .animation(motion, value: finalVisible)
    }

    private var mayorPlaque: some View {
        let cleanName = mayorName.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(spacing: 0.5) {
            Text(isRTL ? "ראש העיר" : "MAYOR")
                .font(.system(size: 6.7, weight: .semibold, design: .rounded))
                .foregroundColor(Color.textMuted)

            if !cleanName.isEmpty {
                Text(cleanName)
                    .font(.system(size: 8.8, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(width: 42, height: 22)
    }

    private var transactionLabels: some View {
        ZStack(alignment: .topLeading) {
            if showTx1 {
                transactionBadge(amount: "₪28", label: isRTL ? "קפה" : "Coffee")
                    .position(x: mirroredX(74), y: 102)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -6)))
            }

            if showTx2 {
                transactionBadge(amount: "₪86", label: isRTL ? "אוכל" : "Dining")
                    .position(x: mirroredX(178), y: 39)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -6)))
            }
        }
    }

    private func transactionBadge(amount: String, label: String) -> some View {
        Text("\(amount) · \(label)")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundColor(Color.deepNavy)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.borderSubtle, lineWidth: 0.8)
            )
    }

    private func mirroredX(_ x: CGFloat) -> CGFloat {
        isRTL ? VectorCityLayer.designWidth - x : x
    }

    private func runConceptSequence() {
        if reduceMotion {
            showTx1 = true
            showCommercial = true
            showTx2 = true
            showHero = true
            return
        }

        showTx1 = false
        showCommercial = false
        showTx2 = false
        showHero = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.18)) {
                showTx1 = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                showCommercial = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.easeOut(duration: 0.18)) {
                showTx2 = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.88) {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                showHero = true
            }
        }
    }
}

// MARK: - Single vector artwork system

private struct VectorCityLayer: View {
    enum Kind {
        case background
        case plaza
        case park
        case secondary
        case hero
        case commercial
        case annex
        case urbanTree
        case parkTrees
        case finalFoliage
    }

    static let designWidth: CGFloat = 390
    static let designHeight: CGFloat = 215

    let kind: Kind

    var body: some View {
        Canvas { context, size in
            context.scaleBy(
                x: size.width / Self.designWidth,
                y: size.height / Self.designHeight
            )

            switch kind {
            case .background: drawBackground(in: &context)
            case .plaza: drawPlaza(in: &context)
            case .park: drawPark(in: &context)
            case .secondary: drawSecondaryBuilding(in: &context)
            case .hero: drawHeroBuilding(in: &context)
            case .commercial: drawCommercialBuilding(in: &context)
            case .annex: drawAnnex(in: &context)
            case .urbanTree: drawUrbanTree(in: &context)
            case .parkTrees: drawParkTrees(in: &context)
            case .finalFoliage: drawFinalFoliage(in: &context)
            }
        }
    }

    private var blue: Color { .primaryBlue }
    private var green: Color { .spentGreen }
    private var orange: Color { .themeOrange }

    private var facade: Color {
        Color(red: 0.969, green: 0.980, blue: 0.995)
    }

    private var facadeSide: Color {
        Color(red: 0.885, green: 0.925, blue: 0.978)
    }

    private var warmFacade: Color {
        Color(red: 0.995, green: 0.968, blue: 0.920)
    }

    private var warmSide: Color {
        Color(red: 0.936, green: 0.875, blue: 0.775)
    }

    private var glass: Color {
        Color(red: 0.705, green: 0.855, blue: 0.972)
    }

    private var paleGlass: Color {
        Color(red: 0.817, green: 0.910, blue: 0.985)
    }

    private var stone: Color {
        Color(red: 0.955, green: 0.944, blue: 0.918)
    }

    private var parkGreen: Color {
        Color(red: 0.795, green: 0.945, blue: 0.842)
    }

    private var parkGreenBack: Color {
        Color(red: 0.681, green: 0.895, blue: 0.735)
    }

    private var deepGreen: Color {
        Color(red: 0.035, green: 0.470, blue: 0.345)
    }

    private var aquaGreen: Color {
        Color(red: 0.048, green: 0.620, blue: 0.500)
    }

    private var water: Color {
        Color(red: 0.635, green: 0.865, blue: 0.988)
    }

    private var trunk: Color {
        Color(red: 0.470, green: 0.315, blue: 0.210)
    }

    private func drawBackground(in context: inout GraphicsContext) {
        var left = Path()
        left.move(to: CGPoint(x: -20, y: 178))
        left.addLine(to: CGPoint(x: -20, y: 102))
        left.addLine(to: CGPoint(x: 18, y: 88))
        left.addLine(to: CGPoint(x: 48, y: 98))
        left.addLine(to: CGPoint(x: 48, y: 178))
        left.closeSubpath()
        context.fill(left, with: .color(Color(red: 0.930, green: 0.952, blue: 0.980)))

        var center = Path()
        center.move(to: CGPoint(x: 196, y: 178))
        center.addLine(to: CGPoint(x: 196, y: 58))
        center.addLine(to: CGPoint(x: 226, y: 48))
        center.addLine(to: CGPoint(x: 226, y: 70))
        center.addLine(to: CGPoint(x: 250, y: 63))
        center.addLine(to: CGPoint(x: 250, y: 178))
        center.closeSubpath()
        context.fill(center, with: .color(Color(red: 0.920, green: 0.945, blue: 0.982)))

        var right = Path()
        right.move(to: CGPoint(x: 315, y: 178))
        right.addLine(to: CGPoint(x: 315, y: 95))
        right.addLine(to: CGPoint(x: 345, y: 84))
        right.addLine(to: CGPoint(x: 345, y: 178))
        right.closeSubpath()
        context.fill(right, with: .color(Color(red: 0.952, green: 0.965, blue: 0.987)))
    }

    private func drawPlaza(in context: inout GraphicsContext) {
        var plaza = Path()
        plaza.move(to: CGPoint(x: -24, y: 174))
        plaza.addLine(to: CGPoint(x: 208, y: 174))
        plaza.addCurve(
            to: CGPoint(x: 245, y: 198),
            control1: CGPoint(x: 223, y: 176),
            control2: CGPoint(x: 239, y: 187)
        )
        plaza.addLine(to: CGPoint(x: 222, y: 220))
        plaza.addLine(to: CGPoint(x: -24, y: 220))
        plaza.closeSubpath()
        context.fill(plaza, with: .color(stone))

        var seam = Path()
        seam.move(to: CGPoint(x: -10, y: 190))
        seam.addCurve(
            to: CGPoint(x: 218, y: 190),
            control1: CGPoint(x: 64, y: 186),
            control2: CGPoint(x: 159, y: 187)
        )
        context.stroke(seam, with: .color(Color.white.opacity(0.62)), lineWidth: 1.2)
    }

    private func drawPark(in context: inout GraphicsContext) {
        var back = Path()
        back.move(to: CGPoint(x: 222, y: 163))
        back.addCurve(
            to: CGPoint(x: 300, y: 141),
            control1: CGPoint(x: 245, y: 146),
            control2: CGPoint(x: 270, y: 139)
        )
        back.addCurve(
            to: CGPoint(x: 420, y: 157),
            control1: CGPoint(x: 342, y: 140),
            control2: CGPoint(x: 382, y: 146)
        )
        back.addLine(to: CGPoint(x: 420, y: 183))
        back.addCurve(
            to: CGPoint(x: 217, y: 184),
            control1: CGPoint(x: 352, y: 167),
            control2: CGPoint(x: 278, y: 169)
        )
        back.closeSubpath()
        context.fill(back, with: .color(parkGreenBack))

        var land = Path()
        land.move(to: CGPoint(x: 206, y: 176))
        land.addCurve(
            to: CGPoint(x: 258, y: 154),
            control1: CGPoint(x: 220, y: 168),
            control2: CGPoint(x: 238, y: 158)
        )
        land.addCurve(
            to: CGPoint(x: 331, y: 155),
            control1: CGPoint(x: 281, y: 148),
            control2: CGPoint(x: 306, y: 149)
        )
        land.addCurve(
            to: CGPoint(x: 420, y: 170),
            control1: CGPoint(x: 360, y: 158),
            control2: CGPoint(x: 392, y: 160)
        )
        land.addLine(to: CGPoint(x: 420, y: 228))
        land.addLine(to: CGPoint(x: 190, y: 228))
        land.closeSubpath()
        context.fill(land, with: .color(parkGreen))

        var pond = Path()
        pond.move(to: CGPoint(x: 277, y: 184))
        pond.addCurve(
            to: CGPoint(x: 347, y: 176),
            control1: CGPoint(x: 294, y: 173),
            control2: CGPoint(x: 326, y: 171)
        )
        pond.addCurve(
            to: CGPoint(x: 371, y: 189),
            control1: CGPoint(x: 358, y: 178),
            control2: CGPoint(x: 367, y: 183)
        )
        pond.addCurve(
            to: CGPoint(x: 289, y: 205),
            control1: CGPoint(x: 349, y: 203),
            control2: CGPoint(x: 314, y: 207)
        )
        pond.addCurve(
            to: CGPoint(x: 277, y: 184),
            control1: CGPoint(x: 280, y: 201),
            control2: CGPoint(x: 272, y: 192)
        )
        pond.closeSubpath()
        context.fill(pond, with: .color(water))

        var reflection = Path()
        reflection.move(to: CGPoint(x: 311, y: 188))
        reflection.addCurve(
            to: CGPoint(x: 341, y: 187),
            control1: CGPoint(x: 322, y: 186),
            control2: CGPoint(x: 333, y: 186)
        )
        context.stroke(reflection, with: .color(Color.white.opacity(0.92)), lineWidth: 1.5)
    }

    private func drawHeroBuilding(in context: inout GraphicsContext) {
        var spine = Path()
        spine.move(to: CGPoint(x: 108, y: -24))
        spine.addLine(to: CGPoint(x: 141, y: -24))
        spine.addLine(to: CGPoint(x: 141, y: 181))
        spine.addLine(to: CGPoint(x: 108, y: 181))
        spine.closeSubpath()
        context.fill(spine, with: .color(blue))

        var spineSide = Path()
        spineSide.move(to: CGPoint(x: 141, y: -24))
        spineSide.addLine(to: CGPoint(x: 153, y: -14))
        spineSide.addLine(to: CGPoint(x: 153, y: 181))
        spineSide.addLine(to: CGPoint(x: 141, y: 181))
        spineSide.closeSubpath()
        context.fill(spineSide, with: .color(Color(red: 0.195, green: 0.390, blue: 0.900)))

        var body = Path()
        body.move(to: CGPoint(x: 153, y: 27))
        body.addLine(to: CGPoint(x: 205, y: 27))
        body.addLine(to: CGPoint(x: 205, y: 39))
        body.addLine(to: CGPoint(x: 223, y: 39))
        body.addLine(to: CGPoint(x: 223, y: 181))
        body.addLine(to: CGPoint(x: 153, y: 181))
        body.closeSubpath()
        context.fill(body, with: .color(facade))

        var side = Path()
        side.move(to: CGPoint(x: 223, y: 39))
        side.addLine(to: CGPoint(x: 236, y: 48))
        side.addLine(to: CGPoint(x: 236, y: 181))
        side.addLine(to: CGPoint(x: 223, y: 181))
        side.closeSubpath()
        context.fill(side, with: .color(facadeSide))

        drawWindowBand(in: &context, rect: CGRect(x: 166, y: 57, width: 42, height: 16))
        drawWindowBand(in: &context, rect: CGRect(x: 166, y: 95, width: 42, height: 16))
        drawWindowBand(in: &context, rect: CGRect(x: 166, y: 133, width: 42, height: 16))

        var reveal = Path()
        reveal.move(to: CGPoint(x: 159, y: 44))
        reveal.addLine(to: CGPoint(x: 159, y: 168))
        context.stroke(reveal, with: .color(Color(red: 0.835, green: 0.885, blue: 0.953)), lineWidth: 2)

        var roofPlanter = Path()
        roofPlanter.addRect(CGRect(x: 183, y: 21, width: 22, height: 6))
        context.fill(roofPlanter, with: .color(Color(red: 0.810, green: 0.765, blue: 0.650)))

        var roofGreen = Path()
        roofGreen.addEllipse(in: CGRect(x: 187, y: 14, width: 9, height: 9))
        roofGreen.addEllipse(in: CGRect(x: 194, y: 12, width: 10, height: 11))
        context.fill(roofGreen, with: .color(green))
    }

    private func drawWindowBand(in context: inout GraphicsContext, rect: CGRect) {
        var band = Path()
        band.addRect(rect)
        context.fill(band, with: .color(glass))

        var mullion = Path()
        mullion.move(to: CGPoint(x: rect.midX, y: rect.minY))
        mullion.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        context.stroke(mullion, with: .color(Color.white.opacity(0.82)), lineWidth: 1)
    }

    private func drawSecondaryBuilding(in context: inout GraphicsContext) {
        var body = Path()
        body.move(to: CGPoint(x: 219, y: 72))
        body.addLine(to: CGPoint(x: 265, y: 62))
        body.addLine(to: CGPoint(x: 265, y: 181))
        body.addLine(to: CGPoint(x: 219, y: 181))
        body.closeSubpath()
        context.fill(body, with: .color(Color(red: 0.944, green: 0.966, blue: 0.990)))

        var side = Path()
        side.move(to: CGPoint(x: 265, y: 62))
        side.addLine(to: CGPoint(x: 276, y: 69))
        side.addLine(to: CGPoint(x: 276, y: 181))
        side.addLine(to: CGPoint(x: 265, y: 181))
        side.closeSubpath()
        context.fill(side, with: .color(Color(red: 0.860, green: 0.915, blue: 0.965)))

        var greenLine = Path()
        greenLine.move(to: CGPoint(x: 221, y: 75))
        greenLine.addLine(to: CGPoint(x: 263, y: 66))
        context.stroke(greenLine, with: .color(green), lineWidth: 4)

        for y in [92.0, 121.0, 150.0] {
            var band = Path()
            band.addRect(CGRect(x: 228, y: y, width: 27, height: 12))
            context.fill(band, with: .color(paleGlass))
        }
    }

    private func drawCommercialBuilding(in context: inout GraphicsContext) {
        var body = Path()
        body.move(to: CGPoint(x: 14, y: 122))
        body.addLine(to: CGPoint(x: 115, y: 122))
        body.addLine(to: CGPoint(x: 115, y: 183))
        body.addLine(to: CGPoint(x: 14, y: 183))
        body.closeSubpath()
        context.fill(body, with: .color(warmFacade))

        var side = Path()
        side.move(to: CGPoint(x: 115, y: 122))
        side.addLine(to: CGPoint(x: 126, y: 129))
        side.addLine(to: CGPoint(x: 126, y: 183))
        side.addLine(to: CGPoint(x: 115, y: 183))
        side.closeSubpath()
        context.fill(side, with: .color(warmSide))

        var canopy = Path()
        canopy.move(to: CGPoint(x: 7, y: 116))
        canopy.addLine(to: CGPoint(x: 117, y: 116))
        canopy.addLine(to: CGPoint(x: 124, y: 121))
        canopy.addLine(to: CGPoint(x: 7, y: 121))
        canopy.closeSubpath()
        context.fill(canopy, with: .color(orange))

        var glazing = Path()
        glazing.addRect(CGRect(x: 26, y: 137, width: 29, height: 34))
        glazing.addRect(CGRect(x: 60, y: 137, width: 27, height: 34))
        context.fill(glazing, with: .color(Color(red: 0.940, green: 0.820, blue: 0.676)))

        var glassHighlight = Path()
        glassHighlight.move(to: CGPoint(x: 32, y: 143))
        glassHighlight.addLine(to: CGPoint(x: 49, y: 143))
        glassHighlight.move(to: CGPoint(x: 66, y: 143))
        glassHighlight.addLine(to: CGPoint(x: 81, y: 143))
        context.stroke(glassHighlight, with: .color(Color.white.opacity(0.74)), lineWidth: 1.2)

        var door = Path()
        door.addRect(CGRect(x: 95, y: 135, width: 12, height: 48))
        context.fill(door, with: .color(Color(red: 0.520, green: 0.260, blue: 0.125)))

        var plaque = Path()
        plaque.addRect(CGRect(x: 49, y: 145, width: 42, height: 24))
        context.fill(plaque, with: .color(Color.white.opacity(0.88)))
        context.stroke(plaque, with: .color(Color(red: 0.820, green: 0.825, blue: 0.835)), lineWidth: 0.7)
    }

    private func drawAnnex(in context: inout GraphicsContext) {
        var body = Path()
        body.move(to: CGPoint(x: -28, y: 137))
        body.addLine(to: CGPoint(x: 42, y: 137))
        body.addLine(to: CGPoint(x: 42, y: 184))
        body.addLine(to: CGPoint(x: -28, y: 184))
        body.closeSubpath()
        context.fill(body, with: .color(Color(red: 0.976, green: 0.956, blue: 0.918)))

        var terrace = Path()
        terrace.addRect(CGRect(x: -7, y: 132, width: 46, height: 5))
        context.fill(terrace, with: .color(Color(red: 0.645, green: 0.815, blue: 0.565)))

        var glazing = Path()
        glazing.addRect(CGRect(x: 9, y: 151, width: 19, height: 21))
        context.fill(glazing, with: .color(paleGlass))
    }

    private func drawUrbanTree(in context: inout GraphicsContext) {
        drawBroadTree(
            in: &context,
            x: 132,
            groundY: 174,
            scale: 0.88,
            canopyColor: green
        )
    }

    private func drawParkTrees(in context: inout GraphicsContext) {
        drawCypress(
            in: &context,
            x: 249,
            groundY: 174,
            scale: 0.92,
            canopyColor: deepGreen
        )

        drawBroadTree(
            in: &context,
            x: 305,
            groundY: 173,
            scale: 1.03,
            canopyColor: green
        )

        drawBroadTree(
            in: &context,
            x: 373,
            groundY: 171,
            scale: 1.12,
            canopyColor: aquaGreen
        )
    }

    private func drawFinalFoliage(in context: inout GraphicsContext) {
        drawShrub(in: &context, x: 218, groundY: 184, scale: 0.86)
    }

    private func drawBroadTree(
        in context: inout GraphicsContext,
        x: CGFloat,
        groundY: CGFloat,
        scale: CGFloat,
        canopyColor: Color
    ) {
        var trunkPath = Path()
        trunkPath.addRect(
            CGRect(
                x: x - 1.5 * scale,
                y: groundY - 14 * scale,
                width: 3 * scale,
                height: 14 * scale
            )
        )
        context.fill(trunkPath, with: .color(trunk))

        var canopy = Path()
        canopy.addEllipse(
            in: CGRect(
                x: x - 16 * scale,
                y: groundY - 38 * scale,
                width: 24 * scale,
                height: 24 * scale
            )
        )
        canopy.addEllipse(
            in: CGRect(
                x: x - 5 * scale,
                y: groundY - 42 * scale,
                width: 24 * scale,
                height: 27 * scale
            )
        )
        canopy.addEllipse(
            in: CGRect(
                x: x - 11 * scale,
                y: groundY - 31 * scale,
                width: 31 * scale,
                height: 20 * scale
            )
        )
        context.fill(canopy, with: .color(canopyColor))
    }

    private func drawCypress(
        in context: inout GraphicsContext,
        x: CGFloat,
        groundY: CGFloat,
        scale: CGFloat,
        canopyColor: Color
    ) {
        var trunkPath = Path()
        trunkPath.addRect(
            CGRect(
                x: x - 1.2 * scale,
                y: groundY - 12 * scale,
                width: 2.4 * scale,
                height: 12 * scale
            )
        )
        context.fill(trunkPath, with: .color(trunk))

        var canopy = Path()
        canopy.move(to: CGPoint(x: x, y: groundY - 52 * scale))
        canopy.addCurve(
            to: CGPoint(x: x + 8 * scale, y: groundY - 13 * scale),
            control1: CGPoint(x: x + 7 * scale, y: groundY - 44 * scale),
            control2: CGPoint(x: x + 9 * scale, y: groundY - 23 * scale)
        )
        canopy.addCurve(
            to: CGPoint(x: x - 8 * scale, y: groundY - 13 * scale),
            control1: CGPoint(x: x + 4 * scale, y: groundY - 7 * scale),
            control2: CGPoint(x: x - 4 * scale, y: groundY - 7 * scale)
        )
        canopy.addCurve(
            to: CGPoint(x: x, y: groundY - 52 * scale),
            control1: CGPoint(x: x - 9 * scale, y: groundY - 23 * scale),
            control2: CGPoint(x: x - 7 * scale, y: groundY - 44 * scale)
        )
        canopy.closeSubpath()
        context.fill(canopy, with: .color(canopyColor))
    }

    private func drawShrub(
        in context: inout GraphicsContext,
        x: CGFloat,
        groundY: CGFloat,
        scale: CGFloat
    ) {
        var shrub = Path()
        shrub.addEllipse(
            in: CGRect(
                x: x - 14 * scale,
                y: groundY - 11 * scale,
                width: 18 * scale,
                height: 13 * scale
            )
        )
        shrub.addEllipse(
            in: CGRect(
                x: x - 3 * scale,
                y: groundY - 14 * scale,
                width: 19 * scale,
                height: 16 * scale
            )
        )
        shrub.addEllipse(
            in: CGRect(
                x: x + 9 * scale,
                y: groundY - 10 * scale,
                width: 15 * scale,
                height: 12 * scale
            )
        )
        context.fill(shrub, with: .color(deepGreen))
    }
}
