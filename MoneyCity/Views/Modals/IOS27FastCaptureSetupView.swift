import SwiftUI

/// Fast Setup walkthrough for iOS 27+ Automatic Capture.
/// Opens a user-tested pre-configured iCloud Shortcut with one tap,
/// while keeping the 13-step manual setup fully accessible.
public struct IOS27FastCaptureSetupView: View {
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
    @Environment(\.scenePhase) private var scenePhase

    public enum FastSetupStep: Equatable {
        case initial
        case shortcutAddedPrompt
        case enabledConfirmation
    }

    public static let automationsURL = URL(string: "shortcuts://automations")!
    public static let fallbackShortcutsURL = URL(string: "shortcuts://")!

    @State private var currentStep: FastSetupStep = .initial
    @State private var didTapOpenShortcut: Bool = false
    @State private var didTapOpenAutomations: Bool = false
    @State private var isShowingManualGuide: Bool = false
    @State private var showShortcutTroubleOptions: Bool = false
    @State private var showAutomationsTroubleOptions: Bool = false

    private var isHebrew: Bool { l10n.language == .hebrew }

    public var body: some View {
        if isShowingManualGuide {
            // Manual 13-step setup (no routing loop, preserves skipIntro)
            IOS27CaptureSetupGuideView(
                skipIntro: skipIntro,
                showCloseButton: showCloseButton,
                onFinished: onFinished
            )
        } else {
            ZStack(alignment: .top) {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            switch currentStep {
                            case .initial:
                                initialContent
                            case .shortcutAddedPrompt:
                                shortcutAddedPromptContent
                            case .enabledConfirmation:
                                enabledConfirmationContent
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        .frame(maxWidth: 520, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer(minLength: 16)

                    bottomBar
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                        .background(Color.appBackground)
                }
            }
            .environment(\.layoutDirection, isHebrew ? .rightToLeft : .leftToRight)
            .onAppear {
                updateStepOnAppear()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active && (oldPhase == .background || oldPhase == .inactive) {
                    handleReturnToApp()
                }
            }
            .confirmationDialog(
                isHebrew ? "לא הצלחת להוסיף את הקיצור?" : "Couldn't add the shortcut?",
                isPresented: $showShortcutTroubleOptions,
                titleVisibility: .visible
            ) {
                Button(isHebrew ? "נסה שוב" : "Try Again") {
                    openShortcutLink()
                }
                Button(isHebrew ? "הגדרה ידנית" : "Manual Setup") {
                    switchToManualSetup()
                }
                Button(isHebrew ? "פתח את קיצורים" : "Open Shortcuts") {
                    openShortcutsApp()
                }
                Button(isHebrew ? "ביטול" : "Cancel", role: .cancel) {}
            } message: {
                Text(isHebrew
                    ? "אפשר לפתוח את הקישור מחדש, לעבור להגדרה ידנית, או לפתוח את קיצורים."
                    : "You can reopen the link, switch to manual setup, or open Shortcuts.")
            }
            .confirmationDialog(
                isHebrew ? "חפש את SPENT בפעולות האוטומטיות" : "Look for SPENT in Automations",
                isPresented: $showAutomationsTroubleOptions,
                titleVisibility: .visible
            ) {
                Button(isHebrew ? "פתח שוב פעולות אוטומטיות" : "Open Automations Again") {
                    openAutomationsLink()
                }
                Button(isHebrew ? "הגדרה ידנית" : "Manual Setup") {
                    switchToManualSetup()
                }
                Button(isHebrew ? "פתח את קיצורים" : "Open Shortcuts") {
                    openShortcutsApp()
                }
                Button(isHebrew ? "ביטול" : "Cancel", role: .cancel) {}
            } message: {
                Text(isHebrew
                    ? "הקיצור שהוספת אמור להופיע שם. פתח אותו והפעל אותו."
                    : "The shortcut you added should appear there. Open it and turn it on.")
            }
        }
    }

    // MARK: - Lifecycle Handlers
    private func updateStepOnAppear() {
        if AutomaticCaptureStateStore.hasLastDetectedCapture {
            onFinished()
            return
        }
        if AutomaticCaptureStateStore.hasFreshFastSetupOpenedAutomations() {
            currentStep = .enabledConfirmation
        } else if AutomaticCaptureStateStore.hasFreshFastSetupProgress() {
            currentStep = .shortcutAddedPrompt
        } else {
            currentStep = .initial
        }
    }

    private func handleReturnToApp() {
        if AutomaticCaptureStateStore.hasLastDetectedCapture {
            onFinished()
            return
        }
        let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.25)
        if currentStep == .initial && (didTapOpenShortcut || AutomaticCaptureStateStore.hasFreshFastSetupProgress()) {
            didTapOpenShortcut = false
            withAnimation(animation) {
                currentStep = .shortcutAddedPrompt
            }
        } else if currentStep == .shortcutAddedPrompt && (didTapOpenAutomations || AutomaticCaptureStateStore.hasFreshFastSetupOpenedAutomations()) {
            didTapOpenAutomations = false
            withAnimation(animation) {
                currentStep = .enabledConfirmation
            }
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Spacer()

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
            }
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Screen Contents
    private var initialContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isHebrew ? "קליטה אוטומטית" : "Automatic Capture")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color.jetBlack)
                .fixedSize(horizontal: false, vertical: true)

            Text(isHebrew
                ? "הגדרה קצרה באייפון, ואחרי זה ההוצאות יכולות להיכנס ל-SPENT לבד."
                : "A quick iPhone setup, and then expenses can enter SPENT automatically.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var shortcutAddedPromptContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isHebrew ? "הקיצור נוסף?" : "Did you add the shortcut?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color.jetBlack)
                .fixedSize(horizontal: false, vertical: true)

            Text(isHebrew
                ? "אם הוספת את הקיצור של SPENT, נשאר רק להפעיל אותו בפעולות האוטומטיות."
                : "If you added the SPENT shortcut, all that's left is enabling it in Automations.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var enabledConfirmationContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isHebrew ? "הפעלת את קיצור SPENT?" : "Did you enable the SPENT shortcut?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color.jetBlack)
                .fixedSize(horizontal: false, vertical: true)

            Text(isHebrew
                ? "אם קיצור SPENT מופעל בפעולות האוטומטיות, ההגדרה הסתיימה."
                : "If the SPENT shortcut is enabled in Automations, setup is complete.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Bottom Bar CTAs
    private var bottomBar: some View {
        VStack(spacing: 12) {
            switch currentStep {
            case .initial:
                initialBottomBar
            case .shortcutAddedPrompt:
                shortcutAddedPromptBottomBar
            case .enabledConfirmation:
                enabledConfirmationBottomBar
            }
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    private var initialBottomBar: some View {
        VStack(spacing: 12) {
            Button(action: openShortcutLink) {
                Text(isHebrew ? "הפעל קליטה אוטומטית" : "Enable Automatic Capture")
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

            Button(action: switchToManualSetup) {
                Text(isHebrew ? "הגדרה ידנית" : "Manual Setup")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    private var shortcutAddedPromptBottomBar: some View {
        VStack(spacing: 12) {
            Button(action: openAutomationsLink) {
                Text(isHebrew ? "פתח פעולות אוטומטיות" : "Open Automations")
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
                showShortcutTroubleOptions = true
            }) {
                Text(isHebrew ? "לא הצלחתי להוסיף את הקיצור" : "Couldn't add the shortcut")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    private var enabledConfirmationBottomBar: some View {
        VStack(spacing: 12) {
            Button(action: confirmSetupCompleted) {
                Text(isHebrew ? "הפעלתי" : "I enabled it")
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
                showAutomationsTroubleOptions = true
            }) {
                Text(isHebrew ? "לא מצאתי את הקיצור" : "Couldn't find the shortcut")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions
    private func openShortcutLink() {
        Haptics.impact(.medium)
        AutomaticCaptureStateStore.markFastSetupStarted(at: Date())
        didTapOpenShortcut = true
        let url = RemoteConfigService.shared.resolvedShortcutURL
        UIApplication.shared.open(url)
    }

    private func openAutomationsLink() {
        Haptics.impact(.medium)
        AutomaticCaptureStateStore.markFastSetupOpenedAutomations(at: Date())
        didTapOpenAutomations = true
        UIApplication.shared.open(Self.automationsURL, options: [:]) { success in
            if !success {
                DispatchQueue.main.async {
                    UIApplication.shared.open(Self.fallbackShortcutsURL)
                }
            }
        }
    }

    private func switchToManualSetup() {
        Haptics.selection()
        AutomaticCaptureStateStore.clearFastSetupProgress()
        isShowingManualGuide = true
    }

    private func confirmSetupCompleted() {
        Haptics.notify(.success)
        AutomaticCaptureStateStore.markSetupCompleted(at: Date())
        AutomaticCaptureStateStore.clearFastSetupProgress()
        onFinished()
    }

    private func openShortcutsApp() {
        Haptics.selection()
        UIApplication.shared.open(Self.fallbackShortcutsURL)
    }
}

#Preview("Fast Setup • Initial") {
    IOS27FastCaptureSetupView(onFinished: {})
        .environmentObject(LocalizationManager.shared)
}
