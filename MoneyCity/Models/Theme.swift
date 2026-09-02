import SwiftUI

/// Global design system tokens and color palette art-directed for MoneyCity.
/// Clean, playful, modern, and distinctive — Vivid Royal Blue brand with soft pastel category accents.
public struct MoneyCityTheme {
    // ── Primary Brand & Base Palette ──
    public static let primaryBlue = Color(red: 37/255, green: 60/255, blue: 196/255)   // #253CC4 Vivid Royal Blue
    public static let deepNavy = Color(red: 16/255, green: 23/255, blue: 45/255)       // #10172D Deep Navy Text
    public static let background = Color(red: 245/255, green: 247/255, blue: 250/255)  // #F5F7FA Cool Light Gray-Blue
    public static let cardSurface = Color.white                                         // #FFFFFF Pure White Cards
    public static let borderSubtle = Color(red: 232/255, green: 237/255, blue: 245/255)// #E8EDF5 Soft Slate Border
    public static let borderHairline = Color(red: 226/255, green: 232/255, blue: 240/255) // #E2E8F0

    // ── Typography Colors ──
    public static let textPrimary = Color(red: 16/255, green: 23/255, blue: 45/255)    // #10172D
    public static let textSecondary = Color(red: 100/255, green: 116/255, blue: 139/255) // #64748B
    public static let textMuted = Color(red: 148/255, green: 163/255, blue: 184/255)   // #94A3B8

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

    // ── Radii ────────────────────────────────────────────────────────
    /// Chips, small controls, inline badges.
    static let radiusSmall: CGFloat = 13
    /// The default for anything card-shaped.
    static let radiusCard: CGFloat = 22
    /// Hero surfaces and sheets — the largest thing on a screen.
    static let radiusHero: CGFloat = 26

    /// Height of the solid lip under a surface.
    static let edgeThickness: CGFloat = 3

    // ── Edge shades ──────────────────────────────────────────────────
    // Each is a deeper version of the surface above it, not a grey. A grey lip
    // under a mint card reads as a shadow that got stuck; a deeper mint reads
    // as the same object seen from the side.
    static let edgeNeutral = Color(red: 223/255, green: 229/255, blue: 241/255)   // #DFE5F1
    static let edgeTurquoise = Color(red: 191/255, green: 230/255, blue: 232/255) // #BFE6E8
    static let edgeLavender = Color(red: 207/255, green: 202/255, blue: 255/255)  // #CFCAFF
    static let edgeMint = Color(red: 182/255, green: 230/255, blue: 211/255)      // #B6E6D3
    static let edgeOrange = Color(red: 247/255, green: 213/255, blue: 187/255)    // #F7D5BB
    static let edgeYellow = Color(red: 245/255, green: 224/255, blue: 160/255)    // #F5E0A0
    static let edgePink = Color(red: 240/255, green: 200/255, blue: 214/255)      // #F0C8D6
    static let edgeBlue = Color(red: 26/255, green: 43/255, blue: 146/255)        // #1A2B92
    static let edgeNavy = Color(red: 6/255, green: 10/255, blue: 22/255)          // #060A16

    // ── The one blur that is allowed ─────────────────────────────────
    // For the tab bar and the add button. Nothing else floats.
    static let floatShadow = Color(red: 16/255, green: 23/255, blue: 45/255).opacity(0.10)
    static let floatShadowRadius: CGFloat = 20
    static let floatShadowY: CGFloat = 8
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

    /// The hairline. A tinted surface borrows its own edge colour rather than a
    /// neutral line, so the outline never looks like a separate object.
    public var line: Color {
        switch self {
        case .plain:  return MoneyCityTheme.borderSubtle
        case .night:  return Color.clear
        default:      return edge
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

    /// Where a spending category lives in the city, so a card about groceries
    /// and the food district are never two different greens.
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

/// A surface with a solid lip instead of a blurred shadow.
///
/// The lip is drawn by letting the fill stop `edgeThickness` short of the
/// bottom, revealing the deeper shape behind it — the same trick a physical
/// key uses, and the reason a tap feels like it presses something.
public struct CityCardModifier: ViewModifier {
    let surface: CitySurface
    let radius: CGFloat

    public func body(content: Content) -> some View {
        content
            // The content sits in the fill, never over the lip.
            .padding(.bottom, MoneyCityTheme.edgeThickness)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(surface.edge)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(surface.fill)
                        .overlay(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .strokeBorder(surface.line, lineWidth: 1)
                        )
                        .padding(.bottom, MoneyCityTheme.edgeThickness)
                }
            )
    }
}

public extension View {
    /// The app's card surface. Use this instead of hand-rolling a background,
    /// a stroke and a shadow — that is how twenty radii happened.
    func cityCard(_ surface: CitySurface = .plain, radius: CGFloat = MoneyCityTheme.radiusCard) -> some View {
        modifier(CityCardModifier(surface: surface, radius: radius))
    }

    /// The only blurred elevation in the app: for the tab bar and the add
    /// button, which really do float over the content.
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
