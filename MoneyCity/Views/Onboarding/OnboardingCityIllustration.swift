import SwiftUI

public enum OnboardingStep: Int, CaseIterable {
    case concept = 1
    case mayor = 2
    case spendingTarget = 3
    case automation = 4
    case finalReveal = 5

    var posterBackground: Color {
        switch self {
        case .concept: return .warmCream
        case .mayor: return .neonLime
        case .spendingTarget: return .babyBlue
        case .automation: return .white
        case .finalReveal: return .violetBlue
        }
    }
}

/// Five compositions sharing a small architectural drawing kit, not one cropped city.
public struct OnboardingCityScene: View {
    let step: OnboardingStep
    let mayorName: String
    let targetAmountText: String
    let isRTL: Bool
    let height: CGFloat
    let animateEntrance: Bool

    private var presentsImmediately: Bool { reduceMotion || !animateEntrance }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    public init(step: OnboardingStep, mayorName: String, targetAmountText: String,
                isRTL: Bool = false, height: CGFloat = 300, animateEntrance: Bool = true) {
        self.step = step
        self.mayorName = mayorName
        self.targetAmountText = targetAmountText
        self.isRTL = isRTL
        self.height = height
        self.animateEntrance = animateEntrance
    }

    public var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 380, geometry.size.height / 300)
            ZStack(alignment: .topLeading) {
                ForEach(0..<3) { layer in
                    CityPosterDrawing(step: step, layer: layer)
                        .opacity(presentsImmediately || phase > layer ? 1 : 0)
                        .offset(y: presentsImmediately || phase > layer ? 0 : 14)
                }
                lettering
                    .opacity(presentsImmediately || phase == 3 ? 1 : 0)
            }
            .frame(width: 380, height: 300)
            .scaleEffect(x: isRTL ? -1 : 1, y: 1)
            .scaleEffect(scale, anchor: .topLeading)
            .offset(x: (geometry.size.width - 380 * scale) / 2,
                    y: (geometry.size.height - 300 * scale) / 2)
        }
        .frame(height: height)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .task(id: "\(step.rawValue)-\(presentsImmediately)") {
            // Structured cancellation prevents a departed scene's sequence from firing later.
            var transaction = SwiftUI.Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { phase = presentsImmediately ? 3 : 0 }
            guard !presentsImmediately else { return }
            for nextPhase in 1...3 {
                do { try await Task.sleep(for: .milliseconds(nextPhase == 1 ? 80 : 190)) }
                catch { return }
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.32)) { phase = nextPhase }
            }
        }
    }

    private var name: String {
        let value = mayorName.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? (isRTL ? "העיר שלך" : "YOUR CITY") : value
    }

    @ViewBuilder private var lettering: some View {
        switch step {
        case .concept:
            posterLabel("SPENT", size: 14, width: 104)
                .position(x: 250, y: 160)
        case .mayor:
            VStack(spacing: 5) {
                Text(isRTL ? "ברוכים הבאים לעיר של" : "WELCOME TO THE CITY OF")
                    .font(.system(size: 9, weight: .semibold))
                Text(name)
                    .font(.system(size: 29, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
            }
            .foregroundStyle(Color.jetBlack)
            .frame(width: 224, height: 76)
            .scaleEffect(x: isRTL ? -1 : 1, y: 1)
            .position(x: 188, y: 83)
        case .spendingTarget:
            VStack(spacing: 4) {
                Text(isRTL ? "המסגרת של החודש" : "THIS MONTH’S TARGET")
                    .font(.system(size: 9, weight: .semibold))
                Text(targetAmountText.isEmpty ? "—" : targetAmountText)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .foregroundStyle(Color.jetBlack)
            .frame(width: 162, height: 59)
            .scaleEffect(x: isRTL ? -1 : 1, y: 1)
            .position(x: 235, y: 216)
        case .automation:
            posterLabel("SPENT", size: 12, width: 80)
                .position(x: 291, y: 210)
            posterLabel(isRTL ? "תשלום" : "PAYMENT", size: 10, width: 90)
                .position(x: 87, y: 126)
        case .finalReveal:
            posterLabel(name, size: 17, width: 139)
                .position(x: 110, y: 61)
            posterLabel("SPENT", size: 11, width: 90)
                .position(x: 252, y: 188)
        }
    }

    private func posterLabel(_ text: String, size: CGFloat, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .heavy))
            .foregroundStyle(Color.jetBlack)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: width)
            // Counter-mirror the glyphs locally, preserving their position in the artwork.
            .scaleEffect(x: isRTL ? -1 : 1, y: 1)
    }
}

