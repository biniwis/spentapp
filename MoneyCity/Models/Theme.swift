import SwiftUI

/// Global design system tokens and color palette art-directed for MoneyCity.
/// SPENT V2 Design System tokens and color palette art-directed for MoneyCity.
/// Calm white interface, strong black typography, controlled expressive moments.
public struct MoneyCityTheme {
    // ── SPENT Canonical Palette (V2) ──
    public static let white       = Color(red: 255/255, green: 255/255, blue: 255/255) // #FFFFFF Pure White
    public static let warmCream   = Color(red: 255/255, green: 242/255, blue: 230/255) // #FFF2E6 Warm Cream (Supporting)
    public static let neonLime    = Color(red: 209/255, green: 209/255, blue: 117/255) // #D1D175 Neon Lime (Special Accent)
    public static let babyBlue    = Color(red: 215/255, green: 231/255, blue: 255/255) // #D7E7FF Baby Blue (Soft Supporting)
    public static let jetBlack    = Color(red: 0/255, green: 0/255, blue: 0/255)       // #000000 Jet Black (Typography & Outlines)
    public static let orangeRed   = Color(red: 255/255, green: 100/255, blue: 70/255)  // #FF6446 Orange Red (Strong Warm Accent)
    public static let luckyGreen  = Color(red: 45/255, green: 158/255, blue: 101/255)  // #2D9E65 Lucky Green (Primary Brand & Action)
    public static let violetBlue  = Color(red: 86/255, green: 83/255, blue: 232/255)   // #5653E8 Violet Blue (Secondary Brand & Editorial)

    // ── Curated Category Palette (Tonally unified for data distinction) ──
    public struct CategoryPalette {
        public static let food           = MoneyCityTheme.orangeRed                            // Canonical Orange Red
        public static let shopping       = MoneyCityTheme.violetBlue                           // Canonical Violet Blue
        public static let transport      = Color(red: 63/255,  green: 134/255, blue: 199/255) // #3F86C7 City Blue
        public static let housing        = Color(red: 201/255, green: 145/255, blue: 63/255)  // #C9913F Warm Ochre
        public static let entertainment  = Color(red: 122/255, green: 95/255,  blue: 199/255) // #7A5FC7 Soft Purple
        public static let health         = Color(red: 216/255, green: 95/255,  blue: 115/255) // #D85F73 Dusty Coral
        public static let subscriptions  = Color(red: 102/255, green: 121/255, blue: 200/255) // #6679C8 Periwinkle
        public static let finance        = Color(red: 83/255,  green: 96/255,  blue: 107/255) // #53606B Graphite Blue
        public static let savings        = MoneyCityTheme.luckyGreen                           // Canonical Lucky Green
        public static let miscellaneous  = Color(red: 166/255, green: 169/255, blue: 86/255)  // #A6A956 Olive Lime
        public static let other          = Color(red: 146/255, green: 153/255, blue: 161/255) // #9299A1 Neutral Slate
    }

    // ── Semantic Design Tokens ──
    public static let appBackground   = white                                         // #FFFFFF Canvas
    public static let surfacePrimary  = white                                         // #FFFFFF Clean cards
    public static let surfaceWarm     = warmCream                                     // #FFF2E6 Supporting warm surface
    public static let surfaceSoft     = babyBlue                                      // #D7E7FF Soft information surface
    public static let brandPrimary    = luckyGreen                                    // #2D9E65 Primary Action / Brand
    public static let brandSecondary  = violetBlue                                    // #5653E8 Secondary Brand / Analytics
    public static let accentWarm      = orangeRed                                     // #FF6446 Warm Accent / Warning / Destructive
    public static let accentSpecial   = neonLime                                      // #D1D175 Rewards / Companions / Highlight
    public static let destructive     = orangeRed                                     // #FF6446

    // ── Typography & Neutral Tokens ──
    public static let textPrimary     = jetBlack                                      // #000000 Primary Text & Numbers
    public static let textSecondary   = jetBlack.opacity(0.62)                        // Readable medium contrast text
    public static let textMuted       = jetBlack.opacity(0.48)                        // Lower hierarchy labels & captions (elevated contrast)
    public static let borderSubtle    = jetBlack.opacity(0.08)                        // Quiet Apple HIG hairline borders
    public static let borderHairline  = jetBlack.opacity(0.05)                        // Ultra-subtle dividers
    public static let divider         = jetBlack.opacity(0.08)

