import SwiftUI

/// Animated placeholder shown while the WebGL diorama scene is loading.
/// Mimics the city skyline silhouette with shimmer effect.
public struct DioramaSkeletonView: View {
    var onReady: (() -> Void)? = nil

    @State private var shimmerOffset: CGFloat = -1.0
    @State private var pulse: Bool = false

    private let skyTop    = Color(red: 248/255, green: 250/255, blue: 252/255)
    private let skyBottom = Color(red: 241/255, green: 245/255, blue: 249/255)
    private let buildingA = Color(red: 203/255, green: 213/255, blue: 225/255)
    private let buildingB = Color(red: 226/255, green: 232/255, blue: 240/255)
    private let groundCol = Color(red: 241/255, green: 245/255, blue: 249/255)

    public init(onReady: (() -> Void)? = nil) {
        self.onReady = onReady
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .bottom) {
                // Sky gradient
                LinearGradient(colors: [skyTop, skyBottom], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                // City silhouette
                CityHorizonShape()
                    .fill(buildingA.opacity(0.6))
                    .frame(height: h * 0.55)

                CityHorizonShape(offsetX: 30, scaleY: 0.85)
                    .fill(buildingB.opacity(0.8))
                    .frame(height: h * 0.50)

                // Ground strip
                Rectangle()
                    .fill(groundCol)
                    .frame(height: h * 0.12)

                // Shimmer sweep
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.5),
                        Color.white.opacity(0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: w * 0.4)
                .offset(x: shimmerOffset * w)
                .allowsHitTesting(false)

                VStack(spacing: 10) {
                    DistrictSkylineVectorIcon(color: Color.primaryBlue)
                        .scaleEffect(pulse ? 1.35 : 1.15)
                        .animation(Animation.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                    Text("בונה את עיר הכסף שלך...")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                }
                .padding(.bottom, h * 0.22)
            }
        }
        .onAppear {
            pulse = true
            withAnimation(
                .linear(duration: 1.4).repeatForever(autoreverses: false)
            ) {
                shimmerOffset = 1.3
            }
        }
        .background(skyTop)
    }
}

/// A simple path that draws a stylized city building skyline.
private struct CityHorizonShape: Shape {
    var offsetX: CGFloat = 0
    var scaleY: CGFloat = 1.0

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height * scaleY
        let b = rect.height   // bottom baseline

        // List of (x_frac, height_frac) pairs for building tops
        let buildings: [(CGFloat, CGFloat)] = [
            (0.00, 0.0),
            (0.00, 0.55),
            (0.07, 0.55),
            (0.07, 0.40),
            (0.13, 0.40),
            (0.13, 0.75),
            (0.18, 0.75),
            (0.18, 0.60),
            (0.24, 0.60),
            (0.24, 0.90),
            (0.30, 0.90),
            (0.30, 0.65),
            (0.36, 0.65),
            (0.36, 0.45),
            (0.43, 0.45),
            (0.43, 1.00),
            (0.50, 1.00),
            (0.50, 0.70),
            (0.56, 0.70),
            (0.56, 0.55),
            (0.63, 0.55),
            (0.63, 0.80),
            (0.70, 0.80),
            (0.70, 0.50),
            (0.77, 0.50),
            (0.77, 0.65),
            (0.84, 0.65),
            (0.84, 0.40),
            (0.91, 0.40),
            (0.91, 0.58),
            (1.00, 0.58),
            (1.00, 0.0),
        ]

        var path = Path()
        path.move(to: CGPoint(x: offsetX, y: b))
        for (xf, hf) in buildings {
            let x = offsetX + xf * (w - offsetX)
            let y = b - hf * h
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: w, y: b))
        path.closeSubpath()
        return path
    }
}
