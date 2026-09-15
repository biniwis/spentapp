import SwiftUI

// MARK: - AutomaticCaptureSetupGuide
//
// Single source of truth for the Automatic Capture setup walkthrough.
// Used by:
//   • ApplePayGuideSheet  — presented as fullScreenCover from ProfileView
//   • OnboardingWizardView step 4B — embedded (skipIntro: true, no full-screen chrome)
//
// Screens (0–6):
//   0 — Intro           (skipped in onboarding — 4A already does this job)
//   1 — Open Shortcuts + pick Automation + pick Transaction (merged)
//   2 — Choose card + Run Immediately
//   3 — Add SPENT action
//   4 — Connect Amount
//   5 — Connect Merchant
//   6 — Done
//
// Design rules (from spec):
//   • CTA-only forward navigation — no free swipe
//   • Current screen persisted via @AppStorage so returning from Shortcuts
//     drops the user exactly where they left off
//   • Progress bar is abstract (no numbers); VoiceOver reads ~percentage
//   • RTL-safe: mapping diagram is vertical so no directional arrows flip

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
    /// When true: screen 0 (intro) is shown. When false: starts at screen 1.
    public var skipIntro: Bool
    /// Called when the user finishes or taps the secondary dismiss CTA.
    public var onFinished: () -> Void
    /// When true: a close (×) button appears in the top-right corner.
    public var showCloseButton: Bool

    public init(
        variant: AutomaticCaptureGuideVariant = .automatic,
        skipIntro: Bool = false,
        showCloseButton: Bool = true,
        onFinished: @escaping () -> Void
    ) {
        self.variant = variant
        self.skipIntro = skipIntro
        self.showCloseButton = showCloseButton
        self.onFinished = onFinished
    }

    // MARK: - State
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Persisted so returning from Shortcuts lands on the same screen.
    @AppStorage("spent.capture.guide.screen") private var storedScreen: Int = 0

    @State private var currentScreen: Int = 0
    @State private var hasOpenedShortcuts: Bool = false
    @State private var showTrouble: Bool = false
    @State private var troubleContext: TroubleContext = .shortcuts

    private var isHebrew: Bool { l10n.language == .hebrew }

    // MARK: - OS Version Detection (Shortcuts Flow)
    private var usesNewShortcutsFlow: Bool {
        switch variant {
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

    // The active screen sequence (screen 2 is omitted in iOS 27 flow)
    private var activeScreens: [Int] {
        let base = usesNewShortcutsFlow ? [1, 3, 4, 5, 6] : [1, 2, 3, 4, 5, 6]
        return skipIntro ? base : [0] + base
    }

    private var firstScreen: Int { activeScreens.first ?? (skipIntro ? 1 : 0) }

    private var canGoBack: Bool {
        guard let idx = activeScreens.firstIndex(of: currentScreen) else { return false }
        return idx > 0
    }

    // MARK: - Progress (abstract, no visible numbers)
    private var progressFraction: Double {
        guard let currentIndex = activeScreens.firstIndex(of: currentScreen) else { return 0 }
        let total = activeScreens.count - 1
        guard total > 0 else { return 1 }
        return max(0, min(1, Double(currentIndex) / Double(total)))
    }

    private var progressA11yPercent: Int {
        Int((progressFraction * 100).rounded())
    }

    // MARK: - Transition
    private var pageAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.28)
    }

    // MARK: - Body
    public var body: some View {
        ZStack(alignment: .top) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top chrome: progress + optional close
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                // Main content area — scrollable per screen
                ScrollView(showsIndicators: false) {
                    screenContent
                        .id(currentScreen)
                        .transition(reduceMotion ? .opacity : .asymmetric(
                            insertion: .offset(x: isHebrew ? -24 : 24).combined(with: .opacity),
                            removal:   .offset(x: isHebrew ?  24 : -24).combined(with: .opacity)
                        ))
                        .animation(pageAnimation, value: currentScreen)
                        .padding(.horizontal, 26)
                        .padding(.bottom, 24)
                        .frame(maxWidth: 560, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 12)

                // Bottom CTA(s)
                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    .background(Color.appBackground)
            }
        }
        .environment(\.layoutDirection, isHebrew ? .rightToLeft : .leftToRight)
        .onAppear {
            let saved = storedScreen
            if activeScreens.contains(saved) {
                currentScreen = saved
            } else {
                currentScreen = activeScreens.first ?? firstScreen
            }
        }
        .sheet(isPresented: $showTrouble) {
            TroubleSheet(
                context: troubleContext,
                usesNewShortcutsFlow: usesNewShortcutsFlow,
                isHebrew: isHebrew
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack(spacing: 16) {
            // Back button (hidden on first screen)
            Button(action: goBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.jetBlack)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isHebrew ? "חזרה" : "Back")
            .opacity(canGoBack ? 1 : 0)
            .allowsHitTesting(canGoBack)

            // Progress bar — abstract, no numbers
            CaptureProgressBar(fraction: progressFraction, isHebrew: isHebrew)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isHebrew
                    ? "התקדמות בהגדרת קליטה אוטומטית, כ-\(progressA11yPercent)%"
                    : "Progress setting up automatic capture, about \(progressA11yPercent)%")

            // Close button or spacer
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
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Screen Router
    @ViewBuilder
    private var screenContent: some View {
        switch currentScreen {
        case 0:  screen0Intro
        case 1:  screen1Shortcuts
        case 2:  screen2Card
        case 3:  screen3SPENT
        case 4:  screen4Amount
        case 5:  screen5Merchant
        default: screen6Done
        }
    }

    // MARK: - Bottom Bar Router
    @ViewBuilder
    private var bottomBar: some View {
        switch currentScreen {
        case 0:  bottomBar0
        case 1:  bottomBar1
        case 6:  bottomBar6
        default: defaultBottomBar
        }
    }

    // MARK: - Navigation helpers
    private func advance() {
        Haptics.impact(.medium)
        withAnimation(pageAnimation) {
            if let currentIndex = activeScreens.firstIndex(of: currentScreen),
               currentIndex + 1 < activeScreens.count {
                currentScreen = activeScreens[currentIndex + 1]
            } else {
                currentScreen = activeScreens.last ?? 6
            }
            storedScreen = currentScreen
        }
    }

    private func goBack() {
        Haptics.selection()
        withAnimation(pageAnimation) {
            if let currentIndex = activeScreens.firstIndex(of: currentScreen),
               currentIndex > 0 {
                currentScreen = activeScreens[currentIndex - 1]
            } else {
                currentScreen = activeScreens.first ?? firstScreen
            }
            storedScreen = currentScreen
        }
    }

    // MARK: - Trouble helper
    private func showTroubleSheet(_ ctx: TroubleContext) {
        troubleContext = ctx
        showTrouble = true
    }

    // MARK: ─────────────────────────────────────────────
    // MARK: Screen 0 — Intro
    // ─────────────────────────────────────────────
    private var screen0Intro: some View {
        VStack(alignment: .leading, spacing: 0) {
            screenHeadline(isHebrew
                ? "מגדירים פעם אחת.\nאחר כך זה קורה לבד."
                : "Set it up once.\nThen it runs by itself.")

            bodyText(isHebrew
                ? "נגדיר לאייפון להעביר ל-SPENT את סכום העסקה ואת בית העסק אחרי תשלום."
                : "We'll tell your iPhone to send SPENT the amount and merchant after each payment.")
                .padding(.top, 20)

            Group {
                reassuranceLine(isHebrew
                    ? "זה קצר, ומגדירים את זה רק פעם אחת."
                    : "It's quick, and you only do it once.")
                reassuranceLine(isHebrew
                    ? "לא צריך לחבר ל-SPENT חשבון בנק או פרטי כרטיס."
                    : "No need to connect a bank account or card details to SPENT.")
            }
            .padding(.top, 16)
        }
    }

    private var bottomBar0: some View {
        VStack(spacing: 8) {
            primaryCTA(isHebrew ? "יאללה, נגדיר" : "Let's set it up") { advance() }

            Button(action: {
                Haptics.selection()
                onFinished()
            }) {
                Text(isHebrew ? "אעשה את זה אחר כך" : "I'll do this later")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(Color.textSecondary)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: ─────────────────────────────────────────────
    // MARK: Screen 1 — Open Shortcuts + Automation + Wallet (merged)
    // ─────────────────────────────────────────────
    private var screen1Shortcuts: some View {
        VStack(alignment: .leading, spacing: 0) {
            if usesNewShortcutsFlow {
                screenHeadline(isHebrew ? "יוצרים פעולה אוטומטית" : "Creating an automation")

                bodyText(isHebrew
                    ? "פתח את ״קיצורים״ ועבור ל־״פעולות אוטומטיות״.\nלחץ על +, בחר ״פעולה אוטומטית״, ומתוך הרשימה בחר ״ארנק״."
                    : "Open Shortcuts and go to \"Automations\".\nTap +, choose \"Automation\", and select \"Wallet\" from the list.")
                    .padding(.top, 16)

                // Visual sequence: פעולות אוטומטיות ↓ + ↓ פעולה אוטומטית ↓ ארנק
                VStack(alignment: .center, spacing: 3) {
                    flowStepPill(isHebrew ? "פעולות אוטומטיות" : "Automations")
                    flowArrowDown
                    flowStepPill("+")
                    flowArrowDown
                    flowStepPill(isHebrew ? "פעולה אוטומטית" : "Automation")
                    flowArrowDown
                    flowStepPill(isHebrew ? "ארנק" : "Wallet", highlight: true)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.jetBlack.opacity(0.035))
                )
                .padding(.top, 20)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isHebrew
                    ? "פעולות אוטומטיות, +, פעולה אוטומטית, ארנק"
                    : "Automations, +, Automation, Wallet")
            } else {
                screenHeadline(isHebrew ? "פותחים את ״קיצורים״" : "Open Shortcuts")

                bodyText(isHebrew
                    ? "זו אפליקציה של Apple שכבר נמצאת באייפון שלך."
                    : "This is an Apple app already on your iPhone.")
                    .padding(.top, 16)

                smallHint(isHebrew
                    ? "לא מוצא? חפש ״קיצורים״ בחיפוש של האייפון."
                    : "Can't find it? Search \"Shortcuts\" on your iPhone.")
                    .padding(.top, 6)

                // Step pills
                VStack(alignment: .leading, spacing: 12) {
                    stepDivider
                    stepRow(
                        label: isHebrew ? "בחר ״פעולה אוטומטית״" : "Choose \"Automation\"",
                        isFirst: true
                    )
                    stepRow(
                        label: isHebrew ? "אחר כך בחר ״ארנק״" : "Then choose \"Wallet\"",
                        isFirst: false
                    )
                    stepDivider

                    smallHint(isHebrew
                        ? "המסך יכול להיראות מעט אחרת בין גרסאות iOS. חפש לפי השם, לא לפי המיקום."
                        : "The screen may look slightly different across iOS versions. Search by name, not by location.")
                }
                .padding(.top, 20)
            }
        }
    }

    private func flowStepPill(_ title: String, highlight: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 13, weight: highlight ? .bold : .semibold, design: .rounded))
            .foregroundColor(highlight ? Color.themeOrange : Color.deepNavy)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(highlight ? Color.themeOrange.opacity(0.15) : Color.deepNavy.opacity(0.06))
            )
    }

    private var flowArrowDown: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(Color.textMuted)
            .padding(.vertical, 1)
    }

    private var bottomBar1: some View {
        VStack(spacing: 8) {
            #if os(iOS)
            if let url = URL(string: "shortcuts://") {
                Button(action: {
                    hasOpenedShortcuts = true
                    Haptics.impact(.medium)
                    UIApplication.shared.open(url)
                }) {
                    HStack(spacing: 6) {
                        MoneyIcon(.lightning, size: 18, color: .jetBlack)
                        Text(isHebrew ? "פתח את ״קיצורים״" : "Open Shortcuts")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                    }
                    .foregroundColor(.jetBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .frame(minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.themeOrange)
                    )
                }
                .buttonStyle(.plain)
                .bouncyPress(scale: 0.97)
            }
            #endif

            primaryCTA(isHebrew ? "אני שם" : "I'm there") { advance() }

            troubleButton(.shortcuts)
        }
    }

    // MARK: ─────────────────────────────────────────────
    // MARK: Screen 2 — Choose cards + Run Immediately
    // ─────────────────────────────────────────────
    private var screen2Card: some View {
        VStack(alignment: .leading, spacing: 0) {
            screenHeadline(isHebrew ? "בחר איך זה ירוץ" : "Choose how it runs")

            VStack(alignment: .leading, spacing: 10) {
                numberedInstruction(1, isHebrew ? "בחר את הכרטיסים שאיתם אתה משלם." : "Choose the cards you pay with.")
                numberedInstruction(2, isHebrew ? "בחר ״הפעלה מיידית״." : "Choose \"Run Immediately\".")
            }
            .padding(.top, 20)

            bodyText(isHebrew
                ? "כך SPENT תקבל את העסקה בלי שתצטרך לאשר בכל פעם."
                : "This way SPENT receives the transaction without asking you to confirm each time.")
                .padding(.top, 16)

            smallHint(isHebrew
                ? "ייתכן שתצטרך לגלול מעט למטה כדי לראות את ״הפעלה מיידית״."
                : "You may need to scroll down slightly to see \"Run Immediately\".")
                .padding(.top, 10)

            smallHint(isHebrew
                ? "אם מופיעה האפשרות ״קבלת עדכון כאשר פועל״, אפשר לכבות אותה כדי שלא תקבל התראה נוספת בכל עסקה."
                : "If you see \"Notify When Run\", you can turn it off to avoid extra notifications after each payment.")
                .padding(.top, 6)
        }
    }

    // MARK: ─────────────────────────────────────────────
    // MARK: Screen 3 — Add SPENT action
    // ─────────────────────────────────────────────
    private var screen3SPENT: some View {
        VStack(alignment: .leading, spacing: 0) {
            microLabel(isHebrew
                ? "SPENT כבר בפנים — נשאר לחבר שני פרטים"
                : "SPENT is in — just two details left to connect")
                .padding(.bottom, 10)

            screenHeadline(isHebrew ? "עכשיו מוסיפים את SPENT" : "Now add SPENT")

            if usesNewShortcutsFlow {
                bodyText(isHebrew
                    ? "בשורת החיפוש שמופיעה למטה, חפש ׳הקלטת עסקת Apple Pay׳ ולחץ עליה."
                    : "In the search bar at the bottom, search for \"Record Apple Pay Transaction\" and tap it.")
                    .padding(.top, 16)
            } else {
                bodyText(isHebrew
                    ? "בחר ״קיצור חדש״ (או ״קיצור ריק חדש״), הוסף פעולה, חפש SPENT ובחר:"
                    : "Choose \"New Shortcut\" (or \"New Blank Automation\"), tap Add Action, search for SPENT and pick:")
                    .padding(.top, 16)
            }

            // Action name pill — prominent
            actionNamePill(isHebrew ? "הקלטת עסקת Apple Pay" : "Record Apple Pay Transaction")
                .padding(.top, 14)

            if usesNewShortcutsFlow {
                verificationBlock(
                    question: isHebrew ? "אחרי הלחיצה" : "After tapping",
                    answer: isHebrew
                        ? "הפעולה של SPENT תתווסף למסך."
                        : "The SPENT action will be added to the screen."
                )
                .padding(.top, 20)
            } else {
                verificationBlock(
                    question: isHebrew ? "מה אתה אמור לראות?" : "What should you see?",
                    answer: isHebrew
                        ? "אמורה להופיע פעולה של SPENT עם שדות העסקה."
                        : "A SPENT action should appear with transaction fields."
                )
                .padding(.top, 20)
            }
        }
    }

    // MARK: ─────────────────────────────────────────────
    // MARK: Screen 4 — Connect Amount
    // ─────────────────────────────────────────────
    private var screen4Amount: some View {
        VStack(alignment: .leading, spacing: 0) {
            microLabel(isHebrew ? "עוד שני חיבורים קטנים וזהו." : "Two small connections and you're done.")
                .padding(.bottom, 10)

            screenHeadline(isHebrew ? "רק נחבר את הסכום" : "Connect the amount")

            bodyText(isHebrew
                ? "זה החלק שקצת פחות ברור ב״קיצורים״ — פשוט לחץ לפי הסדר הזה:"
                : "This part isn't obvious in Shortcuts — just tap in this order:")
                .padding(.top, 16)

            CaptureMappingDiagram(
                top: isHebrew ? "סכום עסקה" : "Transaction Amount",
                mid: isHebrew ? "קלט הקיצור" : "Shortcut Input",
                bot: isHebrew ? "כמות" : "Amount"
            )
            .padding(.top, 18)

            VStack(alignment: .leading, spacing: 8) {
                numberedInstruction(1, isHebrew ? "לחץ על השדה ״סכום עסקה״ בתוך הפעולה של SPENT." : "Tap the \"Transaction Amount\" field inside the SPENT action.")
                numberedInstruction(2, isHebrew ? "בחר ״קלט הקיצור״." : "Choose \"Shortcut Input\".")
                numberedInstruction(3, isHebrew ? "לחץ על הערך שנוסף." : "Tap the value that appeared.")
                numberedInstruction(4, isHebrew ? "בחר ״כמות״ מתוך פרטי העסקה." : "Choose \"Amount\" from the transaction details.")
            }
            .padding(.top, 18)

            quickCheckNote(
                isHebrew
                    ? "בדיקה קטנה: בכרטיס של ׳קלט הקיצור׳, השדה ׳סוג׳ צריך להיות מוגדר ל־׳עסקה׳."
                    : "Quick check: In the \"Shortcut Input\" card, the \"Type\" field should be set to \"Transaction\"."
            )
            .padding(.top, 14)

            verificationBlock(
                question: isHebrew ? "מה אתה אמור לראות עכשיו?" : "What should you see?",
                answer: isHebrew
                    ? "בשדה ״סכום עסקה״ אמור להופיע מידע שמגיע מהעסקה."
                    : "The Transaction Amount field should now show a value coming from the transaction."
            )
            .padding(.top, 16)
        }
    }

    // MARK: ─────────────────────────────────────────────
    // MARK: Screen 5 — Connect Merchant
    // ─────────────────────────────────────────────
    private var screen5Merchant: some View {
        VStack(alignment: .leading, spacing: 0) {
            microLabel(isHebrew ? "אחד נשאר." : "One left.")
                .padding(.bottom, 10)

            screenHeadline(isHebrew ? "ועכשיו בית העסק" : "Now the merchant")

            bodyText(isHebrew
                ? "אותו דבר בדיוק, רק עם שם בית העסק."
                : "Same steps, just with the merchant name.")
                .padding(.top, 16)

            CaptureMappingDiagram(
                top: isHebrew ? "בית העסק" : "Merchant",
                mid: isHebrew ? "קלט הקיצור" : "Shortcut Input",
                bot: isHebrew ? "בית העסק" : "Merchant"
            )
            .padding(.top, 18)

            VStack(alignment: .leading, spacing: 8) {
                numberedInstruction(1, isHebrew ? "לחץ על השדה ״בית העסק״." : "Tap the \"Merchant\" field.")
                numberedInstruction(2, isHebrew ? "בחר ״קלט הקיצור״." : "Choose \"Shortcut Input\".")
                numberedInstruction(3, isHebrew ? "לחץ על הערך שנוסף." : "Tap the value that appeared.")
                numberedInstruction(4, isHebrew ? "בחר ״בית העסק״ מתוך פרטי העסקה." : "Choose \"Merchant\" from the transaction details.")
            }
            .padding(.top, 18)

            quickCheckNote(
                isHebrew
                    ? "בדיקה קטנה: בכרטיס של ׳קלט הקיצור׳, השדה ׳סוג׳ צריך להיות מוגדר ל־׳עסקה׳."
                    : "Quick check: In the \"Shortcut Input\" card, the \"Type\" field should be set to \"Transaction\"."
            )
            .padding(.top, 14)

            verificationBlock(
                question: isHebrew ? "מה אתה אמור לראות עכשיו?" : "What should you see?",
                answer: isHebrew
                    ? "שני השדות אמורים להיות מחוברים לפרטי העסקה."
                    : "Both fields should now be connected to the transaction details."
            )
            .padding(.top, 16)
        }
    }

    // MARK: ─────────────────────────────────────────────
    // MARK: Screen 6 — Done
    // ─────────────────────────────────────────────
    private var screen6Done: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Subtle check mark
            ZStack {
                Circle()
                    .fill(Color.spentGreenSoft)
                    .frame(width: 56, height: 56)
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.spentGreen)
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
            .accessibilityHidden(true)

            screenHeadline(isHebrew
                ? "זהו. מעכשיו זה קורה לבד."
                : "That's it. It runs on its own now.")

            bodyText(isHebrew
                ? "בפעם הבאה שתשלם ב-Apple Pay, האייפון יעביר ל-SPENT את סכום העסקה ואת בית העסק."
                : "The next time you pay with Apple Pay, your iPhone will send SPENT the amount and merchant.")
                .padding(.top, 20)

            reassuranceLine(isHebrew
                ? "לא צריך לפתוח את SPENT אחרי כל תשלום."
                : "No need to open SPENT after each payment.")
                .padding(.top, 12)
        }
    }

    private var bottomBar6: some View {
        primaryCTA(isHebrew ? "חזרה ל-SPENT" : "Back to SPENT") {
            // Clear stored progress so next time starts fresh
            storedScreen = firstScreen
            onFinished()
        }
    }

    // MARK: - Default bottom bar (screens 2–5)
    private var defaultBottomBar: some View {
        VStack(spacing: 4) {
            primaryCTA(ctaLabel(for: currentScreen)) { advance() }
            troubleButton(troubleContextForScreen(currentScreen))
        }
    }

    private func ctaLabel(for screen: Int) -> String {
        if isHebrew {
            switch screen {
            case 2: return "סיימתי כאן"
            case 3: return "מצאתי את SPENT"
            case 4: return "חיברתי את הסכום"
            case 5: return "סיימתי"
            default: return "המשך"
            }
        } else {
            switch screen {
            case 2: return "Done here"
            case 3: return "Found SPENT"
            case 4: return "Connected the amount"
            case 5: return "Done"
            default: return "Continue"
            }
        }
    }

    private func troubleContextForScreen(_ screen: Int) -> TroubleContext {
        switch screen {
        case 1: return .shortcuts
        case 2: return .card
        case 3: return .spent
        case 4: return .amount
        case 5: return .merchant
        default: return .shortcuts
        }
    }

    // MARK: - Reusable sub-views
    private func screenHeadline(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .tracking(isHebrew ? -0.5 : -1.2)
            .foregroundColor(Color.jetBlack)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .rounded))
            .foregroundColor(Color.jetBlack.opacity(0.78))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(3)
    }

    private func smallHint(_ text: String) -> some View {
        Text(text)
            .font(.system(.footnote, design: .rounded))
            .foregroundColor(Color.textSecondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(2)
    }

    private func microLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundColor(Color.themeOrange)
            .multilineTextAlignment(.leading)
    }

    private func reassuranceLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.spentGreen)
                .padding(.top, 2)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(.footnote, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func numberedInstruction(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
                .frame(width: 22, height: 22)
                .background(Color.deepNavy.opacity(0.08))
                .clipShape(Circle())
                .accessibilityHidden(true)
            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundColor(Color.jetBlack.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(n). \(text)")
    }

    /// Prominent pill for the SPENT action name — never changed
    private func actionNamePill(_ label: String) -> some View {
        Text(label)
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundColor(Color.jetBlack)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.themeOrange.opacity(0.13))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.themeOrange.opacity(0.35), lineWidth: 1)
            )
    }

    private func verificationBlock(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(question)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundColor(Color.deepNavy)
            Text(answer)
                .font(.system(.footnote, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.jetBlack.opacity(0.04))
        )
    }

    private func quickCheckNote(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.themeOrange)
                .padding(.top, 1)
            Text(text)
                .font(.system(.footnote, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.themeOrange.opacity(0.08))
        )
    }

    private var stepDivider: some View {
        Divider()
            .overlay(Color.borderSubtle.opacity(0.5))
    }

    private func stepRow(label: String, isFirst: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.deepNavy.opacity(0.12))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(label)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundColor(Color.deepNavy)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func troubleButton(_ ctx: TroubleContext) -> some View {
        Button(action: {
            showTroubleSheet(ctx)
        }) {
            Text(isHebrew ? "נתקעת?" : "Stuck?")
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundColor(Color.textSecondary)
                .frame(minHeight: 36)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Primary CTA
    @Environment(\.accessibilityReduceMotion) private var reduceMotionCTA
    private func primaryCTA(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
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
        .accessibilityAddTraits(.isButton)
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

// MARK: - CaptureMappingDiagram
/// Vertical flow: top → mid → bot.
/// Vertical layout is RTL-safe — no horizontal arrows to flip.
struct CaptureMappingDiagram: View {
    var top: String
    var mid: String
    var bot: String

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            pill(top, style: .field)
            arrow
            pill(mid, style: .input)
            arrow
            pill(bot, style: .field)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(top) → \(mid) → \(bot)")
    }

    private var arrow: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color.textMuted)
            .padding(.vertical, 4)
    }

    private enum PillStyle { case field, input }

    private func pill(_ label: String, style: PillStyle) -> some View {
        Text(label)
            .font(.system(size: 14, weight: style == .input ? .bold : .semibold, design: .rounded))
            .foregroundColor(style == .input ? Color.spentGreen : Color.deepNavy)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(style == .input ? Color.spentGreenSoft : Color.deepNavy.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(style == .input ? Color.spentGreen.opacity(0.3) : Color.deepNavy.opacity(0.15), lineWidth: 1)
            )
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
                    // 1. Prominent golden rule banner
                    goldenRuleBanner

                    // 2. Context-aware targeted help for the current step
                    contextHelpSection

                    Divider().padding(.horizontal, 20)

                    // 3. Fallback & general tips
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
                ? "אם אתה לא רואה כפתור ברור — חפש למטה את מה שאתה רוצה ולחץ עליו."
                : "If you don't see an obvious button — search at the bottom of the screen and tap it.")
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
                    ? "אחרי לחיצה על +, בחר ׳פעולה אוטומטית׳, ולאחר מכן בחר ׳ארנק׳."
                    : "After tapping +, choose \"Automation\", and then choose \"Wallet\".")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)

                VStack(alignment: .center, spacing: 3) {
                    stepPill("+")
                    arrowDown
                    stepPill(isHebrew ? "פעולה אוטומטית" : "Automation")
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
                    ? "+, בחר פעולה אוטומטית, בחר ארנק"
                    : "+, choose Automation, choose Wallet")
            } else {
                Text(isHebrew
                    ? "באפליקציה ׳קיצורים׳: עבור ללשונית פעולה אוטומטית, לחץ על + ובחר ׳עסקה׳ (תחת ארנק)."
                    : "In Shortcuts: go to the Automation tab, tap + and choose \"Transaction\" (under Wallet).")
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
                .fixedSize(horizontal: false, vertical: true)
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

                VStack(alignment: .center, spacing: 3) {
                    stepPill(isHebrew ? "חיפוש למטה" : "Search at bottom")
                    arrowDown
                    stepPill(isHebrew ? "SPENT" : "SPENT")
                    arrowDown
                    stepPill(isHebrew ? "הקלטת עסקת Apple Pay" : "Record Apple Pay Transaction", highlight: true)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.jetBlack.opacity(0.035))
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isHebrew
                    ? "חיפוש למטה, SPENT, הקלטת עסקת Apple Pay"
                    : "Search at bottom, SPENT, Record Apple Pay Transaction")
            } else {
                Text(isHebrew
                    ? "בחר ׳קיצור חדש׳ או ׳קיצור ריק חדש׳, לחץ על ׳הוסף פעולה׳, חפש SPENT ובחר ׳הקלטת עסקת Apple Pay׳."
                    : "Choose \"New Shortcut\" or \"New Blank Automation\", tap Add Action, search for SPENT and pick \"Record Apple Pay Transaction\".")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                ? "לחץ על שדה ׳סכום עסקה׳ בתוך הפעולה של SPENT ← בחר ׳קלט הקיצור׳ ← לחץ על הערך שנוסף ← בחר ׳כמות׳ מתוך פרטי העסקה."
                : "Tap the \"Transaction Amount\" field inside the SPENT action → choose \"Shortcut Input\" → tap the added value → choose \"Amount\" from the transaction details.")
                .font(.system(.body, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            VStack(alignment: .center, spacing: 3) {
                stepPill(isHebrew ? "סכום עסקה" : "Transaction Amount")
                arrowDown
                stepPill(isHebrew ? "קלט הקיצור" : "Shortcut Input")
                arrowDown
                stepPill(isHebrew ? "כמות" : "Amount", highlight: true)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.jetBlack.opacity(0.035))
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isHebrew
                ? "סכום עסקה, קלט הקיצור, כמות"
                : "Transaction Amount, Shortcut Input, Amount")
        }
        .padding(.horizontal, 20)
    }

    private var merchantHelp: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isHebrew ? "איך לחבר את בית העסק?" : "How to connect the merchant?")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundColor(Color.deepNavy)

            Text(isHebrew
                ? "לחץ על שדה ׳בית העסק׳ בתוך הפעולה של SPENT ← בחר ׳קלט הקיצור׳ ← לחץ על הערך שנוסף ← בחר ׳בית העסק׳ מתוך פרטי העסקה."
                : "Tap the \"Merchant\" field inside the SPENT action → choose \"Shortcut Input\" → tap the added value → choose \"Merchant\" from the transaction details.")
                .font(.system(.body, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            VStack(alignment: .center, spacing: 3) {
                stepPill(isHebrew ? "בית העסק" : "Merchant")
                arrowDown
                stepPill(isHebrew ? "קלט הקיצור" : "Shortcut Input")
                arrowDown
                stepPill(isHebrew ? "בית העסק" : "Merchant", highlight: true)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.jetBlack.opacity(0.035))
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isHebrew
                ? "בית העסק, קלט הקיצור, בית העסק"
                : "Merchant, Shortcut Input, Merchant")
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

// MARK: - Previews
#Preview("Guide • Hebrew • Intro") {
    AutomaticCaptureSetupGuide(skipIntro: false, onFinished: {})
        .environmentObject(LocalizationManager.shared)
}

#Preview("Guide • Hebrew • Screen 1") {
    AutomaticCaptureSetupGuide(skipIntro: true, onFinished: {})
        .environmentObject(LocalizationManager.shared)
}

#Preview("Guide • Hebrew • Amount") {
    let g = AutomaticCaptureSetupGuide(skipIntro: true, onFinished: {})
    // Force screen 4 via AppStorage for preview
    return g.environmentObject(LocalizationManager.shared)
        .onAppear { UserDefaults.standard.set(4, forKey: "spent.capture.guide.screen") }
}

#Preview("Guide • English") {
    AutomaticCaptureSetupGuide(skipIntro: false, onFinished: {})
        .environmentObject({
            let m = LocalizationManager.shared
            m.language = .english
            return m
        }())
}

#Preview("CaptureMappingDiagram • Hebrew") {
    CaptureMappingDiagram(top: "כמות", mid: "קלט הקיצור", bot: "כמות")
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
}
