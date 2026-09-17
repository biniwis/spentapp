import SwiftUI

// MARK: - AutomaticCaptureSetupGuide
//
// Single source of truth for the Automatic Capture setup walkthrough.
// Automatically routes:
//   • iOS 27+  → IOS27CaptureSetupGuideView (13 steps with genuine screenshots & tap indicators)
//   • iOS <=26 → LegacyCaptureSetupGuideView (9 steps)
//
// Used by:
//   • ApplePayGuideSheet  — presented as fullScreenCover from ProfileView
//   • OnboardingWizardView step 4B — embedded (skipIntro: true, no full-screen chrome)
//   • DesignLabView

// MARK: - Guide Variant
public enum AutomaticCaptureGuideVariant: String, CaseIterable, Identifiable {
    case automatic
    case ios27
    case legacy

    public var id: String { rawValue }

    public var titleHe: String {
        switch self {
        case .automatic: return "מכשיר נוכחי (אוטומטי)"
        case .ios27: return "זרימת iOS 27"
        case .legacy: return "זרימה ישנה (iOS 26 ומטה)"
        }
    }

    public var titleEn: String {
        switch self {
        case .automatic: return "Current Device / Automatic"
        case .ios27: return "iOS 27 Flow"
        case .legacy: return "Legacy Flow (iOS 26 and earlier)"
        }
    }
}

public struct AutomaticCaptureSetupGuide: View {

    // MARK: - Configuration
    /// The variant to display (automatic detects device OS, ios27/legacy force specific copy)
    public var variant: AutomaticCaptureGuideVariant
    /// When true: screen 0 (intro) is skipped and starts at step 1.
    public var skipIntro: Bool
    /// When true: forces manual 13-step guide instead of Fast Setup.
    public var forceManualGuide: Bool
    /// Fast Setup entry mode (.restart vs .resume).
    public var entryMode: FastSetupEntryMode
    /// Called when the user finishes or taps the secondary dismiss CTA.
    public var onFinished: () -> Void
    /// When true: a close (×) button appears in the top-right corner.
    public var showCloseButton: Bool

    public init(
        entryMode: FastSetupEntryMode = .restart,
        variant: AutomaticCaptureGuideVariant = .automatic,
        forceManualGuide: Bool = false,
        skipIntro: Bool = false,
        showCloseButton: Bool = true,
        onFinished: @escaping () -> Void
    ) {
        self.entryMode = entryMode
        self.variant = variant
        self.forceManualGuide = forceManualGuide
        self.skipIntro = skipIntro
        self.showCloseButton = showCloseButton
        self.onFinished = onFinished
    }

    // MARK: - OS Version Detection (Shortcuts Flow)
    private var effectiveVariant: AutomaticCaptureGuideVariant {
        if variant == .automatic,
           let forced = RemoteConfigService.shared.captureGuideForceVariant,
           let parsed = AutomaticCaptureGuideVariant(rawValue: forced) {
            return parsed
        }
        return variant
    }

    private var usesNewShortcutsFlow: Bool {
        switch effectiveVariant {
        case .ios27:
            return true
        case .legacy:
            return false
        case .automatic:
            #if os(iOS)
            if #available(iOS 27.0, *) {
                return true
            }
            let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
            if major >= 27 {
                return true
            }
            #endif
            return false
        }
    }

    // MARK: - Body
    public var body: some View {
        if usesNewShortcutsFlow {
            if !forceManualGuide && RemoteConfigService.shared.isFastSetupEnabled {
                IOS27FastCaptureSetupView(
                    entryMode: entryMode,
                    skipIntro: skipIntro,
                    showCloseButton: showCloseButton,
                    onFinished: onFinished
                )
            } else {
                IOS27CaptureSetupGuideView(
                    skipIntro: skipIntro,
                    showCloseButton: showCloseButton,
                    onFinished: onFinished
                )
            }
        } else {
            LegacyCaptureSetupGuideView(
                skipIntro: skipIntro,
                showCloseButton: showCloseButton,
                onFinished: onFinished
            )
        }
    }
}

// MARK: - Reusable SetupScreenshotCard
public struct SetupScreenshotCard: View {
    public let imageName: String
    public let tapRelativeX: CGFloat?
    public let tapRelativeY: CGFloat?
    public let aspectRatio: CGFloat
    public let accessibilityDescription: String?

    public init(
        imageName: String,
        tapRelativeX: CGFloat? = nil,
        tapRelativeY: CGFloat? = nil,
        aspectRatio: CGFloat,
        accessibilityDescription: String? = nil
    ) {
        self.imageName = imageName
        self.tapRelativeX = tapRelativeX
        self.tapRelativeY = tapRelativeY
        self.aspectRatio = aspectRatio
        self.accessibilityDescription = accessibilityDescription
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // The genuine iOS screenshot
            Image(imageName)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.jetBlack.opacity(0.08), lineWidth: 1)
                )
                .accessibilityLabel(accessibilityDescription ?? imageName)

            // Green concentric tap indicator overlay
            if let rx = tapRelativeX, let ry = tapRelativeY {
                GeometryReader { geo in
                    SpentTapIndicator()
                        .position(x: geo.size.width * rx, y: geo.size.height * ry)
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight) // Fixed LTR coordinates aligned with image pixels
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxHeight: 460)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - CaptureProgressBar
/// Thin, abstract progress bar — no numbers shown to user.
struct CaptureProgressBar: View {
    var fraction: Double
    var isHebrew: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: isHebrew ? .trailing : .leading) {
                Capsule()
                    .fill(Color.jetBlack.opacity(0.10))
                    .frame(height: 3)

                Capsule()
                    .fill(Color.jetBlack)
                    .frame(width: max(8, geo.size.width * fraction), height: 3)
                    .animation(.easeInOut(duration: 0.3), value: fraction)
            }
        }
        .frame(height: 3)
    }
}

