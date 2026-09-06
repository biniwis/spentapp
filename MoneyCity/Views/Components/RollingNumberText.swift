import SwiftUI

/// Animated rolling counter text for SPENT financial KPIs.
/// Smoothly interpolates numeric values with spring physics and numeric digit transitions.
public struct RollingNumberText: View, Animatable {
    public var value: Double
    private let format: (Double) -> String
    private let font: Font
    private let color: Color
    
    public var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    
    public init(
        value: Double,
        format: @escaping (Double) -> String,
        font: Font = .system(size: 40, weight: .black, design: .rounded),
        color: Color = Color.deepNavy
    ) {
        self.value = value
        self.format = format
        self.font = font
        self.color = color
    }
    
    public var body: some View {
        Text(format(value.rounded()))
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText(countsDown: false))
    }
}
