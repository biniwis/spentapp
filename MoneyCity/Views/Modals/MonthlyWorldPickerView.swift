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

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(isHebrew ? (isCurrentMonthTarget ? "מפת החודש" : "מפת החודש הבא") : (isCurrentMonthTarget ? "This Month's Map" : "Next Month's Map"))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(MoneyCityTheme.jetBlack)

                Text(headerSubtitleText)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(MoneyCityTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 28)
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
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(MoneyCityTheme.borderSubtle, lineWidth: 1)
                )

                // Quiet minimalist badge on the preview
                HStack(spacing: 6) {
                    Circle()
                        .fill(MoneyCityTheme.luckyGreen)
                        .frame(width: 6, height: 6)
                    Text(draft.title(isHebrew: isHebrew))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(MoneyCityTheme.jetBlack)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.92))
                .clipShape(Capsule())
                .shadow(color: Color.deepNavy.opacity(0.04), radius: 6, y: 2)
                .padding(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            // ── Minimalist Inset Grouped World List ──
            VStack(spacing: 0) {
                ForEach(Array(worlds.enumerated()), id: \.element.id) { index, style in
                    let isSelected = (style == draft)
                    let currentMonthSelection = CityMapSelection.resolvedStyle(for: Date())
                    let nextMonthSelection = CityMapSelection.selectedStyle(for: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date())
                    let isCurrentMonthActive = (style == currentMonthSelection)
                    let isNextMonthChosen = (style == nextMonthSelection)

                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.82)) {
                            draft = style
                        }
                        Haptics.selection()
                    } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text(style.title(isHebrew: isHebrew))
                                        .font(.system(size: 15, weight: isSelected ? .bold : .semibold, design: .rounded))
                                        .foregroundColor(MoneyCityTheme.jetBlack)

                                    if isCurrentMonthActive {
                                        Text(isHebrew ? "החודש" : "Current")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(MoneyCityTheme.violetBlue)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(MoneyCityTheme.babyBlue.opacity(0.55))
                                            .clipShape(Capsule())
                                    }

                                    if isNextMonthChosen && !isCurrentMonthTarget {
                                        Text(isHebrew ? "נבחר" : "Selected")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(MoneyCityTheme.luckyGreen)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(MoneyCityTheme.luckyGreen.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(style.subtitle(isHebrew: isHebrew))
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(MoneyCityTheme.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            // Native checkmark indicator
                            ZStack {
                                Circle()
                                    .stroke(isSelected ? MoneyCityTheme.jetBlack : MoneyCityTheme.borderSubtle, lineWidth: 1.5)
                                    .frame(width: 20, height: 20)

                                if isSelected {
                                    Circle()
                                        .fill(MoneyCityTheme.jetBlack)
                                        .frame(width: 10, height: 10)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < worlds.count - 1 {
                        Divider()
                            .background(MoneyCityTheme.borderHairline)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MoneyCityTheme.borderSubtle, lineWidth: 1)
            )
            .shadow(color: Color.deepNavy.opacity(0.03), radius: 8, y: 2)
            .padding(.horizontal, 24)

            Spacer(minLength: 20)

            // Confirm Action Button
            Button {
                Haptics.impact(.medium)
                onConfirm(draft)
            } label: {
                Text(isHebrew ? "בחירת מפה" : "Confirm Map")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(MoneyCityTheme.jetBlack)
                    )
            }
            .buttonStyle(.plain)
            .bouncyPress(scale: reduceMotion ? 1 : 0.98)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(red: 250/255, green: 250/255, blue: 248/255).ignoresSafeArea())
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
