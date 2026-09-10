import SwiftUI

// MARK: - Dedicated Helper Vector Shapes

struct RoofTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct ReceiptJaggedShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 2))
        // 3 zigzag teeth
        let step = rect.width / 4
        p.addLine(to: CGPoint(x: rect.maxX - step * 0.5, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - step * 1.0, y: rect.maxY - 2))
        p.addLine(to: CGPoint(x: rect.maxX - step * 1.5, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - step * 2.0, y: rect.maxY - 2))
        p.addLine(to: CGPoint(x: rect.maxX - step * 2.5, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - step * 3.0, y: rect.maxY - 2))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct PieSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        p.move(to: center)
        p.addArc(center: center, radius: rect.width / 2, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct CalendarHeaderShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = min(3.5, rect.height, rect.width / 2)
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct BellDomeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX + 1, y: rect.minY + 2))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.maxX - 1, y: rect.minY + 2))
        p.closeSubpath()
        return p
    }
}

struct TrayShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

struct ArrowUpShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.45))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.45))
        return p
    }
}

struct ArrowDownShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.45))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.45))
        return p
    }
}

struct TriangleRightShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct TriangleLeftShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct MountainPeakShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.7, y: rect.maxY * 0.6))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct CornerBracketsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let len = rect.width * 0.28
        // Top-Left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))
        // Top-Right
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))
        // Bottom-Right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - len, y: rect.maxY))
        // Bottom-Left
        p.move(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - len))
        return p
    }
}

struct CartBasketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + 3, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct ForkProngsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.6))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.6))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}

struct KnifeBladeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.minY + 2))
        p.closeSubpath()
        return p
    }
}

struct CeramicMugShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 3.5
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct MugHandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control: CGPoint(x: rect.maxX + 1.5, y: rect.midY))
        return p
    }
}

struct CarBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.5))
        p.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY), control: CGPoint(x: rect.minX + 2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.5), control: CGPoint(x: rect.maxX - 2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct HoseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.maxX + 3, y: rect.minY + 2))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return p
    }
}

struct AirlinerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midX = rect.midX
        let h = rect.height

        // 1. Nose (Curved aerodynamic nose dome)
        p.move(to: CGPoint(x: midX - 2.2, y: h * 0.08))
        p.addQuadCurve(to: CGPoint(x: midX + 2.2, y: h * 0.08), control: CGPoint(x: midX, y: 0))

        // 2. Right fuselage down to wing root
        p.addLine(to: CGPoint(x: midX + 2.2, y: h * 0.32))

        // 3. Right Swept Wing (Authentic airliner wing with rounded flat tip)
        p.addLine(to: CGPoint(x: rect.maxX - 0.5, y: h * 0.50))
        p.addLine(to: CGPoint(x: rect.maxX - 0.5, y: h * 0.60))
        p.addLine(to: CGPoint(x: midX + 2.2, y: h * 0.60))

        // 4. Right fuselage to tail root
        p.addLine(to: CGPoint(x: midX + 1.8, y: h * 0.82))

        // 5. Right Tail Stabilizer (Small stabilizer wing at tail)
        p.addLine(to: CGPoint(x: midX + 6.0, y: h * 0.94))
        p.addLine(to: CGPoint(x: midX + 5.5, y: rect.maxY))
        p.addLine(to: CGPoint(x: midX, y: h * 0.96))

        // 6. Left Tail Stabilizer
        p.addLine(to: CGPoint(x: midX - 5.5, y: rect.maxY))
        p.addLine(to: CGPoint(x: midX - 6.0, y: h * 0.94))
        p.addLine(to: CGPoint(x: midX - 1.8, y: h * 0.82))

        // 7. Left fuselage from tail to wing
        p.addLine(to: CGPoint(x: midX - 2.2, y: h * 0.60))

        // 8. Left Swept Wing
        p.addLine(to: CGPoint(x: rect.minX + 0.5, y: h * 0.60))
        p.addLine(to: CGPoint(x: rect.minX + 0.5, y: h * 0.50))
        p.addLine(to: CGPoint(x: midX - 2.2, y: h * 0.32))

        p.closeSubpath()
        return p
    }
}

struct GamepadBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 3, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.maxX + 2, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.maxY * 0.8))
        p.addLine(to: CGPoint(x: rect.minX + 4, y: rect.maxY * 0.8))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + 3, y: rect.minY), control: CGPoint(x: rect.minX - 2, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

struct MedicalCrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let arm = w * 0.35
        let start = (w - arm) / 2
        p.move(to: CGPoint(x: start, y: 0))
        p.addLine(to: CGPoint(x: start + arm, y: 0))
        p.addLine(to: CGPoint(x: start + arm, y: start))
        p.addLine(to: CGPoint(x: w, y: start))
        p.addLine(to: CGPoint(x: w, y: start + arm))
        p.addLine(to: CGPoint(x: start + arm, y: start + arm))
        p.addLine(to: CGPoint(x: start + arm, y: w))
        p.addLine(to: CGPoint(x: start, y: w))
        p.addLine(to: CGPoint(x: start, y: start + arm))
        p.addLine(to: CGPoint(x: 0, y: start + arm))
        p.addLine(to: CGPoint(x: 0, y: start))
        p.addLine(to: CGPoint(x: start, y: start))
        p.closeSubpath()
        return p
    }
}

