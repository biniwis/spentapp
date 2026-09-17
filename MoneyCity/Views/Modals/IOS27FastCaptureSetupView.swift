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

    @State private var didTapOpenShortcut: Bool = false
    @State private var showingConfirmation: Bool = false
    @State private var isShowingManualGuide: Bool = false
    @State private var showTroubleOptions: Bool = false

    private var isHebrew: Bool { l10n.language == .hebrew }

    public var body: some View {
        if isShowingManualGuide {
            // Manual 13-step setup (no routing loop)
            IOS27CaptureSetupGuideView(
                skipIntro: false,
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
                            if showingConfirmation {
                                confirmationContent
                            } else {
                                initialContent
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
                if AutomaticCaptureStateStore.hasFreshFastSetupProgress() {
                    showingConfirmation = true
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active && (oldPhase == .background || oldPhase == .inactive) {
                    if didTapOpenShortcut || AutomaticCaptureStateStore.hasFreshFastSetupProgress() {
                        withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.25)) {
                            showingConfirmation = true
                        }
                    }
                }
            }
            .confirmationDialog(
                isHebrew ? "פתרונות אפשריים" : "Troubleshooting Options",
                isPresented: $showTroubleOptions,
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

    // MARK: - Initial Screen Content
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

    // MARK: - Confirmation Screen Content
    private var confirmationContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isHebrew ? "הוספת את הקיצור?" : "Did you add the shortcut?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color.jetBlack)
                .fixedSize(horizontal: false, vertical: true)

            Text(isHebrew
                ? "אם הוספת את הקיצור באייפון, נשאר רק לחכות לתשלום הבא כדי לוודא שהכול עובד."
                : "If you added the shortcut on your iPhone, all that's left is waiting for the next payment to confirm everything works.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Bottom Bar CTAs
    private var bottomBar: some View {
        VStack(spacing: 12) {
            if showingConfirmation {
                // Confirmation State
                Button(action: confirmShortcutAdded) {
                    Text(isHebrew ? "כן, הוספתי" : "Yes, I added it")
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
                    showTroubleOptions = true
                }) {
                    Text(isHebrew ? "לא עבד לי" : "Didn't work")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)

            } else {
                // Initial State
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
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions
    private func openShortcutLink() {
        Haptics.impact(.medium)
        AutomaticCaptureStateStore.markFastSetupStarted(at: Date())
        didTapOpenShortcut = true
        let url = RemoteConfigService.shared.resolvedShortcutURL
        UIApplication.shared.open(url)
    }

    private func switchToManualSetup() {
        Haptics.selection()
        AutomaticCaptureStateStore.clearFastSetupProgress()
        isShowingManualGuide = true
    }

    private func confirmShortcutAdded() {
        Haptics.notify(.success)
        AutomaticCaptureStateStore.markSetupCompleted(at: Date())
        AutomaticCaptureStateStore.clearFastSetupProgress()
        onFinished()
    }

    private func openShortcutsApp() {
        Haptics.selection()
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview("Fast Setup • Initial") {
    IOS27FastCaptureSetupView(onFinished: {})
        .environmentObject(LocalizationManager.shared)
}
