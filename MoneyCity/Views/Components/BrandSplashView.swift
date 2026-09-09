import SwiftUI

/// Clean, iconic animated brand splash screen displayed on cold launch.
/// Original beloved entrance rhythm of "SPENT", holds for exactly 0.80s after
/// the letters complete, and then dissolves seamlessly into the living 3D city diorama.
public struct BrandSplashView: View {
    @Binding var isPresented: Bool
    let isHebrew: Bool

    @State private var letterVisible: [Bool] = [false, false, false, false, false]
    @State private var isExiting: Bool = false
    @State private var dioramaHasSignaled: Bool = false
    @State private var minHoldElapsed: Bool = false

    private let letters = ["S", "P", "E", "N", "T"]
    private let bgColor = Color(red: 248/255, green: 250/255, blue: 252/255)

    public init(isPresented: Binding<Bool>, isHebrew: Bool = true) {
        self._isPresented = isPresented
        self.isHebrew = isHebrew
    }

    public var body: some View {
        ZStack {
            bgColor
                .ignoresSafeArea()

            // Pure, iconic SPENT wordmark - strictly Left-to-Right
            HStack(spacing: 5) {
                ForEach(0..<letters.count, id: \.self) { index in
                    Text(letters[index])
                        .font(.system(size: 50, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                        .offset(y: letterVisible[index] ? 0 : 22)
                        .scaleEffect(letterVisible[index] ? 1.0 : 0.6)
                        .opacity(letterVisible[index] ? 1.0 : 0.0)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .flipsForRightToLeftLayoutDirection(false)
            .tracking(3.5)
            .scaleEffect(isExiting ? 1.06 : 1.0)
            .opacity(isExiting ? 0.0 : 1.0)
        }
        .environment(\.layoutDirection, .leftToRight)
        .opacity(isExiting ? 0.0 : 1.0)
        .allowsHitTesting(false)
        .onAppear {
            animateEntrance()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dioramaReady)) { _ in
            dioramaHasSignaled = true
            if minHoldElapsed {
                dismissSplash()
            }
        }
    }

    private func animateEntrance() {
        // 1. Original beloved entrance tempo: S -> P -> E -> N -> T
        for i in 0..<letters.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.10 + 0.05) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                    letterVisible[i] = true
                }
            }
        }

        // 2. Light haptic tick when wordmark completes (at 0.52s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            Haptics.impact(.light)
        }

        // 3. Hold for exactly 0.80s after all letters appear (0.52 + 0.80 = 1.32s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.32) {
            minHoldElapsed = true
            if dioramaHasSignaled {
                dismissSplash()
            }
        }

        // 4. Fallback maximum hold in case diorama takes longer
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            dismissSplash()
        }
    }

    private func dismissSplash() {
        guard !isExiting else { return }
        withAnimation(.spring(response: 0.48, dampingFraction: 0.88)) {
            isExiting = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
            isPresented = false
        }
    }
}