struct CoinCylinderShape: Shape {
    let depth: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let ry = rect.height / 2
        let midX = rect.midX
        let topMidY = rect.minY + ry
        let botMidY = topMidY + depth

        p.move(to: CGPoint(x: rect.minX, y: topMidY))
        p.addLine(to: CGPoint(x: rect.minX, y: botMidY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: botMidY), control: CGPoint(x: midX, y: botMidY + ry))
        p.addLine(to: CGPoint(x: rect.maxX, y: topMidY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: topMidY), control: CGPoint(x: midX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

struct HalfEllipseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.minY), radius: rect.width / 2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct BagHandleUshape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 3.0))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + 3.0), control: CGPoint(x: rect.midX, y: rect.minY - 1.0))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}

struct TShirtShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - rect.width * 0.35, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.minY + 3))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.35))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.minY + rect.height * 0.45))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.45))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.35))
        p.closeSubpath()
        return p
    }
}

struct TicketNotchedShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - 2.5))
        p.addArc(center: CGPoint(x: rect.maxX, y: rect.midY), radius: 2.5, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY + 2.5))
        p.addArc(center: CGPoint(x: rect.minX, y: rect.midY), radius: 2.5, startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true)
        p.closeSubpath()
        return p
    }
}

struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let side = min(rect.width, rect.height)
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + side * 0.35),
                   control1: CGPoint(x: rect.midX - side * 0.45, y: rect.maxY - side * 0.3),
                   control2: CGPoint(x: rect.minX, y: rect.minY + side * 0.65))
        p.addArc(center: CGPoint(x: rect.minX + side * 0.25, y: rect.minY + side * 0.3),
                 radius: side * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x: rect.maxX - side * 0.25, y: rect.minY + side * 0.3),
                 radius: side * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                   control1: CGPoint(x: rect.maxX, y: rect.minY + side * 0.65),
                   control2: CGPoint(x: rect.midX + side * 0.45, y: rect.maxY - side * 0.3))
        p.closeSubpath()
        return p
    }
}

struct StarPolygonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = rect.width / 2
        let innerR = outerR * 0.45
        for i in 0..<10 {
            let angle = CGFloat(i) * .pi / 5 - .pi / 2
            let r = i % 2 == 0 ? outerR : innerR
            let pt = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct IslandHillShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

struct PalmTreeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Trunk
        p.move(to: CGPoint(x: rect.midX - 1.5, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.midX - 1, y: rect.midY), control: CGPoint(x: rect.midX - 3, y: rect.maxY * 0.7))
        // Canopy crown leaves
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + 4), control: CGPoint(x: rect.midX - 5, y: rect.minY + 2))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX + 4, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + 4), control: CGPoint(x: rect.midX + 4, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.midX + 1, y: rect.midY), control: CGPoint(x: rect.maxX - 4, y: rect.minY + 4))
        p.addQuadCurve(to: CGPoint(x: rect.midX + 1.5, y: rect.maxY), control: CGPoint(x: rect.midX - 1, y: rect.maxY * 0.7))
        p.closeSubpath()
        return p
    }
}

struct EnvelopeFlapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY * 0.65))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

struct ChatBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - 3), cornerSize: CGSize(width: 4, height: 4))
        p.move(to: CGPoint(x: rect.minX + 3, y: rect.maxY - 3))
        p.addLine(to: CGPoint(x: rect.minX + 1, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + 7, y: rect.maxY - 3))
        p.closeSubpath()
        return p
    }
}

struct SmileArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.minY), radius: rect.width / 2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        return p
    }
}

struct PhoneReceiverShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.midX + 2, y: rect.midY), control: CGPoint(x: rect.maxX, y: rect.midY - 2))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - 2, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.midY + 2))
        p.addLine(to: CGPoint(x: rect.minX + 2, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.midX - 2, y: rect.midY), control: CGPoint(x: rect.minX, y: rect.midY + 2))
        p.addQuadCurve(to: CGPoint(x: rect.minX + 2, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.midY - 2))
        p.closeSubpath()
        return p
    }
}

struct PaperPlaneShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.7))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY * 0.6))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY * 0.6))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX * 0.75, y: rect.maxY * 0.75))
        p.closeSubpath()
        return p
    }
}

