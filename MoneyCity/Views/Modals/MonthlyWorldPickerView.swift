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

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(isHebrew ? "בחירת עולם לעיר" : "City World Selection")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(MoneyCityTheme.jetBlack)

                Text(isHebrew
                    ? (isCurrentMonthTarget ? "הגדרת סגנון העיר לחודש הנוכחי (\(targetMonthName))" : "הגדרת סגנון העיר מראש לחודש הבא (\(targetMonthName))")
                    : (isCurrentMonthTarget ? "Set city style for current month (\(targetMonthName))" : "Pre-select city style for next month (\(targetMonthName))"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(MoneyCityTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // ── Fixed Top Preview: Shopping District Sample ──
            ZStack(alignment: .bottomLeading) {
                ThreeDioramaView(
                    mapStyle: draft,
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
                .id(draft.rawValue)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(MoneyCityTheme.borderSubtle, lineWidth: 1)
                )

                // Active style badge on the diorama preview
                HStack(spacing: 6) {
                    Circle()
                        .fill(MoneyCityTheme.luckyGreen)
                        .frame(width: 7, height: 7)
                    Text(draft.title(isHebrew: isHebrew))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(MoneyCityTheme.jetBlack)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.92))
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
                .padding(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // ── Worlds Selection List (Clean, Non-scrolling List) ──
            VStack(spacing: 8) {
                ForEach(worlds) { style in
                    let isSelected = (style == draft)
                    let currentMonthSelection = CityMapSelection.resolvedStyle(for: Date())
                    let nextMonthSelection = CityMapSelection.selectedStyle(for: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date())
                    let isCurrentMonthActive = (style == currentMonthSelection)
                    let isNextMonthChosen = (style == nextMonthSelection)

                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
                            draft = style
                        }
                        Haptics.selection()
                    } label: {
                        HStack(spacing: 12) {
                            // Selector indicator
                            ZStack {
                                Circle()
                                    .stroke(isSelected ? MoneyCityTheme.jetBlack : MoneyCityTheme.borderSubtle, lineWidth: 2)
                                    .frame(width: 22, height: 22)
                                if isSelected {
                                    Circle()
                                        .fill(MoneyCityTheme.jetBlack)
                                        .frame(width: 12, height: 12)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(style.title(isHebrew: isHebrew))
                                        .font(.system(size: 15, weight: isSelected ? .bold : .semibold, design: .rounded))
                                        .foregroundColor(MoneyCityTheme.jetBlack)

                                    if isCurrentMonthActive {
                                        Text(isHebrew ? "החודש" : "Current")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(MoneyCityTheme.violetBlue)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(MoneyCityTheme.babyBlue.opacity(0.6))
                                            .clipShape(Capsule())
                                    }

                                    if isNextMonthChosen && !isCurrentMonthTarget {
                                        Text(isHebrew ? "נבחר לחודש הבא" : "Next Month")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(MoneyCityTheme.luckyGreen)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(MoneyCityTheme.luckyGreen.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(style.subtitle(isHebrew: isHebrew))
                                    .font(.system(size: 11.5, weight: .regular, design: .rounded))
                                    .foregroundColor(MoneyCityTheme.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isSelected ? MoneyCityTheme.warmCream.opacity(0.6) : Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isSelected ? MoneyCityTheme.jetBlack : MoneyCityTheme.borderSubtle, lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 16)

            // Confirm Action Button
            Button {
                Haptics.impact(.medium)
                onConfirm(draft)
            } label: {
                Text(isHebrew ? "אישור ובחירת עולם" : "Confirm City World")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(MoneyCityTheme.jetBlack)
                    )
            }
            .buttonStyle(.plain)
            .bouncyPress(scale: reduceMotion ? 1 : 0.97)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.white.ignoresSafeArea())
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