// MARK: - SpentTapIndicator
public struct SpentTapIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            // Outer pulsing halo (from Figma TAP_HALO: 54x54)
            Circle()
                .stroke(Color.luckyGreen.opacity(0.25), lineWidth: 2)
                .frame(width: 54, height: 54)
                .scaleEffect(reduceMotion ? 1.0 : (isPulsing ? 1.16 : 0.88))
                .opacity(reduceMotion ? 0.25 : (isPulsing ? 0.40 : 0.15))

            // Middle ring (from Figma TAP_RING: 34x34)
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 34, height: 34)
                .overlay(
                    Circle()
                        .stroke(Color.luckyGreen, lineWidth: 2.5)
                )

            // Center solid dot (from Figma TAP_DOT: 10x10)
            Circle()
                .fill(Color.luckyGreen)
                .frame(width: 10, height: 10)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - IOS27SetupStep Model
public struct IOS27SetupStep: Identifiable {
    public let id: Int
    public let flowNumber: String
    public let titleHe: String
    public let titleEn: String
    public let bodyHe: String
    public let bodyEn: String
    public let imageName: String
    public let tapRelativeX: CGFloat?
    public let tapRelativeY: CGFloat?
    public let a11yHintHe: String?
    public let a11yHintEn: String?

    public static let allSteps: [IOS27SetupStep] = [
        IOS27SetupStep(
            id: 1,
            flowNumber: "01",
            titleHe: "פתח את קיצורים",
            titleEn: "Open Shortcuts",
            bodyHe: "מתוך ״כל הקיצורים״ לחץ על + כדי ליצור קיצור חדש.",
            bodyEn: "In \"All Shortcuts\", tap + to create a new shortcut.",
            imageName: "shortcut_ios27_step_01",
            tapRelativeX: 0.500,
            tapRelativeY: 0.922,
            a11yHintHe: "לחץ על כפתור הפלוס בתחתית המסך",
            a11yHintEn: "Tap the plus button at the bottom of the screen"
        ),
        IOS27SetupStep(
            id: 2,
            flowNumber: "02",
            titleHe: "בחר ״פעולות אוטומטיות״",
            titleEn: "Select \"Automations\"",
            bodyHe: "בתפריט הפעולות שנפתח למטה, לחץ על ״פעולות אוטומטיות״.",
            bodyEn: "In the action menu opened at the bottom, tap \"Automations\".",
            imageName: "shortcut_ios27_step_02",
            tapRelativeX: 0.725,
            tapRelativeY: 0.600,
            a11yHintHe: "לחץ על הכפתור פעולות אוטומטיות",
            a11yHintEn: "Tap the Automations button"
        ),
        IOS27SetupStep(
            id: 3,
            flowNumber: "03",
            titleHe: "בחר ״ארנק״",
            titleEn: "Select \"Wallet\"",
            bodyHe: "מתוך הפעולות האוטומטיות בחר ״ארנק״.",
            bodyEn: "From the automations list, select \"Wallet\".",
            imageName: "shortcut_ios27_step_03",
            tapRelativeX: 0.765,
            tapRelativeY: 0.585,
            a11yHintHe: "בחר בשורת ארנק",
            a11yHintEn: "Select the Wallet row"
        ),
        IOS27SetupStep(
            id: 4,
            flowNumber: "04",
            titleHe: "חפש את SPENT",
            titleEn: "Search for SPENT",
            bodyHe: "בשורת החיפוש הקלד SPENT ובחר ״הקלטת עסקת Apple Pay״.",
            bodyEn: "In the search bar, type SPENT and select \"Record Apple Pay Transaction\".",
            imageName: "shortcut_ios27_step_04",
            tapRelativeX: 0.575,
            tapRelativeY: 0.500,
            a11yHintHe: "בחר בשורה הקלטת עסקת Apple Pay",
            a11yHintEn: "Select Record Apple Pay Transaction"
        ),
        IOS27SetupStep(
            id: 5,
            flowNumber: "05",
            titleHe: "חבר את סכום העסקה",
            titleEn: "Connect Transaction Amount",
            bodyHe: "בתוך הפעולה של SPENT לחץ על ״סכום העסקה״.",
            bodyEn: "Inside the SPENT action, tap \"Transaction Amount\".",
            imageName: "shortcut_ios27_step_05",
            tapRelativeX: 0.355,
            tapRelativeY: 0.306,
            a11yHintHe: "לחץ על שדה סכום העסקה",
            a11yHintEn: "Tap the Transaction Amount field"
        ),
        IOS27SetupStep(
            id: 6,
            flowNumber: "06",
            titleHe: "בחר ״קלט של קיצור״",
            titleEn: "Select \"Shortcut Input\"",
            bodyHe: "מתחת למקלדת בחר ״קלט של קיצור״.",
            bodyEn: "Select \"Shortcut Input\" above the keyboard.",
            imageName: "shortcut_ios27_step_06",
            tapRelativeX: 0.640,
            tapRelativeY: 0.609,
            a11yHintHe: "בחר באפשרות קלט של קיצור מעל המקלדת",
            a11yHintEn: "Select Shortcut Input above the keyboard"
        ),
        IOS27SetupStep(
            id: 7,
            flowNumber: "07",
            titleHe: "הגדר את הקלט כעסקה",
            titleEn: "Set Input as Transaction",
            bodyHe: "לחץ על ״סוג״ ובחר ״עסקה״.",
            bodyEn: "Tap \"Type\" and select \"Transaction\".",
            imageName: "shortcut_ios27_step_07",
            tapRelativeX: 0.850,
            tapRelativeY: 0.661,
            a11yHintHe: "לחץ על שדה סוג ובחר עסקה",
            a11yHintEn: "Tap Type and select Transaction"
        ),
        IOS27SetupStep(
            id: 8,
            flowNumber: "08",
            titleHe: "בחר ״כמות״",
            titleEn: "Select \"Amount\"",
            bodyHe: "מתוך פרטי העסקה בחר ״כמות״.",
            bodyEn: "From the transaction details, select \"Amount\".",
            imageName: "shortcut_ios27_step_08",
            tapRelativeX: 0.860,
            tapRelativeY: 0.568,
            a11yHintHe: "בחר בשורה כמות",
            a11yHintEn: "Select Amount"
        ),
        IOS27SetupStep(
            id: 9,
            flowNumber: "09",
            titleHe: "עכשיו את בית העסק",
            titleEn: "Now the Merchant",
            bodyHe: "לחץ על השדה השני, ״שם בית העסק״.",
            bodyEn: "Tap the second field, \"Merchant Name\".",
            imageName: "shortcut_ios27_step_09",
            tapRelativeX: 0.770,
            tapRelativeY: 0.458,
            a11yHintHe: "לחץ על שדה שם בית העסק",
            a11yHintEn: "Tap the Merchant Name field"
        ),
        IOS27SetupStep(
            id: 10,
            flowNumber: "10",
            titleHe: "בחר שוב ״קלט של קיצור״",
            titleEn: "Select \"Shortcut Input\" Again",
            bodyHe: "כמו קודם, בחר ״קלט של קיצור״ עבור בית העסק.",
            bodyEn: "Just like before, select \"Shortcut Input\" for the merchant.",
            imageName: "shortcut_ios27_step_10",
            tapRelativeX: 0.640,
            tapRelativeY: 0.582,
            a11yHintHe: "בחר שוב באפשרות קלט של קיצור",
            a11yHintEn: "Select Shortcut Input again"
        ),
        IOS27SetupStep(
            id: 11,
            flowNumber: "11",
            titleHe: "בחר ״בית העסק״",
            titleEn: "Select \"Merchant\"",
            bodyHe: "מתוך פרטי העסקה בחר ״בית העסק״.",
            bodyEn: "From the transaction details, select \"Merchant\".",
            imageName: "shortcut_ios27_step_11",
            tapRelativeX: 0.760,
            tapRelativeY: 0.525,
            a11yHintHe: "בחר בשורה בית העסק",
            a11yHintEn: "Select Merchant"
        ),
        IOS27SetupStep(
            id: 12,
            flowNumber: "12",
            titleHe: "ככה זה אמור להיראות",
            titleEn: "Here's How It Should Look",
            bodyHe: "וודא שהסכום מחובר ל״כמות״ וששם המקום מחובר ל״בית העסק״.",
            bodyEn: "Make sure Amount is connected to \"Amount\" and merchant is connected to \"Merchant\".",
            imageName: "shortcut_ios27_step_12",
            tapRelativeX: nil,
            tapRelativeY: nil,
            a11yHintHe: "בדיקת תוצאה: וודא שהסכום מחובר לכמות וששם המקום מחובר לבית העסק",
            a11yHintEn: "Verification: Ensure Amount is connected to Amount and merchant to Merchant"
        ),
        IOS27SetupStep(
            id: 13,
            flowNumber: "13",
            titleHe: "זהו. SPENT מחוברת",
            titleEn: "That's it. SPENT is connected",
            bodyHe: "כשהפעולה האוטומטית מופיעה כאן ופעילה, סיימת.",
            bodyEn: "When the automation appears here and is active, you're done.",
            imageName: "shortcut_ios27_step_13",
            tapRelativeX: nil,
            tapRelativeY: nil,
            a11yHintHe: "אישור שהפעולה האוטומטית פעילה ברשימה",
            a11yHintEn: "Confirmation that the automation is active in the list"
        )
    ]

