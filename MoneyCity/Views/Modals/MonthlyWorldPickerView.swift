import SwiftUI

/// Lightweight monthly world selection sheet presented at the start of a new month.
/// Uses the same swipe carousel as the onboarding Step 5 preview.
public struct MonthlyWorldPickerView: View {
    /// The month this picker is selecting a world for. Used for the display name only.
    public let targetMonth: Date
    @Binding public var draft: CityMapStyle
    public let isHebrew: Bool
    public let onConfirm: (CityMapStyle) -> Void

    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isHebrew ? "he_IL" : "en_US")
        formatter.dateFormat = "LLLL"
        return formatter.string(from: targetMonth)
    }

    /// The worlds shown in this picker — always uses the product-controlled list
    /// so `.future` (and any other unreleased world) is never surfaced here.
    private let worlds = CityMapSelection.pickerWorlds

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isHebrew ? "חודש חדש, עיר חדשה." : "New month, new city.")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .tracking(-1)
                    .foregroundStyle(Color.jetBlack)

                Text(isHebrew
                    ? "בחר את העולם של \(monthName)."
                    : "Choose your world for \(monthName).")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Color.jetBlack.opacity(0.65))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 20)

            // ── World preview carousel ──
            ZStack {
                ThreeDioramaView(
                    mapStyle: draft,
                    totalSpent: 0,
                    totalSavings: 0,
                    categoryTotals: [:],
                    selectedDistrict: nil,
                    language: isHebrew ? "he" : "en",
                    isPaused: false,
                    onSelectDistrict: { _ in },
                    onBuildingSelected: { _ in }
                )
                .allowsHitTesting(false)
                .id(draft)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .accessibilityLabel(draft.title(isHebrew: isHebrew))

                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .frame(height: 260)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 10)
                            .onEnded { value in
                                guard abs(value.translation.width) > abs(value.translation.height),
                                      abs(value.translation.width) > 20 else { return }
                                guard let idx = worlds.firstIndex(of: draft) else { return }
                                let delta = isHebrew
                                    ? (value.translation.width > 0 ? 1 : -1)
                                    : (value.translation.width < 0 ? 1 : -1)
                                let next = worlds[(idx + delta + worlds.count) % worlds.count]
                                withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .easeInOut(duration: 0.25)) {
                                    draft = next
                                }
                                Haptics.selection()
                            }
                    )
            }
            .accessibilityAdjustableAction { direction in
                guard let idx = worlds.firstIndex(of: draft) else { return }
                switch direction {
                case .increment:
                    draft = worlds[(idx + 1) % worlds.count]
                case .decrement:
                    draft = worlds[(idx - 1 + worlds.count) % worlds.count]
                @unknown default: break
                }
            }
            .padding(.horizontal, 12)

            // Page dots — tappable
            HStack(spacing: 8) {
                ForEach(worlds) { style in
                    Button {
                        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .easeInOut(duration: 0.25)) {
                            draft = style
                        }
                        Haptics.selection()
                    } label: {
                        Circle()
                            .fill(style == draft ? Color.jetBlack : Color.jetBlack.opacity(0.2))
                            .frame(width: 7, height: 7)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(style.title(isHebrew: isHebrew))
                }
            }
            .padding(.top, 12)

            HStack(spacing: 8) {
                Text(draft.title(isHebrew: isHebrew))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.jetBlack)

                Text("·")
                    .foregroundStyle(Color.jetBlack.opacity(0.4))

                Text(isHebrew ? "החלק כדי להחליף" : "Swipe to switch")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.jetBlack.opacity(0.65))
            }
            .padding(.top, 8)

            Spacer(minLength: 24)

            Button {
                Haptics.impact(.medium)
                onConfirm(draft)
            } label: {
                Text(isHebrew ? "בחרתי" : "Choose")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .frame(minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.jetBlack)
                    )
            }
            .buttonStyle(.plain)
            .bouncyPress(scale: reduceMotion ? 1 : 0.97)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.warmCream.ignoresSafeArea())
        .environment(\.layoutDirection, isHebrew ? .rightToLeft : .leftToRight)
    }
}

#Preview("Monthly World Picker") {
    MonthlyWorldPickerView(
        targetMonth: Date(),
        draft: .constant(.urban),
        isHebrew: true,
        onConfirm: { _ in }
    )
    .environmentObject(LocalizationManager())
}