    // ── Compatibility Aliases (Redirected to Canonical Palette) ──
    public static let background       = appBackground                                // White
    public static let cardSurface      = surfacePrimary                               // White
    public static let primaryBlue      = brandSecondary                               // Violet Blue #5653E8
    public static let deepNavy         = textPrimary                                  // Jet Black #000000
    public static let spentGreen       = brandPrimary                                 // Lucky Green #2D9E65
    public static let spentGreenSoft   = luckyGreen.opacity(0.12)
    public static let deleteRed        = destructive                                  // Orange Red #FF6446
    public static let deleteSoft       = orangeRed.opacity(0.12)

    public static let turquoise        = violetBlue
    public static let turquoiseSoft    = babyBlue.opacity(0.45)
    public static let orange           = accentWarm                                   // Orange Red #FF6446
    public static let orangeSoft       = warmCream
    public static let lavender         = violetBlue
    public static let lavenderSoft     = babyBlue
    public static let mint             = luckyGreen
    public static let mintSoft         = luckyGreen.opacity(0.12)
    public static let yellow           = neonLime
    public static let yellowSoft       = warmCream
    public static let pink             = violetBlue
    public static let pinkSoft         = warmCream

    // Legacy aliases
    public static let cherryRed        = brandSecondary
    public static let bubblegumPink    = brandSecondary
    public static let sunflowerYellow  = neonLime
    public static let obsidianBlack    = textPrimary
    public static let emeraldGreen     = luckyGreen
    public static let oceanBlue        = brandSecondary
}

public extension Color {
    // Canonical V2 Primitives
    static let spentWhite = MoneyCityTheme.white
    static let warmCream = MoneyCityTheme.warmCream
    static let neonLime = MoneyCityTheme.neonLime
    static let babyBlue = MoneyCityTheme.babyBlue
    static let jetBlack = MoneyCityTheme.jetBlack
    static let orangeRed = MoneyCityTheme.orangeRed
    static let luckyGreen = MoneyCityTheme.luckyGreen
    static let violetBlue = MoneyCityTheme.violetBlue

    // Semantic Design Tokens
    static let appBackground = MoneyCityTheme.appBackground
    static let cardBackground = MoneyCityTheme.surfacePrimary
    static let surfaceWarm = MoneyCityTheme.surfaceWarm
    static let surfaceSoft = MoneyCityTheme.surfaceSoft
    static let brandPrimary = MoneyCityTheme.brandPrimary
    static let brandSecondary = MoneyCityTheme.brandSecondary
    static let accentWarm = MoneyCityTheme.accentWarm
    static let accentSpecial = MoneyCityTheme.accentSpecial
    static let textDark = MoneyCityTheme.textPrimary
    static let textPrimary = MoneyCityTheme.textPrimary
    static let textSecondary = MoneyCityTheme.textSecondary
    static let textMuted = MoneyCityTheme.textMuted
    static let borderSubtle = MoneyCityTheme.borderSubtle
    static let borderHairline = MoneyCityTheme.borderHairline
    static let destructive = MoneyCityTheme.destructive
    static let deleteRed = MoneyCityTheme.deleteRed
    static let deleteSoft = MoneyCityTheme.deleteSoft

    // Backward-Compatibility Aliases
    static let primaryBlue = MoneyCityTheme.primaryBlue
    static let deepNavy = MoneyCityTheme.deepNavy
    static let backgroundElevated = MoneyCityTheme.cardSurface
    static let themeTurquoise = MoneyCityTheme.turquoise
    static let themeTurquoiseSoft = MoneyCityTheme.turquoiseSoft
    static let themeOrange = MoneyCityTheme.orange
    static let themeOrangeSoft = MoneyCityTheme.orangeSoft
    static let accentOrange = MoneyCityTheme.orange
    static let themeLavender = MoneyCityTheme.lavender
    static let themeLavenderSoft = MoneyCityTheme.lavenderSoft
    static let themeMint = MoneyCityTheme.mint
    static let themeMintSoft = MoneyCityTheme.mintSoft
    static let mint = MoneyCityTheme.mint
    static let mintSoft = MoneyCityTheme.mintSoft
    static let spentGreen = MoneyCityTheme.spentGreen
    static let spentGreenSoft = MoneyCityTheme.spentGreenSoft
    static let themeYellow = MoneyCityTheme.yellow
    static let themeYellowSoft = MoneyCityTheme.yellowSoft
    static let themePink = MoneyCityTheme.pink
    static let themePinkSoft = MoneyCityTheme.pinkSoft