    public static func step(for id: Int) -> IOS27SetupStep {
        allSteps.first(where: { $0.id == id }) ?? allSteps[0]
    }
}

// MARK: - iOS 27 Capture Setup Guide View (iOS 27+)
public struct IOS27CaptureSetupGuideView: View {
    public var skipIntro: Bool
    public var showCloseButton: Bool
    public var onFinished: () -> Void

    public init(
        skipIntro: Bool = false,
        showCloseButton: Bool = true,
        onFinished: @escaping () -> Void
    ) {
        self.skipIntro = skipIntro
        self.showCloseButton = showCloseButton
        self.onFinished = onFinished
    }

    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Persist active step so switching to Shortcuts and returning preserves position
    @AppStorage("spent.capture.guide.screen") private var storedStep: Int = 1
    @AppStorage("user_name") private var storedUserName: String = ""

    @State private var currentStep: Int = 1
    @State private var showTrouble: Bool = false

    private var isHebrew: Bool { l10n.language == .hebrew }

    private var totalSteps: Int { 13 }
    private var completionStep: Int { 14 }

    private var pageAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.28)
    }

    private var progressFraction: Double {
        if currentStep <= 0 { return 0 }
        if currentStep >= completionStep { return 1.0 }
        return max(0, min(1, Double(currentStep) / Double(completionStep)))
    }

    private var progressA11yPercent: Int {
        Int((progressFraction * 100).rounded())
    }

    private var canGoBack: Bool {
        if skipIntro {
            return currentStep > 1
        } else {
            return currentStep > 0
        }
    }

    private var activeStep: IOS27SetupStep {
        IOS27SetupStep.step(for: max(1, min(totalSteps, currentStep)))
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: Back, progress bar, close
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                // Scrollable content area
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        if currentStep == 0 {
                            introContent
                        } else if currentStep == completionStep {
                            completionContent
                        } else {
                            stepContent(step: activeStep)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .frame(maxWidth: 520, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(currentStep)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .offset(x: isHebrew ? -24 : 24).combined(with: .opacity),
                        removal:   .offset(x: isHebrew ?  24 : -24).combined(with: .opacity)
                    ))
                }

                Spacer(minLength: 8)

                // Bottom bar CTAs
                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    .background(Color.appBackground)
            }
        }
        .environment(\.layoutDirection, isHebrew ? .rightToLeft : .leftToRight)
        .onAppear {
            let startStep = skipIntro ? 1 : 0
            if let fresh = AutomaticCaptureStateStore.getFreshIOS27Progress() {
                if fresh >= startStep && fresh < completionStep {
                    currentStep = fresh
                } else {
                    currentStep = startStep
                    storedStep = currentStep
                    AutomaticCaptureStateStore.saveIOS27Progress(screen: currentStep)
                }
            } else {
                currentStep = startStep
                storedStep = currentStep
                AutomaticCaptureStateStore.saveIOS27Progress(screen: currentStep)
            }
        }
        .sheet(isPresented: $showTrouble) {
            TroubleSheet(
                context: .shortcuts,
                usesNewShortcutsFlow: true,
                isHebrew: isHebrew
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack(spacing: 16) {
            Button(action: goBack) {
                Image(systemName: "arrow.backward")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.jetBlack)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isHebrew ? "חזרה" : "Back")
            .opacity(canGoBack ? 1 : 0)
            .allowsHitTesting(canGoBack)

            CaptureProgressBar(fraction: progressFraction, isHebrew: isHebrew)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isHebrew
                    ? "התקדמות בהגדרת קליטה אוטומטית, שלב \(currentStep) מתוך \(totalSteps)"
                    : "Progress setting up automatic capture, step \(currentStep) of \(totalSteps)")

            if showCloseButton {
                Button(action: {
                    Haptics.selection()
                    onFinished()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.jetBlack.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(Color.jetBlack.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isHebrew ? "סגור" : "Close")
            } else {
                Color.clear.frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Intro Content (Step 0)
    private var introContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isHebrew
                ? "מגדירים פעם אחת.\nאחר כך זה קורה לבד."
                : "Set it up once.\nThen it runs automatically.")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(Color.jetBlack)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text(isHebrew
                ? "נגדיר לאייפון להעביר ל-SPENT את סכום העסקה ואת בית העסק אחרי כל תשלום ב-Apple Pay."
                : "We'll set up your iPhone to pass transaction amounts and merchants to SPENT after every Apple Pay purchase.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 14) {
                introReassuranceRow(
                    icon: "sparkles",
                    text: isHebrew ? "זה קצר, ומגדירים את זה רק פעם אחת." : "It's quick, and you only set it up once."
                )
                introReassuranceRow(
                    icon: "lock.shield",
                    text: isHebrew ? "העסקאות נשמרות רק במכשיר שלך ללא חיבור לבנק." : "Transactions stay securely on your device without bank connections."
                )
                introReassuranceRow(
                    icon: "hand.tap",
                    text: isHebrew ? "המדריך כולל צילומי מסך וסימוני טאפ מדויקים." : "The guide features step-by-step screenshots and exact tap indicators."
                )
            }
            .padding(.top, 12)
        }
    }

    private func introReassuranceRow(icon: String, text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.jetBlack.opacity(0.6))
                .frame(width: 22, height: 22)

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color.jetBlack)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Step Content (Steps 1-13)
    private func stepContent(step: IOS27SetupStep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title
            Text(isHebrew ? step.titleHe : step.titleEn)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(Color.jetBlack)
                .fixedSize(horizontal: false, vertical: true)

            // Body
            Text(isHebrew ? step.bodyHe : step.bodyEn)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Screenshot with Tap Indicator
            screenshotCard(step: step)
                .padding(.top, 6)
        }
    }

    // MARK: - Completion Content (Step 14)
    private var completionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isHebrew ? "ההגדרה הסתיימה" : "Setup complete")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color.jetBlack)
                .fixedSize(horizontal: false, vertical: true)

            Text(isHebrew
                ? "SPENT מחכה לקליטה הראשונה מהפעולה האוטומטית. אחרי התשלום הבא נדע שהכול מחובר."
                : "SPENT is waiting for the first automatic capture. After your next payment, we'll know everything is connected.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            OnboardingCityScene(
                step: .automation,
                mayorName: storedUserName,
                targetAmountText: "",
                currencySymbol: l10n.baseCurrency.symbol,
                isRTL: isHebrew,
                height: 220
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
            .padding(.bottom, 4)

            Text(isHebrew ? "מחכה לקליטה הראשונה" : "Waiting for the first capture")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Screenshot Device Card
    @ViewBuilder
    private func screenshotCard(step: IOS27SetupStep) -> some View {
        SetupScreenshotCard(
            imageName: step.imageName,
            tapRelativeX: step.tapRelativeX,
            tapRelativeY: step.tapRelativeY,
            aspectRatio: 1206.0 / 2622.0,
            accessibilityDescription: isHebrew ? step.a11yHintHe : step.a11yHintEn
        )
    }

    // MARK: - Bottom Bar
    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 10) {
            if currentStep == 0 {
                // Intro CTAs
                Button(action: advance) {
                    Text(isHebrew ? "יאללה, נגדיר" : "Let's set it up")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.luckyGreen)
                        )
                }
                .buttonStyle(.plain)
                .bouncyPress()

                Button(action: {
                    Haptics.selection()
                    onFinished()
                }) {
                    Text(isHebrew ? "אעשה את זה אחר כך" : "I'll do this later")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                        .frame(minHeight: 40)
                }
                .buttonStyle(.plain)

            } else if currentStep == 1 {
                // Step 1: Open Shortcuts button + Next button
                Button(action: openShortcutsApp) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 15, weight: .semibold))
                        Text(isHebrew ? "פתח את אפליקציית קיצורים" : "Open Shortcuts App")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Color.jetBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.jetBlack.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                .bouncyPress()

                Button(action: advance) {
                    Text(isHebrew ? "הבא" : "Next")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.luckyGreen)
                        )
                }
                .buttonStyle(.plain)
                .bouncyPress()

            } else if currentStep <= totalSteps {
                // Steps 2 - 13: Back button + Next button
                HStack(spacing: 12) {
                    Button(action: goBack) {
                        Text(isHebrew ? "הקודם" : "Back")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.jetBlack)
                            .frame(width: 105)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.jetBlack.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    .bouncyPress()

                    Button(action: advance) {
                        Text(isHebrew ? "הבא" : "Next")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.luckyGreen)
                            )
                    }
                    .buttonStyle(.plain)
                    .bouncyPress()
                }
            } else {
                // Step 14 (Completion Screen): Single prominent "סיימתי" button
                Button(action: {
                    Haptics.notify(.success)
                    AutomaticCaptureStateStore.markSetupCompleted(at: Date())
                    onFinished()
                }) {
                    Text(isHebrew ? "סיימתי" : "Done")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.luckyGreen)
                        )
                }
                .buttonStyle(.plain)
                .bouncyPress()
            }
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions
    private func advance() {
        Haptics.impact(.medium)
        withAnimation(pageAnimation) {
            if currentStep < completionStep {
                currentStep += 1
                storedStep = currentStep
                AutomaticCaptureStateStore.saveIOS27Progress(screen: currentStep)
            } else {
                Haptics.notify(.success)
                AutomaticCaptureStateStore.markSetupCompleted(at: Date())
                onFinished()
            }
        }
    }

    private func goBack() {
        Haptics.selection()
        withAnimation(pageAnimation) {
            let minStep = skipIntro ? 1 : 0
            if currentStep > minStep {
                currentStep -= 1
                storedStep = currentStep
                AutomaticCaptureStateStore.saveIOS27Progress(screen: currentStep)
            }
        }
    }

    private func openShortcutsApp() {
        Haptics.impact(.medium)
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - TroubleContext & Sheet
enum TroubleContext {
    case shortcuts, card, spent, amount, merchant
}

struct TroubleSheet: View {
    var context: TroubleContext
    var usesNewShortcutsFlow: Bool
    var isHebrew: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    goldenRuleBanner
                    contextHelpSection
                    Divider().padding(.horizontal, 20)
                    generalTipsSection
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(isHebrew ? "עזרה" : "Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isHebrew ? "סגור" : "Close") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .medium))
                }
            }
        }
        .environment(\.layoutDirection, isHebrew ? .rightToLeft : .leftToRight)
    }

    private var goldenRuleBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.themeOrange)
                .padding(.top, 2)

            Text(isHebrew
                ? "אם אתה לא רואה כפתור ברור, חפש למטה את מה שאתה רוצה ולחץ עליו."
                : "If you don't see an obvious button, search at the bottom of the screen and tap it.")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundColor(Color.jetBlack)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.themeOrange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.themeOrange.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var contextHelpSection: some View {
        switch context {
        case .shortcuts:
            shortcutsHelp
        case .card:
            cardHelp
        case .spent:
            spentHelp
        case .amount:
            amountHelp
        case .merchant:
            merchantHelp
        }
    }

    private var shortcutsHelp: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isHebrew ? "איך יוצרים את הפעולה האוטומטית?" : "How to create the automation?")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundColor(Color.deepNavy)

            if usesNewShortcutsFlow {
                Text(isHebrew
                    ? "אחרי לחיצה על +, בחר ׳פעולות אוטומטיות׳, ולאחר מכן בחר ׳ארנק׳."
                    : "After tapping +, choose \"Automations\", and then choose \"Wallet\".")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)

                VStack(alignment: .center, spacing: 3) {
                    stepPill("+")
                    arrowDown
                    stepPill(isHebrew ? "פעולות אוטומטיות" : "Automations")
                    arrowDown
                    stepPill(isHebrew ? "ארנק" : "Wallet", highlight: true)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.jetBlack.opacity(0.035))
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isHebrew
                    ? "+, בחר פעולות אוטומטיות, בחר ארנק"
                    : "+, choose Automations, choose Wallet")
            } else {
                Text(isHebrew
                    ? "באפליקציה ׳קיצורים׳: עבור ללשונית פעולות אוטומטיות, לחץ על + ובחר ׳ארנק׳."
                    : "In Shortcuts: go to the Automations tab, tap + and choose \"Wallet\".")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 20)
    }

    private var cardHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isHebrew ? "איפה נמצא ׳הפעלה מיידית׳?" : "Where is \"Run Immediately\"?")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundColor(Color.deepNavy)

            Text(isHebrew
                ? "במסך הגדרת הפעולה האוטומטית, בחר את הכרטיסים שבהם אתה משלם. ייתכן שתצטרך לגלול מעט למטה כדי לראות את האפשרות ׳הפעלה מיידית׳."
                : "In the automation setup screen, choose the cards you pay with. You may need to scroll down slightly to see \"Run Immediately\".")
                .font(.system(.body, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .lineSpacing(2)
        }
        .padding(.horizontal, 20)
    }

    private var spentHelp: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isHebrew ? "לא מוצא איך להוסיף את SPENT?" : "Can't find how to add SPENT?")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundColor(Color.deepNavy)

            if usesNewShortcutsFlow {
                Text(isHebrew
                    ? "ב׳קיצורים׳ לא תמיד יש כפתור ברור של הוספה. פשוט השתמש בשדה החיפוש שמופיע למטה, חפש ׳הקלטת עסקת Apple Pay׳ ולחץ על התוצאה. היא תתווסף למסך."
                    : "In Shortcuts there isn't always an obvious Add button. Simply use the search bar at the bottom, search for \"Record Apple Pay Transaction\" and tap the result. It will be added to the screen.")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            } else {
                Text(isHebrew
                    ? "בחר ׳קיצור חדש׳ או ׳קיצור ריק חדש׳, לחץ על ׳הוסף פעולה׳, חפש SPENT ובחר ׳הקלטת עסקת Apple Pay׳."
                    : "Choose \"New Shortcut\" or \"New Blank Automation\", tap Add Action, search for SPENT and pick \"Record Apple Pay Transaction\".")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 20)
    }

    private var amountHelp: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isHebrew ? "איך לחבר את הסכום?" : "How to connect the amount?")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundColor(Color.deepNavy)

            Text(isHebrew
                ? "לחץ על שדה ׳סכום העסקה׳ בתוך הפעולה של SPENT ← בחר ׳קלט של קיצור׳ ← בחר ׳כמות׳ מתוך פרטי העסקה."
                : "Tap the \"Transaction Amount\" field inside the SPENT action → choose \"Shortcut Input\" → choose \"Amount\" from the transaction details.")
                .font(.system(.body, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .lineSpacing(2)
        }
        .padding(.horizontal, 20)
    }

    private var merchantHelp: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isHebrew ? "איך לחבר את בית העסק?" : "How to connect the merchant?")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundColor(Color.deepNavy)

            Text(isHebrew
                ? "לחץ על שדה ׳שם בית העסק׳ בתוך הפעולה של SPENT ← בחר ׳קלט של קיצור׳ ← בחר ׳בית העסק׳ מתוך פרטי העסקה."
                : "Tap the \"Merchant Name\" field inside the SPENT action → choose \"Shortcut Input\" → choose \"Merchant\" from the transaction details.")
                .font(.system(.body, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .lineSpacing(2)
        }
        .padding(.horizontal, 20)
    }

    private func stepPill(_ title: String, highlight: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 12.5, weight: highlight ? .bold : .semibold, design: .rounded))
            .foregroundColor(highlight ? Color.themeOrange : Color.deepNavy)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(highlight ? Color.themeOrange.opacity(0.15) : Color.deepNavy.opacity(0.06))
            )
    }

    private var arrowDown: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(Color.textMuted)
            .padding(.vertical, 1)
    }

    private var generalTipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(generalItems, id: \.question) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.question)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(Color.deepNavy)
                    Text(item.answer)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 20)

                if item.question != generalItems.last?.question {
                    Divider().padding(.horizontal, 20)
                }
            }
        }
    }

    private var generalItems: [(question: String, answer: String)] {
        if isHebrew {
            return [
                (
                    question: "נראה אצלך קצת אחרת?",
                    answer: "המראה של ׳קיצורים׳ יכול להשתנות מעט בין גרסאות iOS. חפש לפי השמות שמופיעים כאן, לא לפי המיקום שלהם."
                ),
                (
                    question: "לא מוצא את ״קיצורים״?",
                    answer: "חפש ״קיצורים״ בחיפוש של האייפון."
                ),
                (
                    question: "לא מוצא SPENT?",
                    answer: "פתח את SPENT לפחות פעם אחת, חזור ל״קיצורים״ וחפש שוב."
                ),
            ]
        } else {
            return [
                (
                    question: "Looks slightly different on your device?",
                    answer: "Shortcuts can look slightly different across iOS versions. Search by the names shown here, not by their exact position."
                ),
                (
                    question: "Can't find Shortcuts?",
                    answer: "Search \"Shortcuts\" on your iPhone."
                ),
                (
                    question: "Can't find SPENT?",
                    answer: "Open SPENT at least once, go back to Shortcuts and search again."
                ),
            ]
        }
    }
}