struct DocDogEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let fold: CGFloat = 4.5
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct FolderShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + 3))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.minY + 3))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.5, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct TrashCanShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - 1.5, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + 1.5, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct PencilShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY - 4))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 4))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

struct BookmarkRibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 4))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct FlagBannerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + 2), control: CGPoint(x: rect.midX, y: rect.minY - 2))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - 2), control: CGPoint(x: rect.midX, y: rect.maxY + 2))
        p.closeSubpath()
        return p
    }
}

struct RefreshArrowsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = rect.width * 0.42
        // Top semi
        p.addArc(center: c, radius: r, startAngle: .degrees(-150), endAngle: .degrees(-10), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - 2))
        // Bottom semi
        p.addArc(center: c, radius: r, startAngle: .degrees(30), endAngle: .degrees(170), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY + 2))
        return p
    }
}

struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 3, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.maxX - 4, y: rect.maxY - 4), radius: 4, startAngle: .degrees(90), endAngle: .degrees(-45), clockwise: false)
        p.addArc(center: CGPoint(x: rect.midX, y: rect.minY + 4), radius: 5.5, startAngle: .degrees(-30), endAngle: .degrees(-150), clockwise: false)
        p.addArc(center: CGPoint(x: rect.minX + 4, y: rect.maxY - 4), radius: 4, startAngle: .degrees(-135), endAngle: .degrees(90), clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct CrescentMoonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2, startAngle: .degrees(-110), endAngle: .degrees(110), clockwise: false)
        p.addQuadCurve(to: CGPoint(x: rect.midX + rect.width * 0.15, y: rect.minY + 2), control: CGPoint(x: rect.midX + 2, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

struct LightningShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX - 2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX + 2, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.minX + 1, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control: CGPoint(x: rect.maxX - 1, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct LeafVeinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 1.5, y: rect.maxY - 1.5))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - 2, y: rect.minY + 2), control: CGPoint(x: rect.midX * 0.9, y: rect.midY * 1.1))
        // Branch veins
        p.move(to: CGPoint(x: rect.width * 0.38, y: rect.height * 0.65))
        p.addLine(to: CGPoint(x: rect.width * 0.22, y: rect.height * 0.50))
        p.move(to: CGPoint(x: rect.width * 0.60, y: rect.height * 0.40))
        p.addLine(to: CGPoint(x: rect.width * 0.74, y: rect.height * 0.54))
        return p
    }
}

struct WaterDropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.65), control: CGPoint(x: rect.maxX - 1, y: rect.midY))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY * 0.65), radius: rect.width / 2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX + 1, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

struct FlameOutlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.7), control: CGPoint(x: rect.maxX + 1, y: rect.minY + 4))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY * 0.7), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX - 1, y: rect.minY + 4))
        p.closeSubpath()
        return p
    }
}

struct SnowflakeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = rect.width / 2
        for i in 0..<3 {
            let angle = CGFloat(i) * .pi / 3
            let dx = r * cos(angle)
            let dy = r * sin(angle)
            p.move(to: CGPoint(x: c.x - dx, y: c.y - dy))
            p.addLine(to: CGPoint(x: c.x + dx, y: c.y + dy))
        }
        return p
    }
}

struct MapPinTeardropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + rect.width * 0.5),
                   control1: CGPoint(x: rect.midX - 2, y: rect.maxY * 0.65),
                   control2: CGPoint(x: rect.minX, y: rect.maxY * 0.45))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.minY + rect.width * 0.5),
                 radius: rect.width / 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                   control1: CGPoint(x: rect.maxX, y: rect.maxY * 0.45),
                   control2: CGPoint(x: rect.midX + 2, y: rect.maxY * 0.65))
        p.closeSubpath()
        return p
    }
}

struct NavCompassShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY * 0.75))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct TrophyCupShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 3.5, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - 3.5, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.maxX - 2, y: rect.maxY * 0.75))
        p.addQuadCurve(to: CGPoint(x: rect.minX + 3.5, y: rect.minY), control: CGPoint(x: rect.minX + 2, y: rect.maxY * 0.75))
        // Handles
        p.move(to: CGPoint(x: rect.minX + 3.5, y: rect.minY + 2))
        p.addQuadCurve(to: CGPoint(x: rect.minX + 3.5, y: rect.maxY * 0.55), control: CGPoint(x: rect.minX - 2, y: rect.midY))
        p.move(to: CGPoint(x: rect.maxX - 3.5, y: rect.minY + 2))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - 3.5, y: rect.maxY * 0.55), control: CGPoint(x: rect.maxX + 2, y: rect.midY))
        return p
    }
}

struct UserBustShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

struct ChevronShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return p
    }
}

struct BackspaceTagShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}
