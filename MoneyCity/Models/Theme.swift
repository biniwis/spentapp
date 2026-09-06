import SwiftUI

/// Global design system tokens and color palette art-directed for MoneyCity.
/// Clean, playful, modern, and distinctive — Vivid Royal Blue brand with soft pastel category accents.
public struct MoneyCityTheme {
    // ── Primary Brand & Base Palette ──
    public static let primaryBlue = Color(red: 37/255, green: 60/255, blue: 196/255)   // #253CC4 Vivid Royal Blue
    public static let deepNavy = Color(red: 17/255, green: 24/255, blue: 39/255)       // #111827 Crisp Charcoal Primary Text
    public static let background = Color(red: 248/255, green: 249/255, blue: 250/255)  // #F8F9FA Breathable Warm Off-White
    public static let cardSurface = Color.white                                         // #FFFFFF Pure White Cards
    public static let borderSubtle = Color(red: 229/255, green: 231/255, blue: 235/255)// #E5E7EB Soft Slate Border
    public static let borderHairline = Color(red: 243/255, green: 244/255, blue: 246/255) // #F3F4F6

    // ── Typography Colors ──
    public static let textPrimary = Color(red: 17/255, green: 24/255, blue: 39/255)    // #111827
    public static let textSecondary = Color(red: 107/255, green: 114/255, blue: 128/255) // #6B7280
    public static let textMuted = Color(red: 156/255, green: 163/255, blue: 175/255)   // #9CA3AF

    // ── Secondary / Category Palette ──
    public static let turquoise = Color(red: 53/255, green: 174/255, blue: 183/255)     // #35AEB7
    public static let turquoiseSoft = Color(red: 230/255, green: 247/255, blue: 248/255)// #E6F7F8

    public static let orange = Color(red: 244/255, green: 122/255, blue: 40/255)        // #F47A28
    public static let orangeSoft = Color(red: 254/255, green: 242/255, blue: 232/255)   // #FEF2E8

    public static let lavender = Color(red: 124/255, green: 114/255, blue: 255/255)     // #7C72FF
    public static let lavenderSoft = Color(red: 232/255, green: 229/255, blue: 255/255) // #E8E5FF

    public static let mint = Color(red: 16/255, green: 185/255, blue: 129/255)          // #10B981
    public static let mintSoft = Color(red: 221/255, green: 243/255, blue: 234/255)     // #DDF3EA

    public static let yellow = Color(red: 245/255, green: 158/255, blue: 11/255)        // #F59E0B
    public static let yellowSoft = Color(red: 255/255, green: 240/255, blue: 199/255)   // #FFF0C7

    public static let pink = Color(red: 236/255, green: 72/255, blue: 153/255)          // #EC4899
    public static let pinkSoft = Color(red: 249/255, green: 225/255, blue: 232/255)     // #F9E1E8

    // Legacy aliases redirected to the clean new palette
    public static let cherryRed = Color(red: 37/255, green: 60/255, blue: 196/255)     // Redirected to primary blue
    public static let bubblegumPink = lavender
    public static let sunflowerYellow = yellow
    public static let obsidianBlack = deepNavy
    public static let emeraldGreen = mint
    public static let oceanBlue = primaryBlue
}

public extension Color {
    // Brand Tokens
    static let primaryBlue = MoneyCityTheme.primaryBlue
    static let deepNavy = MoneyCityTheme.deepNavy
    static let appBackground = MoneyCityTheme.background
    static let cardBackground = MoneyCityTheme.cardSurface
    static let borderSubtle = MoneyCityTheme.borderSubtle
    static let textDark = MoneyCityTheme.textPrimary
    static let textMuted = MoneyCityTheme.textMuted
    static let textSecondary = MoneyCityTheme.textSecondary

