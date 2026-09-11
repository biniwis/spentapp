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
/// The whole illustration shares one 390×215 coordinate system.
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
            let compactScale = geo.size.height / 185
            let sceneScale = compact ? min(widthScale, compactScale) : widthScale
            let renderedWidth = VectorCityLayer.designWidth * sceneScale
            let xOffset = (geo.size.width - renderedWidth) / 2
            let yOffset: CGFloat = compact ? -20 : 0

            ZStack(alignment: .topLeading) {
                artwork

                if step.rawValue >= OnboardingStep.mayor.rawValue {
                    mayorPlaque
                        .position(x: 73, y: 138)
                        .scaleEffect(x: isRTL ? -1 : 1, y: 1)
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
            .scaleEffect(x: isRTL ? -1 : 1, y: 1, anchor: .center)
            .scaleEffect(sceneScale, anchor: .topLeading)
            .offset(x: xOffset, y: yOffset)
        }
        .frame(height: height)
        .clipped()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onAppear { runConceptSequence() }
        .onChange(of: step) { _, newStep in
            if newStep == .concept { runConceptSequence() }
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
                    x: parkVisible ? 1 : 0.9,
                    y: parkVisible ? 1 : 0.94,
                    anchor: .bottomTrailing
                )

            VectorCityLayer(kind: .secondary)
                .opacity(secondaryVisible ? 1 : 0)
                .offset(y: secondaryVisible ? 0 : 15)

            VectorCityLayer(kind: .hero)
                .opacity(heroVisible ? 1 : 0)
                .scaleEffect(x: 1, y: heroVisible ? 1 : 0.02, anchor: .bottom)

            VectorCityLayer(kind: .annex)
                .opacity(finalVisible ? 1 : 0)
                .offset(y: finalVisible ? 0 : 12)

            VectorCityLayer(kind: .commercial)
                .opacity(commercialVisible ? 1 : 0)
                .scaleEffect(x: 1, y: commercialVisible ? 1 : 0.02, anchor: .bottom)

            VectorCityLayer(kind: .parkTrees)
                .opacity(parkVisible ? 1 : 0)
                .scaleEffect(parkVisible ? 1 : 0.2, anchor: .bottom)
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

        return VStack(spacing: 0) {
            Text(isRTL ? "ראש העיר" : "MAYOR")
                .font(.system(size: 6.2, weight: .semibold, design: .rounded))
                .foregroundColor(Color.textMuted)

            if !cleanName.isEmpty {
                Text(cleanName)
                    .font(.system(size: 8.2, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(width: 42, height: 15)
    }

    private var transactionLabels: some View {
        ZStack(alignment: .topLeading) {
            if showTx1 {
                transactionBadge(amount: "₪28", label: isRTL ? "קפה" : "Coffee")
                    .position(x: 78, y: 104)
                    .scaleEffect(x: isRTL ? -1 : 1, y: 1)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -6)))
            }

            if showTx2 {
                transactionBadge(amount: "₪86", label: isRTL ? "אוכל" : "Dining")
                    .position(x: 184, y: 42)
                    .scaleEffect(x: isRTL ? -1 : 1, y: 1)
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
            withAnimation(.easeOut(duration: 0.18)) { showTx1 = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) { showCommercial = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.easeOut(duration: 0.18)) { showTx2 = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.88) {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) { showHero = true }
        }
    }
}

// MARK: - Shared vector artwork

private struct VectorCityLayer: View {
    enum Kind {
        case background
        case plaza
        case park
        case secondary
        case hero
        case commercial
        case annex
        case parkTrees
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
            case .parkTrees: drawParkTrees(in: &context)
            }
        }
    }

    private var blue: Color { .primaryBlue }
    private var green: Color { .spentGreen }
    private var orange: Color { .themeOrange }

    private var facade: Color { Color(red: 0.969, green: 0.980, blue: 0.995) }
    private var facadeSide: Color { Color(red: 0.885, green: 0.925, blue: 0.978) }
    private var warmFacade: Color { Color(red: 0.995, green: 0.968, blue: 0.920) }
    private var warmSide: Color { Color(red: 0.936, green: 0.875, blue: 0.775) }
    private var glass: Color { Color(red: 0.705, green: 0.855, blue: 0.972) }
    private var paleGlass: Color { Color(red: 0.817, green: 0.910, blue: 0.985) }
    private var stone: Color { Color(red: 0.955, green: 0.944, blue: 0.918) }
    private var parkGreen: Color { Color(red: 0.795, green: 0.945, blue: 0.842) }
    private var parkGreenBack: Color { Color(red: 0.681, green: 0.895, blue: 0.735) }
    private var deepGreen: Color { Color(red: 0.035, green: 0.470, blue: 0.345) }
    private var aquaGreen: Color { Color(red: 0.048, green: 0.620, blue: 0.500) }
    private var water: Color { Color(red: 0.635, green: 0.865, blue: 0.988) }
    private var trunk: Color { Color(red: 0.470, green: 0.315, blue: 0.210) }

    private func drawBackground(in context: inout GraphicsContext) {
        var edge = Path()
        edge.move(to: CGPoint(x: -18, y: 181))
        edge.addLine(to: CGPoint(x: -18, y: 120))
        edge.addLine(to: CGPoint(x: 20, y: 104))
        edge.addLine(to: CGPoint(x: 42, y: 112))
        edge.addLine(to: CGPoint(x: 42, y: 181))
        edge.closeSubpath()
        context.fill(edge, with: .color(Color(red: 0.955, green: 0.968, blue: 0.988)))

        var middle = Path()
        middle.move(to: CGPoint(x: 246, y: 181))
        middle.addLine(to: CGPoint(x: 246, y: 93))
        middle.addLine(to: CGPoint(x: 274, y: 83))
        middle.addLine(to: CGPoint(x: 274, y: 181))
        middle.closeSubpath()
        context.fill(middle, with: .color(Color(red: 0.932, green: 0.954, blue: 0.983)))

        var far = Path()
        far.move(to: CGPoint(x: 322, y: 181))
        far.addLine(to: CGPoint(x: 322, y: 112))
        far.addLine(to: CGPoint(x: 354, y: 100))
        far.addLine(to: CGPoint(x: 354, y: 181))
        far.closeSubpath()
        context.fill(far, with: .color(Color(red: 0.960, green: 0.970, blue: 0.990)))
    }

    private func drawPlaza(in context: inout GraphicsContext) {
        var plaza = Path()
        plaza.move(to: CGPoint(x: -24, y: 176))
        plaza.addLine(to: CGPoint(x: 251, y: 176))
        plaza.addCurve(
            to: CGPoint(x: 270, y: 195),
            control1: CGPoint(x: 259, y: 178),
            control2: CGPoint(x: 266, y: 186)
        )
        plaza.addCurve(
            to: CGPoint(x: 250, y: 218),
            control1: CGPoint(x: 270, y: 204),
            control2: CGPoint(x: 262, y: 212)
        )
        plaza.addLine(to: CGPoint(x: -24, y: 218))
        plaza.closeSubpath()
        context.fill(plaza, with: .color(stone))

        var seam = Path()
        seam.move(to: CGPoint(x: -8, y: 193))
        seam.addCurve(
            to: CGPoint(x: 244, y: 191),
            control1: CGPoint(x: 73, y: 188),
            control2: CGPoint(x: 178, y: 189)
        )
        context.stroke(seam, with: .color(Color.white.opacity(0.6)), lineWidth: 1)
    }

    private func drawPark(in context: inout GraphicsContext) {
        var rearHill = Path()
        rearHill.move(to: CGPoint(x: 250, y: 166))
        rearHill.addCurve(
            to: CGPoint(x: 319, y: 145),
            control1: CGPoint(x: 269, y: 151),
            control2: CGPoint(x: 294, y: 143)
        )
        rearHill.addCurve(
            to: CGPoint(x: 420, y: 160),
            control1: CGPoint(x: 352, y: 145),
            control2: CGPoint(x: 388, y: 150)
        )
        rearHill.addLine(to: CGPoint(x: 420, y: 184))
        rearHill.addCurve(
            to: CGPoint(x: 245, y: 184),
            control1: CGPoint(x: 360, y: 170),
            control2: CGPoint(x: 294, y: 171)
        )
        rearHill.closeSubpath()
        context.fill(rearHill, with: .color(parkGreenBack))

        var lawn = Path()
        lawn.move(to: CGPoint(x: 241, y: 178))
        lawn.addCurve(
            to: CGPoint(x: 283, y: 157),
            control1: CGPoint(x: 252, y: 169),
            control2: CGPoint(x: 266, y: 160)
        )
        lawn.addCurve(
            to: CGPoint(x: 342, y: 157),
            control1: CGPoint(x: 302, y: 151),
            control2: CGPoint(x: 323, y: 152)
        )
        lawn.addCurve(
            to: CGPoint(x: 420, y: 171),
            control1: CGPoint(x: 367, y: 159),
            control2: CGPoint(x: 394, y: 162)
        )
        lawn.addLine(to: CGPoint(x: 420, y: 222))
        lawn.addLine(to: CGPoint(x: 226, y: 222))
        lawn.addCurve(
            to: CGPoint(x: 241, y: 178),
            control1: CGPoint(x: 228, y: 205),
            control2: CGPoint(x: 232, y: 187)
        )
        lawn.closeSubpath()
        context.fill(lawn, with: .color(parkGreen))

        var pond = Path()
        pond.move(to: CGPoint(x: 290, y: 184))
        pond.addCurve(
            to: CGPoint(x: 349, y: 179),
            control1: CGPoint(x: 305, y: 177),
            control2: CGPoint(x: 332, y: 175)
        )
        pond.addCurve(
            to: CGPoint(x: 366, y: 190),
            control1: CGPoint(x: 357, y: 181),
            control2: CGPoint(x: 363, y: 185)
        )
        pond.addCurve(
            to: CGPoint(x: 298, y: 202),
            control1: CGPoint(x: 347, y: 201),
            control2: CGPoint(x: 319, y: 204)
        )
        pond.addCurve(
            to: CGPoint(x: 290, y: 184),
            control1: CGPoint(x: 292, y: 198),
            control2: CGPoint(x: 287, y: 190)
        )
        pond.closeSubpath()
        context.fill(pond, with: .color(water))

        var reflection = Path()
        reflection.move(to: CGPoint(x: 316, y: 188))
        reflection.addLine(to: CGPoint(x: 340, y: 187))
        context.stroke(reflection, with: .color(Color.white.opacity(0.9)), lineWidth: 1.4)
    }

    private func drawHeroBuilding(in context: inout GraphicsContext) {
        var body = Path()
        body.move(to: CGPoint(x: 145, y: 31))
        body.addLine(to: CGPoint(x: 207, y: 31))
        body.addLine(to: CGPoint(x: 207, y: 42))
        body.addLine(to: CGPoint(x: 225, y: 42))
        body.addLine(to: CGPoint(x: 225, y: 182))
        body.addLine(to: CGPoint(x: 145, y: 182))
        body.closeSubpath()
        context.fill(body, with: .color(facade))

        var side = Path()
        side.move(to: CGPoint(x: 225, y: 42))
        side.addLine(to: CGPoint(x: 236, y: 50))
        side.addLine(to: CGPoint(x: 236, y: 182))
        side.addLine(to: CGPoint(x: 225, y: 182))
        side.closeSubpath()
        context.fill(side, with: .color(facadeSide))

        var spine = Path()
        spine.move(to: CGPoint(x: 124, y: -18))
        spine.addLine(to: CGPoint(x: 148, y: -18))
        spine.addLine(to: CGPoint(x: 148, y: 182))
        spine.addLine(to: CGPoint(x: 124, y: 182))
        spine.closeSubpath()
        context.fill(spine, with: .color(blue))

        var spineSide = Path()
        spineSide.move(to: CGPoint(x: 148, y: -18))
        spineSide.addLine(to: CGPoint(x: 154, y: -12))
        spineSide.addLine(to: CGPoint(x: 154, y: 182))
        spineSide.addLine(to: CGPoint(x: 148, y: 182))
        spineSide.closeSubpath()
        context.fill(spineSide, with: .color(Color(red: 0.195, green: 0.390, blue: 0.900)))

        drawWindowBand(in: &context, rect: CGRect(x: 166, y: 60, width: 44, height: 15))
        drawWindowBand(in: &context, rect: CGRect(x: 166, y: 98, width: 44, height: 15))
        drawWindowBand(in: &context, rect: CGRect(x: 166, y: 136, width: 44, height: 15))

        var reveal = Path()
        reveal.move(to: CGPoint(x: 158, y: 47))
        reveal.addLine(to: CGPoint(x: 158, y: 169))
        context.stroke(reveal, with: .color(Color(red: 0.835, green: 0.885, blue: 0.953)), lineWidth: 1.7)
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
        body.move(to: CGPoint(x: 218, y: 78))
        body.addLine(to: CGPoint(x: 263, y: 68))
        body.addLine(to: CGPoint(x: 263, y: 182))
        body.addLine(to: CGPoint(x: 218, y: 182))
        body.closeSubpath()
        context.fill(body, with: .color(Color(red: 0.944, green: 0.966, blue: 0.990)))

        var side = Path()
        side.move(to: CGPoint(x: 263, y: 68))
        side.addLine(to: CGPoint(x: 273, y: 75))
        side.addLine(to: CGPoint(x: 273, y: 182))
        side.addLine(to: CGPoint(x: 263, y: 182))
        side.closeSubpath()
        context.fill(side, with: .color(Color(red: 0.860, green: 0.915, blue: 0.965)))

        var greenLine = Path()
        greenLine.move(to: CGPoint(x: 220, y: 81))
        greenLine.addLine(to: CGPoint(x: 261, y: 72))
        context.stroke(greenLine, with: .color(green), lineWidth: 3.5)

        for y in [101.0, 130.0, 159.0] {
            var band = Path()
            band.addRect(CGRect(x: 227, y: y, width: 25, height: 11))
            context.fill(band, with: .color(paleGlass))
        }
    }

    private func drawCommercialBuilding(in context: inout GraphicsContext) {
        var body = Path()
        body.move(to: CGPoint(x: 30, y: 125))
        body.addLine(to: CGPoint(x: 128, y: 125))
        body.addLine(to: CGPoint(x: 128, y: 184))
        body.addLine(to: CGPoint(x: 30, y: 184))
        body.closeSubpath()
        context.fill(body, with: .color(warmFacade))

        var side = Path()
        side.move(to: CGPoint(x: 128, y: 125))
        side.addLine(to: CGPoint(x: 136, y: 131))
        side.addLine(to: CGPoint(x: 136, y: 184))
        side.addLine(to: CGPoint(x: 128, y: 184))
        side.closeSubpath()
        context.fill(side, with: .color(warmSide))

        var canopy = Path()
        canopy.move(to: CGPoint(x: 24, y: 119))
        canopy.addLine(to: CGPoint(x: 129, y: 119))
        canopy.addLine(to: CGPoint(x: 135, y: 124))
        canopy.addLine(to: CGPoint(x: 24, y: 124))
        canopy.closeSubpath()
        context.fill(canopy, with: .color(orange))

        var plaque = Path()
        plaque.addRect(CGRect(x: 52, y: 129, width: 42, height: 18))
        context.fill(plaque, with: .color(Color.white.opacity(0.9)))
        context.stroke(plaque, with: .color(Color(red: 0.82, green: 0.83, blue: 0.85)), lineWidth: 0.7)

        var glazing = Path()
        glazing.addRect(CGRect(x: 39, y: 151, width: 27, height: 27))
        glazing.addRect(CGRect(x: 70, y: 151, width: 27, height: 27))
        context.fill(glazing, with: .color(Color(red: 0.94, green: 0.82, blue: 0.68)))

        var highlight = Path()
        highlight.move(to: CGPoint(x: 44, y: 156))
        highlight.addLine(to: CGPoint(x: 60, y: 156))
        highlight.move(to: CGPoint(x: 75, y: 156))
        highlight.addLine(to: CGPoint(x: 91, y: 156))
        context.stroke(highlight, with: .color(Color.white.opacity(0.72)), lineWidth: 1)

        var door = Path()
        door.addRect(CGRect(x: 106, y: 143, width: 12, height: 41))
        context.fill(door, with: .color(Color(red: 0.52, green: 0.26, blue: 0.125)))
    }

    private func drawAnnex(in context: inout GraphicsContext) {
        var body = Path()
        body.move(to: CGPoint(x: -20, y: 146))
        body.addLine(to: CGPoint(x: 27, y: 146))
        body.addLine(to: CGPoint(x: 27, y: 184))
        body.addLine(to: CGPoint(x: -20, y: 184))
        body.closeSubpath()
        context.fill(body, with: .color(Color(red: 0.978, green: 0.958, blue: 0.922)))

        var terrace = Path()
        terrace.addRect(CGRect(x: -3, y: 141, width: 28, height: 5))
        context.fill(terrace, with: .color(Color(red: 0.645, green: 0.815, blue: 0.565)))
    }

    private func drawParkTrees(in context: inout GraphicsContext) {
        drawCypress(in: &context, x: 258, groundY: 176, scale: 0.86, canopyColor: deepGreen)
        drawBroadTree(in: &context, x: 318, groundY: 174, scale: 0.98, canopyColor: green)
        drawBroadTree(in: &context, x: 379, groundY: 172, scale: 1.08, canopyColor: aquaGreen)
    }

    private func drawBroadTree(
        in context: inout GraphicsContext,
        x: CGFloat,
        groundY: CGFloat,
        scale: CGFloat,
        canopyColor: Color
    ) {
        var trunkPath = Path()
        trunkPath.addRect(CGRect(x: x - 1.4 * scale, y: groundY - 13 * scale, width: 2.8 * scale, height: 13 * scale))
        context.fill(trunkPath, with: .color(trunk))

        var canopy = Path()
        canopy.addEllipse(in: CGRect(x: x - 15 * scale, y: groundY - 37 * scale, width: 22 * scale, height: 22 * scale))
        canopy.addEllipse(in: CGRect(x: x - 5 * scale, y: groundY - 41 * scale, width: 23 * scale, height: 25 * scale))
        canopy.addEllipse(in: CGRect(x: x - 10 * scale, y: groundY - 30 * scale, width: 29 * scale, height: 19 * scale))
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
        trunkPath.addRect(CGRect(x: x - 1.1 * scale, y: groundY - 11 * scale, width: 2.2 * scale, height: 11 * scale))
        context.fill(trunkPath, with: .color(trunk))

        var canopy = Path()
        canopy.move(to: CGPoint(x: x, y: groundY - 48 * scale))
        canopy.addCurve(
            to: CGPoint(x: x + 7 * scale, y: groundY - 12 * scale),
            control1: CGPoint(x: x + 6 * scale, y: groundY - 42 * scale),
            control2: CGPoint(x: x + 8 * scale, y: groundY - 22 * scale)
        )
        canopy.addCurve(
            to: CGPoint(x: x - 7 * scale, y: groundY - 12 * scale),
            control1: CGPoint(x: x + 4 * scale, y: groundY - 7 * scale),
            control2: CGPoint(x: x - 4 * scale, y: groundY - 7 * scale)
        )
        canopy.addCurve(
            to: CGPoint(x: x, y: groundY - 48 * scale),
            control1: CGPoint(x: x - 8 * scale, y: groundY - 22 * scale),
            control2: CGPoint(x: x - 6 * scale, y: groundY - 42 * scale)
        )
        canopy.closeSubpath()
        context.fill(canopy, with: .color(canopyColor))
    }
}
