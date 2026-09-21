import SwiftUI

/// Monthly world selection sheet presented at the start of a new month or from Profile.
/// Features a top shopping street district sample (`isDistrictSample: true`) reflecting
/// the selected draft, followed by individual world selection cards with clear hierarchy and no dividers.
public struct MonthlyWorldPickerView: View {
    /// The month this picker is selecting a world for.
    public let targetMonth: Date
    @Binding public var draft: CityMapStyle
    public let isHebrew: Bool
    public var onClose: (() -> Void)?
    public let onConfirm: (CityMapStyle) -> Void

    public init(
        targetMonth: Date,
        draft: Binding<CityMapStyle>,
        isHebrew: Bool,
        onClose: (() -> Void)? = nil,
        onConfirm: @escaping (CityMapStyle) -> Void
    ) {
        self.targetMonth = targetMonth
        self._draft = draft
        self.isHebrew = isHebrew
        self.onClose = onClose
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
                ? "בחר את מראה העיר עבור החודש הקרוב"
                : "בחר את מראה העיר עבור החודש הבא"
        } else {
            return isCurrentMonthTarget
                ? "Choose your city style for the upcoming month"
                : "Choose your city style for next month"
        }
    }

    private func styleIcon(_ style: CityMapStyle) -> MoneyIconType {
        switch style {
        case .urban: return .citySkyline
        case .medieval: return .flag
        case .arctic: return .snowflake
        case .israel: return .sun
        case .future: return .lightning
        }
    }

    private func styleTintColor(_ style: CityMapStyle) -> Color {
        switch style {
        case .urban: return MoneyCityTheme.violetBlue
        case .medieval: return Color(red: 165/255, green: 105/255, blue: 38/255)
        case .arctic: return Color(red: 35/255, green: 140/255, blue: 215/255)
        case .israel: return MoneyCityTheme.orangeRed
        case .future: return MoneyCityTheme.neonLime
        }
    }

    private func styleBgColor(_ style: CityMapStyle) -> Color {
        switch style {
        case .urban: return MoneyCityTheme.babyBlue.opacity(0.55)
        case .medieval: return MoneyCityTheme.warmCream
        case .arctic: return Color(red: 228/255, green: 244/255, blue: 255/255)
        case .israel: return Color(red: 255/255, green: 242/255, blue: 228/255)
        case .future: return MoneyCityTheme.babyBlue.opacity(0.3)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // ── Header ──
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isHebrew
                         ? (isCurrentMonthTarget ? "מפת החודש" : "מפת החודש הבא")
                         : (isCurrentMonthTarget ? "This Month's Map" : "Next Month's Map"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(MoneyCityTheme.jetBlack)

                    Text(headerSubtitleText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(MoneyCityTheme.textSecondary)
                }

                Spacer()

                if let onClose {
                    Button(action: {
                        Haptics.impact(.light)
                        onClose()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 36, height: 36)
                                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(MoneyCityTheme.jetBlack)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isHebrew ? "סגור" : "Close")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            // ── Scrollable Body: Diorama Preview + 2x2 Clean White Grid ──
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // ── Hero Preview: Shopping District Sample (Pre-loaded ZStack for zero blank flash) ──
                    ZStack(alignment: .bottomLeading) {
                        ZStack {
                            ForEach(worlds) { style in
                                ThreeDioramaView(
                                    mapStyle: style,
                                    isDistrictSample: true,
                                    totalSpent: 0,
                                    totalSavings: 0,
                                    categoryTotals: [:],
                                    selectedDistrict: nil,
                                    language: isHebrew ? "he" : "en",
                                    isPaused: draft != style,
                                    timeOfDayOverride: 12,
                                    onSelectDistrict: { _ in },
                                    onBuildingSelected: { _ in }
                                )
                                .allowsHitTesting(false)
                                .opacity(draft == style ? 1 : 0)
                                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: draft)
                            }
                        }
                        .frame(height: 180)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                        // Quiet floating pill on the preview
                        HStack(spacing: 6) {
                            Circle()
                                .fill(MoneyCityTheme.luckyGreen)
                                .frame(width: 6, height: 6)
                            Text(draft.title(isHebrew: isHebrew))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(MoneyCityTheme.jetBlack)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
                        .padding(12)
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)

                    // ── 2x2 Bento Tiles: Clean white squares matching ProfileView ──
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(worlds) { style in
                            let isSelected = (style == draft)
                            let currentMonthSelection = CityMapSelection.resolvedStyle(for: Date())
                            let nextMonthSelection = CityMapSelection.selectedStyle(for: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date())
                            let isCurrentMonthActive = (style == currentMonthSelection)
                            let isNextMonthChosen = (style == nextMonthSelection)

                            Button {
                                withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)) {
                                    draft = style
                                }
                                Haptics.selection()
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    // Top row: Icon on leading, Checkmark/Badge on trailing
                                    HStack(alignment: .center) {
                                        ZStack {
                                            Circle()
                                                .fill(styleBgColor(style))
                                                .frame(width: 38, height: 38)
                                            MoneyIcon(styleIcon(style), size: 20, color: styleTintColor(style))
                                        }

                                        Spacer()

                                        if isSelected {
                                            ZStack {
                                                Circle()
                                                    .fill(MoneyCityTheme.jetBlack)
                                                    .frame(width: 20, height: 20)
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        } else if isCurrentMonthActive {
                                            Text(isHebrew ? "החודש" : "Current")
                                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                                .foregroundColor(MoneyCityTheme.violetBlue)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 3)
                                                .background(MoneyCityTheme.babyBlue.opacity(0.55))
                                                .clipShape(Capsule())
                                        } else if isNextMonthChosen && !isCurrentMonthTarget {
                                            Text(isHebrew ? "נבחר" : "Selected")
                                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                                .foregroundColor(MoneyCityTheme.luckyGreen)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 3)
                                                .background(MoneyCityTheme.luckyGreen.opacity(0.14))
                                                .clipShape(Capsule())
                                        }
                                    }

                                    // Style title and short descriptive note
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(style.title(isHebrew: isHebrew))
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(MoneyCityTheme.jetBlack)
                                            .lineLimit(1)

                                        Text(styleShortSubtitle(style))
                                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                            .foregroundColor(MoneyCityTheme.textSecondary)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(minHeight: 110)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(isSelected ? MoneyCityTheme.jetBlack : Color.clear, lineWidth: isSelected ? 1.5 : 0)
                                )
                                .shadow(color: Color.black.opacity(isSelected ? 0.05 : 0.025), radius: 8, y: 2)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .bouncyPress(scale: reduceMotion ? 1 : 0.96)
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            // ── Confirm Action Button (Pinned at Bottom) ──
            Button {
                Haptics.impact(.medium)
                onConfirm(draft)
            } label: {
                Text(isHebrew ? "בחירת מפה" : "Confirm Map")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
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
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(Color.white.ignoresSafeArea())
        .environment(\.layoutDirection, isHebrew ? .rightToLeft : .leftToRight)
    }

    private func styleShortSubtitle(_ style: CityMapStyle) -> String {
        switch style {
        case .urban:
            return isHebrew ? "שדרות נעימות ובתי קפה" : "Charming avenues & cafes"
        case .medieval:
            return isHebrew ? "טירות אבן וסמטאות שוק" : "Stone castles & market alleys"
        case .arctic:
            return isHebrew ? "כיפות קרח ואורות קוטב" : "Ice domes & northern lights"
        case .israel:
            return isHebrew ? "בנייני באוהאוס ועצי דקל" : "Bauhaus & warm palms"
        case .future:
            return isHebrew ? "מגדלים מרחפים ואורות ניאון" : "Floating towers & neon"
        }
    }
}

#Preview("Monthly World Picker") {
    MonthlyWorldPickerView(
        targetMonth: Date(),
        draft: .constant(.urban),
        isHebrew: true,
        onClose: {},
        onConfirm: { _ in }
    )
    .environmentObject(LocalizationManager())
}