/// Coordinates belong to the artwork only; screen layout remains adaptive SwiftUI.
private struct CityPosterDrawing: View {
    let step: OnboardingStep
    let layer: Int
    private let ink = Color.jetBlack
    private let stroke = StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round)

    var body: some View {
        Canvas { context, _ in
            switch step {
            case .concept: concept(&context)
            case .mayor: personalization(&context)
            case .spendingTarget: target(&context)
            case .automation: automation(&context)
            case .finalReveal: reveal(&context)
            }
        }
    }

    private func concept(_ c: inout GraphicsContext) {
        if layer == 0 {
            // A receipt and a takeaway cup: the transaction before the architecture.
            polygon(&c, [(24, 45), (85, 37), (95, 109), (84, 103), (74, 114),
                         (63, 107), (53, 117), (42, 110), (34, 121)], fill: .white)
            line(&c, [(41, 62), (71, 58)])
            line(&c, [(44, 74), (64, 71)])
            polygon(&c, [(59, 95), (115, 101), (103, 156), (66, 152)], fill: .orangeRed)
            polygon(&c, [(56, 88), (119, 95), (120, 105), (54, 98)], fill: .white)
            line(&c, [(83, 114), (80, 136)], color: .white, width: 5)
        } else if layer == 1 {
            var arrow = Path()
            arrow.move(to: CGPoint(x: 105, y: 189))
            arrow.addCurve(to: CGPoint(x: 218, y: 68),
                           control1: CGPoint(x: 160, y: 217), control2: CGPoint(x: 122, y: 53))
            c.stroke(arrow, with: .color(ink), style: stroke)
            line(&c, [(204, 55), (221, 68), (202, 79)])
        } else {
            building(&c, x: 174, y: 111, width: 146, height: 149, color: .babyBlue, shop: true)
            line(&c, [(153, 263), (344, 263)])
            line(&c, [(264, 69), (265, 53)])
            line(&c, [(282, 76), (293, 64)])
            tree(&c, x: 148, ground: 260, size: 0.58)
        }
    }

    private func personalization(_ c: inout GraphicsContext) {
        if layer == 0 {
            building(&c, x: 108, y: 145, width: 183, height: 132, color: .warmCream)
            line(&c, [(71, 278), (336, 278)])
        } else if layer == 1 {
            line(&c, [(100, 144), (100, 105)], width: 7)
            line(&c, [(274, 144), (274, 105)], width: 7)
            polygon(&c, [(65, 41), (312, 41), (318, 128), (70, 128)], fill: .jetBlack)
            rectangle(&c, 57, 34, 258, 89, fill: .white, radius: 5)
            circle(&c, 68, 44, 4, fill: .orangeRed)
            circle(&c, 300, 108, 4, fill: .orangeRed)
        } else {
            tree(&c, x: 60, ground: 276, size: 0.9)
            line(&c, [(325, 44), (339, 35)])
            line(&c, [(326, 63), (346, 63)])
        }
    }

    private func target(_ c: inout GraphicsContext) {
        if layer == 0 {
            polygon(&c, [(26, 143), (183, 80), (352, 153), (327, 245), (168, 279), (31, 223)], fill: .neonLime)
            var walk = Path()
            walk.move(to: CGPoint(x: 75, y: 237))
            walk.addCurve(to: CGPoint(x: 306, y: 135),
                          control1: CGPoint(x: 250, y: 250), control2: CGPoint(x: 86, y: 101))
            c.stroke(walk, with: .color(.warmCream), style: StrokeStyle(lineWidth: 19, lineCap: .round))
            line(&c, [(24, 245), (167, 293), (345, 254)], width: 2)
        } else if layer == 1 {
            tree(&c, x: 87, ground: 179, size: 1.05)
            tree(&c, x: 277, ground: 139, size: 0.93)
            tree(&c, x: 135, ground: 129, size: 0.68)
            // Bench, a consistent piece of the city rather than a budget score.
            polygon(&c, [(73, 210), (118, 224), (126, 215), (80, 201)], fill: .orangeRed)
            line(&c, [(79, 215), (77, 228)])
            line(&c, [(115, 226), (113, 239)])
        } else {
            line(&c, [(182, 254), (182, 230)], width: 5)
            line(&c, [(288, 254), (288, 230)], width: 5)
            rectangle(&c, 147, 181, 176, 70, fill: .warmCream, radius: 4)
        }
    }

    private func automation(_ c: inout GraphicsContext) {
        if layer == 0 {
            var card = c
            card.translateBy(x: 29, y: 42)
            card.rotate(by: .degrees(-9))
            rectangle(&card, 0, 0, 119, 77, fill: .orangeRed, radius: 10)
            rectangle(&card, 0, 17, 119, 13, fill: .jetBlack)
            rectangle(&card, 15, 45, 20, 15, fill: .warmCream, radius: 3)
            line(&card, [(75, 57), (96, 57)])
        } else if layer == 1 {
            var route = Path()
            route.move(to: CGPoint(x: 66, y: 154))
            route.addCurve(to: CGPoint(x: 203, y: 200),
                           control1: CGPoint(x: 35, y: 269), control2: CGPoint(x: 202, y: 283))
            route.addCurve(to: CGPoint(x: 276, y: 114),
                           control1: CGPoint(x: 200, y: 151), control2: CGPoint(x: 215, y: 84))
            c.stroke(route, with: .color(ink), style: stroke)
            line(&c, [(266, 95), (278, 115), (256, 119)])
            polygon(&c, [(137, 116), (184, 90), (228, 118), (181, 146)], fill: .babyBlue)
            polygon(&c, [(137, 103), (184, 77), (228, 105), (181, 133)], fill: .violetBlue)
            polygon(&c, [(186, 89), (169, 108), (181, 108), (176, 122), (196, 101), (183, 102)], fill: .white, outlined: false)
        } else {
            building(&c, x: 241, y: 165, width: 101, height: 113, color: .warmCream, shop: true)
            line(&c, [(230, 279), (359, 279)])
            line(&c, [(306, 136), (309, 121)])
            line(&c, [(323, 145), (335, 135)])
        }
    }

    private func reveal(_ c: inout GraphicsContext) {
        if layer == 0 {
            polygon(&c, [(19, 226), (173, 174), (357, 225), (306, 283), (108, 291)], fill: .neonLime)
            polygon(&c, [(85, 265), (235, 221), (336, 252), (323, 266), (236, 242), (110, 281)], fill: .warmCream, outlined: false)
            building(&c, x: 179, y: 65, width: 77, height: 161, color: .babyBlue)
            building(&c, x: 284, y: 117, width: 52, height: 111, color: .orangeRed)
        } else if layer == 1 {
            building(&c, x: 48, y: 97, width: 121, height: 144, color: .warmCream)
            building(&c, x: 193, y: 145, width: 111, height: 108, color: .white, shop: true)
            line(&c, [(65, 98), (65, 64)], width: 4)
            line(&c, [(151, 98), (151, 64)], width: 4)
            rectangle(&c, 31, 39, 158, 45, fill: .neonLime, radius: 4)
        } else {
            tree(&c, x: 32, ground: 261, size: 0.7)
            tree(&c, x: 328, ground: 249, size: 0.85)
            tree(&c, x: 144, ground: 269, size: 0.64)
            // A tiny bus adds a final, grounded city detail.
            rectangle(&c, 214, 264, 62, 23, fill: .orangeRed, radius: 6)
            rectangle(&c, 224, 268, 31, 8, fill: .babyBlue, radius: 2)
            circle(&c, 226, 287, 5, fill: .jetBlack)
            circle(&c, 263, 287, 5, fill: .jetBlack)
        }
    }

    private func building(_ c: inout GraphicsContext, x: CGFloat, y: CGFloat,
                          width: CGFloat, height: CGFloat, color: Color, shop: Bool = false) {
        // Shallow side plane and a roof lip give depth without isometric clutter.
        polygon(&c, [(x + width, y), (x + width + 12, y - 8),
                     (x + width + 12, y + height - 8), (x + width, y + height)], fill: .jetBlack)
        rectangle(&c, x, y, width, height, fill: color, radius: 2)
        polygon(&c, [(x - 5, y), (x + 7, y - 10), (x + width + 15, y - 10),
                     (x + width + 5, y)], fill: .white)
        if shop {
            rectangle(&c, x + 12, y + height * 0.22, width - 24, 26, fill: .warmCream)
            let stripeWidth = width / 6
            for index in 0..<6 {
                rectangle(&c, x + CGFloat(index) * stripeWidth, y + height * 0.53,
                          stripeWidth, 19, fill: index.isMultiple(of: 2) ? .orangeRed : .warmCream)
            }
            rectangle(&c, x + 14, y + height * 0.73, width * 0.31, height * 0.27, fill: .jetBlack)
            rectangle(&c, x + width * 0.57, y + height * 0.73, width * 0.27, height * 0.17, fill: .white)
        } else {
            for row in 0..<2 {
                for column in 0..<3 {
                    let windowWidth = width * 0.14
                    let windowX = x + width * 0.15 + CGFloat(column) * width * 0.28
                    let windowY = y + 20 + CGFloat(row) * height * 0.28
                    rectangle(&c, windowX, windowY, windowWidth, height * 0.15, fill: .jetBlack, radius: 1)
                    line(&c, [(windowX + 3, windowY + 3), (windowX + 3, windowY + height * 0.1)], color: .white, width: 2)
                }
            }
            rectangle(&c, x + width * 0.4, y + height * 0.75, width * 0.22, height * 0.25, fill: .violetBlue)
        }
    }

    private func tree(_ c: inout GraphicsContext, x: CGFloat, ground: CGFloat, size: CGFloat) {
        var local = c
        local.translateBy(x: x, y: ground)
        local.scaleBy(x: size, y: size)
        line(&local, [(0, 0), (0, -67)], width: 3)
        let canopy = Path(ellipseIn: CGRect(x: -20, y: -85, width: 40, height: 60))
        local.fill(canopy, with: .color(.luckyGreen))
        local.stroke(canopy, with: .color(ink), style: stroke)
        line(&local, [(0, -19), (0, -61)])
        line(&local, [(0, -39), (-10, -49)])
    }

    private func rectangle(_ c: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat,
                           _ w: CGFloat, _ h: CGFloat, fill: Color, radius: CGFloat = 0) {
        let path = Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius)
        c.fill(path, with: .color(fill))
        c.stroke(path, with: .color(ink), style: stroke)
    }

    private func circle(_ c: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, fill: Color) {
        let path = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        c.fill(path, with: .color(fill))
        c.stroke(path, with: .color(ink), style: stroke)
    }

    private func polygon(_ c: inout GraphicsContext, _ points: [(CGFloat, CGFloat)],
                         fill: Color, outlined: Bool = true) {
        let path = path(points, closed: true)
        c.fill(path, with: .color(fill))
        if outlined { c.stroke(path, with: .color(ink), style: stroke) }
    }

    private func line(_ c: inout GraphicsContext, _ points: [(CGFloat, CGFloat)],
                      color: Color = .jetBlack, width: CGFloat = 2.8) {
        c.stroke(path(points), with: .color(color),
                 style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func path(_ points: [(CGFloat, CGFloat)], closed: Bool = false) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: CGPoint(x: first.0, y: first.1))
            for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.0, y: point.1)) }
            if closed { path.closeSubpath() }
        }
    }
}

#Preview("Onboarding • illustration collection") {
    ScrollView {
        VStack(spacing: 0) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                OnboardingCityScene(step: step, mayorName: "דניאל", targetAmountText: "8,000", isRTL: true, animateEntrance: false)
                    .padding(20)
                    .background(step.posterBackground)
            }
        }
    }
}