// MARK: - Legacy Capture Setup Guide View (iOS < 27)
// Built faithfully to Figma flow: SPENT — Apple Pay Setup Flow (9 steps)
public struct LegacyCaptureSetupGuideView: View {
    public var skipIntro: Bool
    public var showCloseButton: Bool
    public var onFinished: () -> Void

    public init(
        skipIntro: Bool = false,
        showCloseButton: Bool = true,
        onFinished: @escaping () -> Void
    ) {
        self.skipIntro = skipIntro
        self.showCloseButton = showCloseButton
        self.onFinished = onFinished
    }

    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Persist active step so switching to Shortcuts and returning preserves position
    @AppStorage("spent.capture.guide.legacy.step") private var storedStep: Int = 1
    @AppStorage("user_name") private var storedUserName: String = ""

    @State private var currentStep: Int = 1
    @State private var showTrouble: Bool = false

    private var isHebrew: Bool { l10n.language == .hebrew }

    private var totalSteps: Int { 9 }
    private var completionStep: Int { 10 }

    private var pageAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.28)
    }

    private var progressFraction: Double {
        if currentStep <= 0 { return 0 }
        if currentStep >= completionStep { return 1.0 }
        return max(0, min(1, Double(currentStep) / Double(completionStep)))
    }

    private var progressA11yPercent: Int {
        Int((progressFraction * 100).rounded())
    }

    private var canGoBack: Bool {
        if skipIntro {
            return currentStep > 1
        } else {
            return currentStep > 0
        }
    }

    private var activeStep: LegacySetupStep {
        LegacySetupStep.step(for: max(1, min(totalSteps, currentStep)))
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: Back, progress bar, close
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                // Scrollable content area
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        if currentStep == 0 {
                            introContent
                        } else if currentStep == completionStep {
                            completionContent
                        } else {
                            stepContent(step: activeStep)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .frame(maxWidth: 520, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(currentStep)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .offset(x: isHebrew ? -24 : 24).combined(with: .opacity),
                        removal:   .offset(x: isHebrew ?  24 : -24).combined(with: .opacity)
                    ))
                }

                Spacer(minLength: 8)

                // Bottom bar CTAs
                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    .background(Color.appBackground)
            }
        }
        .environment(\.layoutDirection, isHebrew ? .rightToLeft : .leftToRight)
        .onAppear {
            let startStep = skipIntro ? 1 : 0
            if let fresh = AutomaticCaptureStateStore.getFreshLegacyProgress() {
                if fresh >= startStep && fresh < completionStep {
                    currentStep = fresh
                } else {
                    currentStep = startStep
                    storedStep = currentStep
                    AutomaticCaptureStateStore.saveLegacyProgress(step: currentStep)
                }
            } else {
                currentStep = startStep
                storedStep = currentStep
                AutomaticCaptureStateStore.saveLegacyProgress(step: currentStep)
            }
        }
        .sheet(isPresented: $showTrouble) {
            TroubleSheet(
                context: .shortcuts,
                usesNewShortcutsFlow: false,
                isHebrew: isHebrew
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack(spacing: 16) {
            Button(action: goBack) {
                Image(systemName: "arrow.backward")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.jetBlack)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isHebrew ? "חזרה" : "Back")
            .opacity(canGoBack ? 1 : 0)
            .allowsHitTesting(canGoBack)

            CaptureProgressBar(fraction: progressFraction, isHebrew: isHebrew)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isHebrew
                    ? "התקדמות בהגדרת קליטה אוטומטית, שלב \(currentStep) מתוך \(totalSteps)"
                    : "Progress setting up automatic capture, step \(currentStep) of \(totalSteps)")

            if showCloseButton {
                Button(action: {
                    Haptics.selection()
                    onFinished()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.jetBlack.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(Color.jetBlack.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isHebrew ? "סגור" : "Close")
            } else {
                Color.clear.frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Intro Content (Step 0)
    private var introContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isHebrew
                ? "מגדירים פעם אחת.\nאחר כך זה קורה לבד."
                : "Set it up once.\nThen it runs automatically.")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(Color.jetBlack)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text(isHebrew
                ? "נגדיר לאייפון להעביר ל-SPENT את סכום העסקה ואת בית העסק אחרי כל תשלום ב-Apple Pay."
                : "We'll set up your iPhone to pass transaction amounts and merchants to SPENT after every Apple Pay purchase.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 14) {
                introReassuranceRow(
                    icon: "sparkles",
                    text: isHebrew ? "זה קצר, ומגדירים את זה רק פעם אחת." : "It's quick, and you only set it up once."
                )
                introReassuranceRow(
                    icon: "lock.shield",
                    text: isHebrew ? "העסקאות נשמרות רק במכשיר שלך ללא חיבור לבנק." : "Transactions stay securely on your device without bank connections."
                )
                introReassuranceRow(
                    icon: "hand.tap",
                    text: isHebrew ? "המדריך כולל צילומי מסך וסימוני טאפ מדויקים." : "The guide features step-by-step screenshots and exact tap indicators."
                )
            }
            .padding(.top, 12)
        }
    }

    private func introReassuranceRow(icon: String, text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.jetBlack.opacity(0.6))
                .frame(width: 22, height: 22)

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color.jetBlack)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Step Content (Steps 1-9)
    private func stepContent(step: LegacySetupStep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title
            Text(isHebrew ? step.titleHe : step.titleEn)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(Color.jetBlack)
                .fixedSize(horizontal: false, vertical: true)

            // Body
            Text(isHebrew ? step.bodyHe : step.bodyEn)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Screenshot with Tap Indicator
            screenshotCard(step: step)
                .padding(.top, 6)
        }
    }

    // MARK: - Completion Content (Step 10)
    private var completionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isHebrew ? "ההגדרה הסתיימה" : "Setup complete")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color.jetBlack)
                .fixedSize(horizontal: false, vertical: true)

            Text(isHebrew
                ? "SPENT מחכה לקליטה הראשונה מהפעולה האוטומטית. אחרי התשלום הבא נדע שהכול מחובר."
                : "SPENT is waiting for the first automatic capture. After your next payment, we'll know everything is connected.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            // Dynamic onboarding-vibe city scene for automatic capture
            OnboardingCityScene(
                step: .automation,
                mayorName: storedUserName,
                targetAmountText: "",
                currencySymbol: l10n.baseCurrency.symbol,
                isRTL: isHebrew,
                height: 220
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Quiet state text
            Text(isHebrew ? "מחכה לקליטה הראשונה" : "Waiting for the first capture")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Screenshot Device Card
    @ViewBuilder
    private func screenshotCard(step: LegacySetupStep) -> some View {
        SetupScreenshotCard(
            imageName: step.imageName,
            tapRelativeX: step.tapRelativeX,
            tapRelativeY: step.tapRelativeY,
            aspectRatio: 259.0 / 520.0
        )
    }

    // MARK: - Bottom Bar
    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 10) {
            if currentStep == 0 {
                // Intro CTAs
                Button(action: advance) {
                    Text(isHebrew ? "יאללה, נגדיר" : "Let's set it up")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.luckyGreen)
                        )
                }
                .buttonStyle(.plain)
                .bouncyPress()

                Button(action: {
                    Haptics.selection()
                    onFinished()
                }) {
                    Text(isHebrew ? "אעשה את זה אחר כך" : "I'll do this later")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                        .frame(minHeight: 40)
                }
                .buttonStyle(.plain)

            } else if currentStep == 1 {
                // Step 1: Open Shortcuts button + Next button
                Button(action: openShortcutsApp) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 15, weight: .semibold))
                        Text(isHebrew ? "פתח את אפליקציית קיצורים" : "Open Shortcuts App")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Color.jetBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.jetBlack.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                .bouncyPress()

                Button(action: advance) {
                    Text(isHebrew ? "הבא" : "Next")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.luckyGreen)
                        )
                }
                .buttonStyle(.plain)
                .bouncyPress()

            } else if currentStep <= totalSteps {
                // Steps 2 - 9: Back button + Next button
                HStack(spacing: 12) {
                    Button(action: goBack) {
                        Text(isHebrew ? "הקודם" : "Back")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.jetBlack)
                            .frame(width: 105)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.jetBlack.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    .bouncyPress()

                    Button(action: advance) {
                        Text(isHebrew ? "הבא" : "Next")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.luckyGreen)
                            )
                    }
                    .buttonStyle(.plain)
                    .bouncyPress()
                }
            } else {
                // Step 10 (Completion Screen): Single prominent "סיימתי" button
                Button(action: {
                    Haptics.notify(.success)
                    AutomaticCaptureStateStore.markSetupCompleted(at: Date())
                    onFinished()
                }) {
                    Text(isHebrew ? "סיימתי" : "Done")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.luckyGreen)
                        )
                }
                .buttonStyle(.plain)
                .bouncyPress()
            }
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions
    private func advance() {
        Haptics.impact(.medium)
        withAnimation(pageAnimation) {
            if currentStep < completionStep {
                currentStep += 1
                storedStep = currentStep
                AutomaticCaptureStateStore.saveLegacyProgress(step: currentStep)
            } else {
                Haptics.notify(.success)
                AutomaticCaptureStateStore.markSetupCompleted(at: Date())
                onFinished()
            }
        }
    }

    private func goBack() {
        Haptics.selection()
        withAnimation(pageAnimation) {
            let minStep = skipIntro ? 1 : 0
            if currentStep > minStep {
                currentStep -= 1
                storedStep = currentStep
                AutomaticCaptureStateStore.saveLegacyProgress(step: currentStep)
            }
        }
    }

    private func openShortcutsApp() {
        Haptics.impact(.medium)
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - LegacySetupStep Model
public struct LegacySetupStep: Identifiable {
    public let id: Int
    public let flowNumber: String
    public let titleHe: String
    public let titleEn: String
    public let bodyHe: String
    public let bodyEn: String
    public let imageName: String
    public let tapRelativeX: CGFloat?
    public let tapRelativeY: CGFloat?

    public static let allSteps: [LegacySetupStep] = [
        LegacySetupStep(
            id: 1,
            flowNumber: "01",
            titleHe: "פתח את אפליקציית קיצורים",
            titleEn: "Open Shortcuts App",
            bodyHe: "עבור בתפריט שלמטה ל״פעולות אוטומטיות״ והקש על + בפינה העליונה.",
            bodyEn: "In the bottom menu, go to \"Automations\" and tap + in the top corner.",
            imageName: "shortcut_legacy_step_01",
            tapRelativeX: 0.1313,
            tapRelativeY: 0.0923
        ),
        LegacySetupStep(
            id: 2,
            flowNumber: "02",
            titleHe: "בחר את ״ארנק״",
            titleEn: "Select \"Wallet\"",
            bodyHe: "גלול ברשימת הטריגרים עד ״ארנק״ והקש עליו.",
            bodyEn: "Scroll through the trigger list to \"Wallet\" and tap it.",
            imageName: "shortcut_legacy_step_02",
            tapRelativeX: 0.4903,
            tapRelativeY: 0.7673
        ),
        LegacySetupStep(
            id: 3,
            flowNumber: "03",
            titleHe: "בחר מה לעקוב",
            titleEn: "Choose What to Track",
            bodyHe: "סמן את הכרטיסים והקטגוריות הרצויים, ואז הקש ״הבא״.",
            bodyEn: "Select the desired cards and categories, then tap \"Next\".",
            imageName: "shortcut_legacy_step_03",
            tapRelativeX: 0.1969,
            tapRelativeY: 0.0808
        ),
        LegacySetupStep(
            id: 4,
            flowNumber: "04",
            titleHe: "הוסף פעולה",
            titleEn: "Add Action",
            bodyHe: "הקש על ״יצירת קיצור חדש״ כדי להמשיך.",
            bodyEn: "Tap \"New Blank Automation\" to continue.",
            imageName: "shortcut_legacy_step_04",
            tapRelativeX: 0.7027,
            tapRelativeY: 0.3385
        ),
        LegacySetupStep(
            id: 5,
            flowNumber: "05",
            titleHe: "חפש את SPENT",
            titleEn: "Search for SPENT",
            bodyHe: "הקלד Spe ובחר ״הקלטת עסקת Apple Pay״.",
            bodyEn: "Type Spe and select \"Record Apple Pay Transaction\".",
            imageName: "shortcut_legacy_step_05",
            tapRelativeX: 0.2587,
            tapRelativeY: 0.5288
        ),
        LegacySetupStep(
            id: 6,
            flowNumber: "06",
            titleHe: "חבר את סכום העסקה",
            titleEn: "Connect Transaction Amount",
            bodyHe: "בשדה הסכום בחר ״קלט של קיצור״ ואז לחץ עליו שוב ובחר ״כמות״.",
            bodyEn: "In the amount field select \"Shortcut Input\", tap it again and choose \"Amount\".",
            imageName: "shortcut_legacy_step_06",
            tapRelativeX: 0.3977,
            tapRelativeY: 0.2596
        ),
        LegacySetupStep(
            id: 7,
            flowNumber: "07",
            titleHe: "חבר את שם המקום",
            titleEn: "Connect Merchant Name",
            bodyHe: "בחר שוב ״קלט של קיצור״ בשדה הבא ולחץ עליו שוב ובחר בית העסק.",
            bodyEn: "Select \"Shortcut Input\" again in the next field, tap it again, and choose Merchant.",
            imageName: "shortcut_legacy_step_07",
            tapRelativeX: 0.7529,
            tapRelativeY: 0.2981
        ),
        LegacySetupStep(
            id: 8,
            flowNumber: "08",
            titleHe: "בדוק שזה נשמר",
            titleEn: "Verify It's Saved",
            bodyHe: "חזור ל״פעולות אוטומטיות״ וודא שהפעולה מופיעה ברשימה, ולחץ עליה.",
            bodyEn: "Return to \"Automations\", verify that the automation appears in the list, and tap it.",
            imageName: "shortcut_legacy_step_09",
            tapRelativeX: 0.50,
            tapRelativeY: 0.22
        ),
        LegacySetupStep(
            id: 9,
            flowNumber: "09",
            titleHe: "סיים את ההגדרה",
            titleEn: "Finish Setup",
            bodyHe: "וודא שהסימון הוא על ״הפעלה מיידית״, ואז הקש ״סיום״.",
            bodyEn: "Verify it is set to \"Run Immediately\", then tap \"Done\".",
            imageName: "shortcut_legacy_step_08",
            tapRelativeX: 0.1351,
            tapRelativeY: 0.0904
        )
    ]

    public static func step(for id: Int) -> LegacySetupStep {
        allSteps.first(where: { $0.id == id }) ?? allSteps[0]
    }
}

// MARK: - Previews
#Preview("iOS 27 Guide • Step 1") {
    IOS27CaptureSetupGuideView(skipIntro: true, onFinished: {})
        .environmentObject(LocalizationManager.shared)
}

