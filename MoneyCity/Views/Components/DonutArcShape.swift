import SwiftUI

public struct DonutArcShape: Shape {
    public var startAngle: Double
    public var endAngle: Double

    public var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle, endAngle) }
        set {
            startAngle = newValue.first
            endAngle = newValue.second
        }
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max((min(rect.width, rect.height) - 30) / 2, 10)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )
        return path
    }
}

/// A crisp radial separator line between donut slices
public struct DonutRadialSeparator: Shape {
    public var angle: Double
    public var innerRadius: CGFloat
    public var outerRadius: CGFloat

    public var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    public init(angle: Double, innerRadius: CGFloat = 63, outerRadius: CGFloat = 93) {
        self.angle = angle
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rad = CGFloat(angle) * .pi / 180.0
        let p1 = CGPoint(
            x: center.x + innerRadius * cos(rad),
            y: center.y + innerRadius * sin(rad)
        )
        let p2 = CGPoint(
            x: center.x + outerRadius * cos(rad),
            y: center.y + outerRadius * sin(rad)
        )
        path.move(to: p1)
        path.addLine(to: p2)
        return path
    }
}

public struct DonutSliceData: Identifiable {
    public let id: String
    public let category: SpendingCategory
    public let name: String
    public let icon: MoneyIconType?
    public let color: Color
    public let amount: Double
    public let fraction: Double
    public let count: Int
    public let startAngle: Double
    public let endAngle: Double
    public let rawStartAngle: Double
    public let rawEndAngle: Double

    public init(
        id: String,
        category: SpendingCategory,
        name: String,
        icon: MoneyIconType?,
        color: Color,
        amount: Double,
        fraction: Double,
        count: Int,
        startAngle: Double,
        endAngle: Double,
        rawStartAngle: Double,
        rawEndAngle: Double
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.icon = icon
        self.color = color
        self.amount = amount
        self.fraction = fraction
        self.count = count
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.rawStartAngle = rawStartAngle
        self.rawEndAngle = rawEndAngle
    }
}
