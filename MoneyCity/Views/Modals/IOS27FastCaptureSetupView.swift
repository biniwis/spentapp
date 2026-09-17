import SwiftUI

/// Fast Setup walkthrough for iOS 27+ Automatic Capture.
/// Opens a user-tested pre-configured iCloud Shortcut with one tap,
/// while keeping the 13-step manual setup fully accessible.
public struct IOS27FastCaptureSetupView: View {
    public var entryMode: FastSetupEntryMode
    public var skipIntro: Bool
    public var showCloseButton: Bool
    public var onFinished: () -> Void

    public init(
        entryMode: FastSetupEntryMode = .restart,
        skipIntro: Bool = false,
        showCloseButton: Bool = true,
        onFinished: @escaping () -> Void
    ) {
        self.entryMode = entryMode
        self.skipIntro = skipIntro
        self.showCloseButton = showCloseButton
        self.onFinished = onFinished
    }

    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    public enum FastSetupStep: Equatable {
        case initial
        case shortcutAddedCheckpoint
        case openAutomationsPrompt
        case automationsEnabledCheckpoint
        case captureDetectedSuccess
    }

    public static let automationsURL = URL(string: "shortcuts://automations")!
    public static let fallbackShortcutsURL = URL(string: "shortcuts://")!

    @State private var currentStep: FastSetupStep = .initial
    @State private var sessionStartedAt: Date = Date()
    @State private var didTapOpenShortcut: Bool = false
    @State private var didTapOpenAutomations: Bool = false
    @State private var isShowingManualGuide: Bool = false

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
                            case .shortcutAddedCheckpoint:
                                shortcutAddedCheckpointContent
                            case .openAutomationsPrompt:
                                openAutomationsPromptContent
                            case .automationsEnabledCheckpoint:
                                automationsEnabledCheckpointContent
                            case .captureDetectedSuccess:
                                captureDetectedSuccessContent
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
        }
    }

    // MARK: - Lifecycle Handlers
    private func updateStepOnAppear() {
        sessionStartedAt = Date()

        switch entryMode {
        case .restart:
            AutomaticCaptureStateStore.clearFastSetupProgress()
            currentStep = .initial
        case .resume:
            if AutomaticCaptureStateStore.hasFreshFastSetupOpenedAutomations() {
                currentStep = .automationsEnabledCheckpoint
            } else if AutomaticCaptureStateStore.hasFreshFastSetupProgress() {
                currentStep = .shortcutAddedCheckpoint
            } else {
                currentStep = .initial
            }
        }
    }

    private func handleReturnToApp() {
        let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.25)

        // If a brand new capture arrived during this setup session, show success screen with "סיום" instead of auto-dismissing
        if let lastCapture = AutomaticCaptureStateStore.lastDetectedDate, lastCapture > sessionStartedAt {
            withAnimation(animation) {
                currentStep = .captureDetectedSuccess
            }
            return
        }

        if currentStep == .initial && didTapOpenShortcut {
            didTapOpenShortcut = false
            withAnimation(animation) {
                currentStep = .shortcutAddedCheckpoint
            }
        } else if currentStep == .openAutomationsPrompt && didTapOpenAutomations {
            didTapOpenAutomations = false
            withAnimation(animation) {
                currentStep = .automationsEnabledCheckpoint
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

    private var shortcutAddedCheckpointContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isHebrew ? "הוספת את קיצור SPENT?" : "Did you add the SPENT shortcut?")
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

    private var openAutomationsPromptContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isHebrew ? "עכשיו מפעילים את קיצור SPENT" : "Now enable the SPENT shortcut")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color.jetBlack)
                .fixedSize(horizontal: false, vertical: true)

            Text(isHebrew
                ? "נפתח את אזור הפעולות האוטומטיות באפליקציית קיצורים, ושם רק מפעילים את הקיצור שהוספת."
                : "We'll open the Automations area in Shortcuts, and simply turn on the shortcut you just added.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var automationsEnabledCheckpointContent: some View {
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

    private var captureDetectedSuccessContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isHebrew ? "הקליטה כבר עובדת" : "Automatic Capture is Working")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color.jetBlack)
                .fixedSize(horizontal: false, vertical: true)

            Text(isHebrew
                ? "עסקה נקלטה בהצלחה ב-SPENT. הכול מחובר ומוכן לשימוש."
                : "A transaction was successfully captured in SPENT. Everything is connected and ready to use.")
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
            case .shortcutAddedCheckpoint:
                shortcutAddedCheckpointBottomBar
            case .openAutomationsPrompt:
                openAutomationsPromptBottomBar
            case .automationsEnabledCheckpoint:
                automationsEnabledCheckpointBottomBar
            case .captureDetectedSuccess:
                captureDetectedSuccessBottomBar
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

    private var shortcutAddedCheckpointBottomBar: some View {
        VStack(spacing: 10) {
            Button(action: {
                Haptics.impact(.medium)
                let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.25)
                withAnimation(animation) {
                    currentStep = .openAutomationsPrompt
                }
            }) {
                Text(isHebrew ? "הצלחתי" : "I succeeded")
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

            Button(action: openShortcutLink) {
                Text(isHebrew ? "נסה שוב" : "Try Again")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.jetBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.jetBlack.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
            .bouncyPress()

            Button(action: {
                Haptics.selection()
                AutomaticCaptureStateStore.clearFastSetupProgress()
                let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.25)
                withAnimation(animation) {
                    currentStep = .initial
                }
            }) {
                Text(isHebrew ? "חזרה" : "Back")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    private var openAutomationsPromptBottomBar: some View {
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
                AutomaticCaptureStateStore.clearFastSetupOpenedAutomations()
                let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.25)
                withAnimation(animation) {
                    currentStep = .shortcutAddedCheckpoint
                }
            }) {
                Text(isHebrew ? "חזרה" : "Back")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    private var automationsEnabledCheckpointBottomBar: some View {
        VStack(spacing: 10) {
            Button(action: confirmSetupCompleted) {
                Text(isHebrew ? "הצלחתי" : "I succeeded")
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

            Button(action: openAutomationsLink) {
                Text(isHebrew ? "נסה שוב" : "Try Again")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.jetBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.jetBlack.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
            .bouncyPress()

            Button(action: {
                Haptics.selection()
                AutomaticCaptureStateStore.clearFastSetupOpenedAutomations()
                let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.25)
                withAnimation(animation) {
                    currentStep = .openAutomationsPrompt
                }
            }) {
                Text(isHebrew ? "חזרה" : "Back")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    private var captureDetectedSuccessBottomBar: some View {
        VStack(spacing: 12) {
            Button(action: confirmSetupCompleted) {
                Text(isHebrew ? "סיום" : "Done")
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
}

#Preview("Fast Setup • Initial") {
    IOS27FastCaptureSetupView(onFinished: {})
        .environmentObject(LocalizationManager.shared)
}