    static let cherryRed = MoneyCityTheme.cherryRed
    static let bubblegumPink = MoneyCityTheme.bubblegumPink
    static let sunflowerYellow = MoneyCityTheme.sunflowerYellow
    static let obsidianBlack = MoneyCityTheme.obsidianBlack
    static let emeraldGreen = MoneyCityTheme.emeraldGreen
    static let oceanBlue = MoneyCityTheme.oceanBlue

    // Slates (pure neutral Jet Black hierarchy)
    static let slate100 = Color.white
    static let slate200 = MoneyCityTheme.jetBlack.opacity(0.04)
    static let slate300 = MoneyCityTheme.jetBlack.opacity(0.08)
    static let slate400 = MoneyCityTheme.jetBlack.opacity(0.25)
    static let slate500 = MoneyCityTheme.jetBlack.opacity(0.48)
    static let slate700 = MoneyCityTheme.jetBlack.opacity(0.70)
    static let slate800 = MoneyCityTheme.jetBlack.opacity(0.85)
    static let slate900 = MoneyCityTheme.jetBlack.opacity(0.92)
    static let slate950 = MoneyCityTheme.jetBlack

    /// Initialize a Color from a hexadecimal string (e.g., "#9333EA", "9333EA", "#FFF")
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// ─── Global App Font: Rounded SF Pro (matches the ₪ spending amount style) ───

public extension Font {
    /// The app's standard rounded font — friendly, modern, and human art-directed.
    static func appFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// ════════════════════════════════════════════════════════════════════
//  SURFACE SYSTEM
// ════════════════════════════════════════════════════════════════════
//
//  The screens had drifted into twenty distinct corner radii and fifty-one
//  separate shadows, each decided on its own. That is what made a colourful,
//  playful app read as generated rather than designed: every element looked
//  like a one-off. The fix is not less colour — this is a game about a city,
//  the colour is the point — it is that colour and depth now follow rules.
//
//  Three rules:
//
//  1. Depth is a solid lip, not a blur. A card sits on a 3pt band of a deeper
//     shade of itself, the way a physical key sits on its own edge. Blur is
//     reserved for the two things that genuinely float above the page — the
//     tab bar and the add button.
//  2. A tint means something. A surface is coloured because it belongs to a
//     district of the city, never for variety. Anything that belongs to no
//     district stays white, which is what lets the coloured ones read.
//  3. Three radii, and no others.

public extension MoneyCityTheme {

    /// Chips, small controls, inline badges.
    static let radiusSmall: CGFloat = 12
    /// The default for anything card-shaped.
    static let radiusCard: CGFloat = 20
    /// Hero surfaces and sheets — the largest thing on a screen.
    static let radiusHero: CGFloat = 24

    /// Edge thickness set to 0 for flat modern Apple HIG surfaces
    static let edgeThickness: CGFloat = 0

    // ── Edge shades ──────────────────────────────────────────────────
    static let edgeNeutral = MoneyCityTheme.borderSubtle
    static let edgeTurquoise = MoneyCityTheme.babyBlue.opacity(0.35)
    static let edgeLavender = MoneyCityTheme.violetBlue.opacity(0.18)
    static let edgeMint = MoneyCityTheme.luckyGreen.opacity(0.20)
    static let edgeOrange = MoneyCityTheme.orangeRed.opacity(0.20)
    static let edgeYellow = MoneyCityTheme.neonLime.opacity(0.25)
    static let edgePink = MoneyCityTheme.violetBlue.opacity(0.18)
    static let edgeBlue = MoneyCityTheme.violetBlue
    static let edgeNavy = MoneyCityTheme.jetBlack

    // ── Ambient Soft Shadow ──────────────────────────────────────────
    static let floatShadow = Color.black.opacity(0.06)
    static let floatShadowRadius: CGFloat = 16
    static let floatShadowY: CGFloat = 6
}

/// What a surface is *about*, which is the only reason it may be coloured.
public enum CitySurface: Equatable {
    /// Belongs to no district. White. Most surfaces are this.
    case plain
    case food
    case shopping
    case housing
    case savings
    /// A behavioural streak or habit.
    case habit
    /// The one dark surface on a screen.
    case night

