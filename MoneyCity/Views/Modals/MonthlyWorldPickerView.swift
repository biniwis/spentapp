import SwiftUI

/// Map style selection sheet presented from Profile.
/// Features a top shopping street district sample (`isDistrictSample: true`) reflecting
/// the selected draft, followed by individual world selection cards with immediate selection on tap.
public struct MonthlyWorldPickerView: View {
    @Binding public var draft: CityMapStyle
    public let isHebrew: Bool
    public var onClose: (() -> Void)?
    public let onSelect: (CityMapStyle) -> Void

    public init(
        draft: Binding<CityMapStyle>,
        isHebrew: Bool,
        onClose: (() -> Void)? = nil,
        onSelect: @escaping (CityMapStyle) -> Void
    ) {
        self._draft = draft
        self.isHebrew = isHebrew
        self.onClose = onClose
        self.onSelect = onSelect
    }

    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Allowed worlds in the picker (excludes .future)
    private let worlds = CityMapSelection.pickerWorlds

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
                    Text(isHebrew ? "סגנון המפה" : "Map Style")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(MoneyCityTheme.jetBlack)

                    Text(isHebrew ? "בחר איך העיר שלך תיראה" : "Choose how your city looks")
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

                    // ── Primary Map: Classic City (Hero Card) ──
                    let isClassicSelected = (draft == .urban)

                    Button {
                        Haptics.selection()
                        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)) {
                            draft = .urban
                        }
                        onSelect(.urban)
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(styleBgColor(.urban))
                                    .frame(width: 44, height: 44)
                                MoneyIcon(styleIcon(.urban), size: 22, color: styleTintColor(.urban))
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text(CityMapStyle.urban.title(isHebrew: isHebrew))
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(MoneyCityTheme.jetBlack)

                                    Text(isHebrew ? "המפה הראשית" : "Primary")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(MoneyCityTheme.violetBlue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2.5)
                                        .background(MoneyCityTheme.babyBlue.opacity(0.65))
                                        .clipShape(Capsule())
                                }

                                Text(styleShortSubtitle(.urban))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(MoneyCityTheme.textSecondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            if isClassicSelected {
                                ZStack {
                                    Circle()
                                        .fill(MoneyCityTheme.jetBlack)
                                        .frame(width: 22, height: 22)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(isClassicSelected ? MoneyCityTheme.jetBlack : Color.clear, lineWidth: isClassicSelected ? 1.5 : 0)
                        )
                        .shadow(color: Color.black.opacity(isClassicSelected ? 0.05 : 0.025), radius: 8, y: 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .bouncyPress(scale: reduceMotion ? 1 : 0.98)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(isClassicSelected ? [.isButton, .isSelected] : [.isButton])

                    // ── Section Title: Additional Options ──
                    HStack {
                        Text(isHebrew ? "עולמות נוספים" : "Alternative Worlds")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundColor(MoneyCityTheme.jetBlack.opacity(0.65))
                        Spacer()
                    }
                    .padding(.top, 4)
                    .padding(.horizontal, 4)

                    // ── 3 Alternative Worlds Grid ──
                    let alternativeWorlds: [CityMapStyle] = [.medieval, .arctic, .israel]

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ], spacing: 10) {
                        ForEach(alternativeWorlds) { style in
                            let isSelected = (style == draft)

                            Button {
                                Haptics.selection()
                                withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)) {
                                    draft = style
                                }
                                onSelect(style)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    // Top row: Icon on leading, Checkmark on trailing when selected
                                    HStack(alignment: .center) {
                                        ZStack {
                                            Circle()
                                                .fill(styleBgColor(style))
                                                .frame(width: 34, height: 34)
                                            MoneyIcon(styleIcon(style), size: 18, color: styleTintColor(style))
                                        }

                                        Spacer()

                                        if isSelected {
                                            ZStack {
                                                Circle()
                                                    .fill(MoneyCityTheme.jetBlack)
                                                    .frame(width: 18, height: 18)
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }

                                    // Style title and short descriptive note
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(style.title(isHebrew: isHebrew))
                                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                            .foregroundColor(MoneyCityTheme.jetBlack)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.85)

                                        Text(styleShortSubtitle(style))
                                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                            .foregroundColor(MoneyCityTheme.textSecondary)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(minHeight: 112)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                .padding(.bottom, 24)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .environment(\.layoutDirection, isHebrew ? .rightToLeft : .leftToRight)
    }

    private func styleShortSubtitle(_ style: CityMapStyle) -> String {
        switch style {
        case .urban:
            return isHebrew ? "שדרות נעימות, בתי קפה ואדריכלות עיר מודרנית" : "Charming avenues, cafes & modern architecture"
        case .medieval:
            return isHebrew ? "טירות אבן ושווקים" : "Stone castles & markets"
        case .arctic:
            return isHebrew ? "איגלו, שלג וזוהר קוטב" : "Igloos, snow & polar lights"
        case .israel:
            return isHebrew ? "באוהאוס ועצי דקל" : "Bauhaus & warm palms"
        case .future:
            return isHebrew ? "מגדלים מרחפים וניאון" : "Floating towers & neon"
        }
    }
}

#Preview("Map Style Picker") {
    MonthlyWorldPickerView(
        draft: .constant(.urban),
        isHebrew: true,
        onClose: {},
        onSelect: { _ in }
    )
    .environmentObject(LocalizationManager())
}