    // Pastel Secondary Tokens
    static let themeTurquoise = MoneyCityTheme.turquoise
    static let themeTurquoiseSoft = MoneyCityTheme.turquoiseSoft
    static let themeOrange = MoneyCityTheme.orange
    static let themeOrangeSoft = MoneyCityTheme.orangeSoft
    static let accentOrange = MoneyCityTheme.orange
    static let backgroundElevated = MoneyCityTheme.cardSurface
    static let themeLavender = MoneyCityTheme.lavender
    static let themeLavenderSoft = MoneyCityTheme.lavenderSoft
    static let themeMint = MoneyCityTheme.mint
    static let themeMintSoft = MoneyCityTheme.mintSoft
    static let themeYellow = MoneyCityTheme.yellow
    static let themeYellowSoft = MoneyCityTheme.yellowSoft
    static let themePink = MoneyCityTheme.pink
    static let themePinkSoft = MoneyCityTheme.pinkSoft

    // Legacy aliases
    static let cherryRed = MoneyCityTheme.primaryBlue
    static let bubblegumPink = MoneyCityTheme.lavender
    static let sunflowerYellow = MoneyCityTheme.yellow
    static let obsidianBlack = MoneyCityTheme.deepNavy
    static let emeraldGreen = MoneyCityTheme.mint
    static let oceanBlue = MoneyCityTheme.primaryBlue

    // Slates
    static let slate100 = Color(red: 245/255, green: 247/255, blue: 250/255)
    static let slate200 = Color(red: 232/255, green: 237/255, blue: 245/255)
    static let slate300 = Color(red: 203/255, green: 213/255, blue: 225/255)
    static let slate400 = Color(red: 148/255, green: 163/255, blue: 184/255)
    static let slate500 = Color(red: 100/255, green: 116/255, blue: 139/255)
    static let slate700 = Color(red: 51/255, green: 65/255, blue: 85/255)
    static let slate800 = Color(red: 30/255, green: 41/255, blue: 59/255)
    static let slate900 = Color(red: 16/255, green: 23/255, blue: 45/255)
    static let slate950 = Color(red: 10/255, green: 15/255, blue: 30/255)

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
    static let edgeNeutral = Color(red: 236/255, green: 240/255, blue: 246/255)
    static let edgeTurquoise = Color(red: 200/255, green: 235/255, blue: 237/255)
    static let edgeLavender = Color(red: 215/255, green: 212/255, blue: 255/255)
    static let edgeMint = Color(red: 195/255, green: 238/255, blue: 222/255)
    static let edgeOrange = Color(red: 254/255, green: 228/255, blue: 208/255)
    static let edgeYellow = Color(red: 254/255, green: 235/255, blue: 185/255)
    static let edgePink = Color(red: 250/255, green: 215/255, blue: 226/255)
    static let edgeBlue = Color(red: 37/255, green: 60/255, blue: 196/255)
    static let edgeNavy = Color(red: 15/255, green: 23/255, blue: 42/255)

    // ── Ambient Soft Shadow ──────────────────────────────────────────
    static let floatShadow = Color(red: 15/255, green: 23/255, blue: 42/255).opacity(0.08)
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
        case .plain:    return MoneyCityTheme.cardSurface
        case .food:     return MoneyCityTheme.turquoiseSoft
        case .shopping: return MoneyCityTheme.lavenderSoft
        case .housing:  return MoneyCityTheme.yellowSoft
        case .savings:  return MoneyCityTheme.mintSoft
        case .habit:    return MoneyCityTheme.orangeSoft
        case .night:    return MoneyCityTheme.deepNavy
        }
    }

    public var edge: Color {
        switch self {
        case .plain:    return MoneyCityTheme.edgeNeutral
        case .food:     return MoneyCityTheme.edgeTurquoise
        case .shopping: return MoneyCityTheme.edgeLavender
        case .housing:  return MoneyCityTheme.edgeYellow
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
        case .plain:    return MoneyCityTheme.primaryBlue
        case .food:     return MoneyCityTheme.turquoise
        case .shopping: return MoneyCityTheme.lavender
        case .housing:  return MoneyCityTheme.yellow
        case .savings:  return MoneyCityTheme.mint
        case .habit:    return MoneyCityTheme.orange
        case .night:    return MoneyCityTheme.mint
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
