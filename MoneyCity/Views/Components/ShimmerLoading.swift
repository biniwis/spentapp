import SwiftUI

/// Universal Shimmer effect for skeleton loading screens
public struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0

    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let w = geo.size.width
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color.white.opacity(0.65), location: 0.5),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: max(w * 0.7, 100))
                    .offset(x: phase * max(w * 1.7, 200))
                    .blendMode(.screen)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

public extension View {
    /// Applies a continuous fluid shimmer sweep to indicate loading state.
    func shimmering() -> some View {
        self.modifier(ShimmerModifier())
    }
}

/// Transaction Row Skeleton Placeholder
public struct TransactionSkeletonRow: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.borderSubtle)
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.borderSubtle)
                    .frame(width: 120, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.borderSubtle.opacity(0.6))
                    .frame(width: 70, height: 10)
            }
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.borderSubtle)
                .frame(width: 55, height: 18)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .shimmering()
    }
}

/// Interactive Holographic Receipt Scanner Placeholder Card
public struct ReceiptScanningSkeletonView: View {
    @State private var scanBeamOffset: CGFloat = -40
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .top) {
                // Receipt Paper Shape
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardBackground)
                    .frame(height: 120)
                    .overlay(
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Circle().fill(Color.themeMintSoft).frame(width: 24, height: 24)
                                RoundedRectangle(cornerRadius: 4).fill(Color.borderSubtle).frame(width: 80, height: 12)
                                Spacer()
                                RoundedRectangle(cornerRadius: 4).fill(Color.borderSubtle).frame(width: 40, height: 12)
                            }
                            RoundedRectangle(cornerRadius: 4).fill(Color.borderSubtle.opacity(0.7)).frame(width: 140, height: 10)
                            RoundedRectangle(cornerRadius: 4).fill(Color.borderSubtle.opacity(0.5)).frame(width: 100, height: 10)
                            Spacer()
                            HStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 6).fill(Color.primaryBlue.opacity(0.2)).frame(width: 60, height: 16)
                            }
                        }
                        .padding(14)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.themeMint.opacity(0.4), lineWidth: 1.5)
                    )
                    .shadow(color: Color.deepNavy.opacity(0.04), radius: 8, y: 3)
                
                // Laser Scanning Line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.themeMint.opacity(0), Color.themeMint, Color.themeMint.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
                    .shadow(color: Color.themeMint.opacity(0.8), radius: 4)
                    .offset(y: scanBeamOffset)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(height: 120)
            
            HStack(spacing: 8) {
                ProgressView().tint(Color.themeMint)
                Text("מפענח סכום ופרטי עסק מתמונת הקבלה...")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color.themeMint)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                scanBeamOffset = 110
            }
        }
    }
}

/// Category Card Skeleton Placeholder
public struct CategorySkeletonGrid: View {
    public init() {}
    public var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(0..<4) { _ in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.borderSubtle)
                        .frame(width: 36, height: 36)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.borderSubtle)
                        .frame(width: 60, height: 12)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.borderSubtle, lineWidth: 1.2))
            }
        }
        .padding(.horizontal, 20)
        .shimmering()
    }
}
