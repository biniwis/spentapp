import SwiftUI

/// Monthly world selection sheet presented at the start of a new month or from Profile.
/// Features a top shopping street district sample (`isDistrictSample: true`) that reflects
/// the selected draft, followed by a clean selection list with current and next month badges.
public struct MonthlyWorldPickerView: View {
    /// The month this picker is selecting a world for.
    public let targetMonth: Date
    @Binding public var draft: CityMapStyle
    public let isHebrew: Bool
    public let onConfirm: (CityMapStyle) -> Void

    public init(
        targetMonth: Date,
        draft: Binding<CityMapStyle>,
        isHebrew: Bool,
        onConfirm: @escaping (CityMapStyle) -> Void
    ) {
        self.targetMonth = targetMonth
        self._draft = draft
        self.isHebrew = isHebrew
        self.onConfirm = onConfirm
    }

    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var targetMonthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isHebrew ? "he_IL" : "en_US")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: targetMonth)
    }

    private var isCurrentMonthTarget: Bool {
        Calendar.current.isDate(targetMonth, equalTo: Date(), toGranularity: .month)
    }

    /// Allowed worlds in the picker (excludes .future)
    private let worlds = CityMapSelection.pickerWorlds

    private var headerSubtitleText: String {
        if isHebrew {
            return isCurrentMonthTarget
                ? "בחר את מראה העיר עבור חודש \(targetMonthName)"
                : "בחר מראש את מראה העיר עבור חודש \(nextMonthName)"
        } else {
            return isCurrentMonthTarget
                ? "Choose your city style for \(targetMonthName)"
                : "Select in advance your city style for \(nextMonthName)"
        }
    }

    private var nextMonthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isHebrew ? "he_IL" : "en_US")
        formatter.dateFormat = "LLLL"
        return formatter.string(from: targetMonth)
    }

    @GestureState private var mapDrag: CGFloat = 0

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text(isHebrew ? (isCurrentMonthTarget ? "מפת החודש" : "מפת החודש הבא") : (isCurrentMonthTarget ? "This Month's Map" : "Next Month's Map"))
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .tracking(-1)
                    .foregroundStyle(Color.jetBlack)

                Text(headerSubtitleText)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Color.jetBlack.opacity(0.65))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 12)

            // ── Floating 3D Diorama (Pure on Canvas, No Card/Border) ──
            GeometryReader { geometry in
                let selectedIndex = worlds.firstIndex(of: draft) ?? 0
                let direction: CGFloat = isHebrew ? -1 : 1

                ZStack {
                    ForEach(Array(worlds.enumerated()), id: \.element.id) { index, style in
                        ThreeDioramaView(
                            mapStyle: style,
                            isDistrictSample: true,
                            totalSpent: 0,
                            totalSavings: 0,
                            categoryTotals: [:],
                            selectedDistrict: nil,
                            language: isHebrew ? "he" : "en",
                            isPaused: false,
                            timeOfDayOverride: 12,
                            onSelectDistrict: { _ in },
                            onBuildingSelected: { _ in }
                        )
                        .allowsHitTesting(false)
                        .accessibilityHidden(style != draft)
                        .offset(x: CGFloat(index - selectedIndex) * geometry.size.width * direction + mapDrag)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .updating($mapDrag) { value, state, _ in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            state = value.translation.width
                        }
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            let travel = value.predictedEndTranslation.width * direction
                            guard abs(travel) > geometry.size.width * 0.15 else { return }
                            let next = min(max(selectedIndex + (travel < 0 ? 1 : -1), 0), worlds.count - 1)
                            if next != selectedIndex {
                                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                                    draft = worlds[next]
                                }
                                Haptics.selection()
                            }
                        }
                )
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: draft)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: mapDrag == 0)
            }
            .frame(height: 250)
            .clipped()

            // ── Style Title and Context ──
            VStack(spacing: 6) {
                Text(draft.title(isHebrew: isHebrew))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.jetBlack)
                    .id(draft)
                    .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 5)))

                Text(isHebrew ? "החלק לבחירת סגנון" : "Swipe to choose a style")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.jetBlack.opacity(0.6))
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)

            // ── Native Page Dots ──
            HStack(spacing: 8) {
                ForEach(worlds) { style in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
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
            .padding(.top, 10)
            .padding(.bottom, 16)

            // ── Clean Description directly on canvas ──
            VStack(alignment: .leading, spacing: 6) {
                Text(isHebrew ? "רובע קטן. הצצה לעיר שלך." : "One district. A glimpse of your city.")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.jetBlack)

                Text(isHebrew
                    ? (isCurrentMonthTarget
                        ? "זה רובע האוכל, לדוגמה. אחרי הבחירה תתגלה העיר המלאה עבור החודש."
                        : "בחר את מראה העיר מראש. בתחילת החודש הבא העיר המלאה תיפתח בסגנון זה.")
                    : (isCurrentMonthTarget
                        ? "This is a sample of the food district. Confirming will set your full city style for this month."
                        : "Pre-select your city style. At the start of next month, your full city will reveal in this world."))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Color.jetBlack.opacity(0.7))
                    .lineSpacing(3)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)

            Spacer(minLength: 20)

            // Confirm Action Button
            Button {
                Haptics.impact(.medium)
                onConfirm(draft)
            } label: {
                Text(isHebrew ? "בחירת מפה" : "Confirm Map")
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
            .padding(.bottom, 28)
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