    public var fill: Color {
        switch self {
        case .plain:    return MoneyCityTheme.surfacePrimary
        case .food:     return MoneyCityTheme.surfaceWarm
        case .shopping: return MoneyCityTheme.surfaceSoft
        case .housing:  return MoneyCityTheme.surfaceWarm
        case .savings:  return MoneyCityTheme.luckyGreen.opacity(0.12)
        case .habit:    return MoneyCityTheme.surfaceWarm
        case .night:    return MoneyCityTheme.jetBlack
        }
    }

    public var edge: Color {
        switch self {
        case .plain:    return MoneyCityTheme.edgeNeutral
        case .food:     return MoneyCityTheme.edgeOrange
        case .shopping: return MoneyCityTheme.edgeLavender
        case .housing:  return MoneyCityTheme.edgeOrange
        case .savings:  return MoneyCityTheme.edgeMint
        case .habit:    return MoneyCityTheme.edgeOrange
        case .night:    return MoneyCityTheme.edgeNavy
        }
    }

    /// The hairline. A clean subtle stroke for crisp Apple HIG contrast.
    public var line: Color {
        switch self {
        case .plain:  return MoneyCityTheme.borderSubtle
        case .night:  return Color.clear
        default:      return edge.opacity(0.6)
        }
    }

    /// The accent used for a glyph or a value sitting on this surface.
    public var accent: Color {
        switch self {
        case .plain:    return MoneyCityTheme.brandSecondary
        case .food:     return MoneyCityTheme.accentWarm
        case .shopping: return MoneyCityTheme.brandSecondary
        case .housing:  return MoneyCityTheme.accentWarm
        case .savings:  return MoneyCityTheme.brandPrimary
        case .habit:    return MoneyCityTheme.accentWarm
        case .night:    return MoneyCityTheme.brandPrimary
        }
    }

    public static func forCategory(_ category: SpendingCategory) -> CitySurface {
        switch category.canonical {
        case .food:      return .food
        case .shopping:  return .shopping
        case .housing:   return .housing
        case .savings:   return .savings
        default:         return .plain
        }
    }
}

/// Clean Apple HIG card surface with subtle hairline and soft ambient shadow
public struct CityCardModifier: ViewModifier {
    let surface: CitySurface
    let radius: CGFloat

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(surface.fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(surface.line, lineWidth: 1)
                    )
                    .shadow(
                        color: surface == .night ? Color.black.opacity(0.18) : Color.black.opacity(0.035),
                        radius: surface == .night ? 14 : 10,
                        x: 0,
                        y: 3
                    )
            )
    }
}

public extension View {
    /// The app's card surface. Clean Apple HIG card with continuous corners, hairline border, and soft shadow.
    func cityCard(_ surface: CitySurface = .plain, radius: CGFloat = MoneyCityTheme.radiusCard) -> some View {
        modifier(CityCardModifier(surface: surface, radius: radius))
    }

    /// Blurred elevation for floating components like tab bar and buttons.
    func cityFloat() -> some View {
        shadow(
            color: MoneyCityTheme.floatShadow,
            radius: MoneyCityTheme.floatShadowRadius,
            y: MoneyCityTheme.floatShadowY
        )
    }
}

/// Applies the app-wide rounded SF Pro font as the default for all SwiftUI text.
struct RoundedFontEnvironment: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.font, .system(.body, design: .rounded))
    }
}

public extension View {
    /// Apply the MoneyCityApp global rounded font as the environment default.
    func moneyCityFont() -> some View {
        self.modifier(RoundedFontEnvironment())
    }
}

/// Fluid, tactile physical button depression on touch-down with spring rebound
public struct BouncyScaleButtonStyle: ButtonStyle {
    public var scale: CGFloat = 0.94
    public var opacity: CGFloat = 0.92

    public init(scale: CGFloat = 0.94, opacity: CGFloat = 0.92) {
        self.scale = scale
        self.opacity = opacity
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? opacity : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

public extension View {
    /// Apply a playful, physical bouncy scale on press with spring response.
    func bouncyPress(scale: CGFloat = 0.94) -> some View {
        self.buttonStyle(BouncyScaleButtonStyle(scale: scale))
    }
}