#Preview("iOS 27 Guide • Step 12 • Verification") {
    IOS27CaptureSetupGuideView(skipIntro: true, onFinished: {})
        .environmentObject(LocalizationManager.shared)
        .onAppear {
            UserDefaults.standard.set(12, forKey: "spent.capture.guide.screen")
        }
}

#Preview("iOS 27 Guide • Full Automatic") {
    AutomaticCaptureSetupGuide(variant: .ios27, skipIntro: false, onFinished: {})
        .environmentObject(LocalizationManager.shared)
}

#Preview("Legacy Guide • Step 1 • Hebrew") {
    LegacyCaptureSetupGuideView(skipIntro: true, onFinished: {})
        .environmentObject(LocalizationManager.shared)
}

#Preview("Legacy Guide • Step 6 • Connect Amount") {
    LegacyCaptureSetupGuideView(skipIntro: true, onFinished: {})
        .environmentObject(LocalizationManager.shared)
        .onAppear {
            UserDefaults.standard.set(6, forKey: "spent.capture.guide.legacy.step")
        }
}

#Preview("Legacy Guide • Step 10 • Completion Screen") {
    LegacyCaptureSetupGuideView(skipIntro: true, onFinished: {})
        .environmentObject(LocalizationManager.shared)
        .onAppear {
            UserDefaults.standard.set(10, forKey: "spent.capture.guide.legacy.step")
        }
}

#Preview("Legacy Guide • English") {
    LegacyCaptureSetupGuideView(skipIntro: true, onFinished: {})
        .environmentObject({
            let m = LocalizationManager.shared
            m.language = .english
            return m
        }())
}

#Preview("Automatic Guide • Legacy Variant") {
    AutomaticCaptureSetupGuide(variant: .legacy, skipIntro: false, onFinished: {})
        .environmentObject(LocalizationManager.shared)
}
