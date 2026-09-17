import SwiftUI

/// Status screen for Automatic Capture when configured or detected.
/// Restrained, quiet, functional design adhering strictly to SPENT Design Constitution.
public struct AutomaticCaptureStatusView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager

    @State private var showSetupGuide: Bool = false
    @State private var setupGuideEntryMode: FastSetupEntryMode = .restart
    @State private var showManualGuide: Bool = false
    @State private var showTrouble: Bool = false

    private var isHebrew: Bool { l10n.language == .hebrew }
    private var state: AutomaticCaptureState { AutomaticCaptureStateStore.state() }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(mainStateTitle)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(bodyDescription)
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundColor(Color.textSecondary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)

                            if case .captureDetected(let date) = state {
                                Text(AutomaticCaptureStateStore.formatLastDetected(date: date, isHebrew: isHebrew))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.textMuted)
                                    .padding(.top, 6)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer(minLength: 16)

                    // Action buttons
                    bottomActionButtons
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle(isHebrew ? "קליטה אוטומטית" : "Automatic Capture")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isHebrew ? "סגור" : "Close") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                }
            }
        }
        .environment(\.layoutDirection, isHebrew ? .rightToLeft : .leftToRight)
        .fullScreenCover(isPresented: $showSetupGuide) {
            ApplePayGuideSheet(entryMode: setupGuideEntryMode)
                .environmentObject(l10n)
        }
        .fullScreenCover(isPresented: $showManualGuide) {
            AutomaticCaptureSetupGuide(
                forceManualGuide: true,
                skipIntro: false,
                showCloseButton: true,
                onFinished: { showManualGuide = false }
            )
            .environmentObject(l10n)
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

    // MARK: - Action Buttons
    @ViewBuilder
    private var bottomActionButtons: some View {
        VStack(spacing: 12) {
            switch state {
            case .captureDetected:
                Button(action: {
                    Haptics.impact(.medium)
                    setupGuideEntryMode = .restart
                    showSetupGuide = true
                }) {
                    Text(isHebrew ? "הוסף קיצור מחדש" : "Add Shortcut Again")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.deepNavy)
                        )
                }
                .buttonStyle(.plain)
                .bouncyPress()

                Button(action: {
                    Haptics.selection()
                    showManualGuide = true
                }) {
                    Text(isHebrew ? "מדריך הגדרה ידנית" : "Manual Setup Guide")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)

                Button(action: {
                    Haptics.selection()
                    showTrouble = true
                }) {
                    Text(isHebrew ? "פתרון בעיות" : "Troubleshooting")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textMuted)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)

            case .configuredAwaitingFirstCapture:
                Button(action: {
                    Haptics.impact(.medium)
                    setupGuideEntryMode = .restart
                    showSetupGuide = true
                }) {
                    Text(isHebrew ? "הוסף קיצור מחדש" : "Add Shortcut Again")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.deepNavy)
                        )
                }
                .buttonStyle(.plain)
                .bouncyPress()

                Button(action: {
                    Haptics.selection()
                    showManualGuide = true
                }) {
                    Text(isHebrew ? "מדריך הגדרה ידנית" : "Manual Setup Guide")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)

                Button(action: {
                    Haptics.selection()
                    showTrouble = true
                }) {
                    Text(isHebrew ? "לא עובד?" : "Not working?")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textMuted)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)

            case .setupInProgress:
                Button(action: {
                    Haptics.impact(.medium)
                    setupGuideEntryMode = .resume
                    showSetupGuide = true
                }) {
                    Text(isHebrew ? "המשך הגדרה" : "Continue Setup")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.deepNavy)
                        )
                }
                .buttonStyle(.plain)
                .bouncyPress()

                Button(action: {
                    Haptics.selection()
                    showManualGuide = true
                }) {
                    Text(isHebrew ? "מדריך הגדרה ידנית" : "Manual Setup Guide")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)

            case .notConfigured:
                Button(action: {
                    Haptics.impact(.medium)
                    setupGuideEntryMode = .restart
                    showSetupGuide = true
                }) {
                    Text(isHebrew ? "הגדר קליטה אוטומטית" : "Set Up Automatic Capture")
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
                    showManualGuide = true
                }) {
                    Text(isHebrew ? "מדריך הגדרה ידנית" : "Manual Setup Guide")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Copy resolution
    private var mainStateTitle: String {
        switch state {
        case .captureDetected:
            return RemoteConfigService.shared.localizedCopy(
                key: "capture.active.title",
                fallbackHe: "קליטה אוטומטית פעילה",
                fallbackEn: "Automatic capture active",
                isHebrew: isHebrew
            )
        case .configuredAwaitingFirstCapture:
            return RemoteConfigService.shared.localizedCopy(
                key: "capture.waiting.title",
                fallbackHe: "מחכים לקליטה הראשונה",
                fallbackEn: "Waiting for first capture",
                isHebrew: isHebrew
            )
        case .setupInProgress:
            return isHebrew ? "המשך הגדרה" : "Continue setup"
        case .notConfigured:
            return isHebrew ? "קליטה אוטומטית" : "Automatic Capture"
        }
    }

    private var bodyDescription: String {
        switch state {
        case .captureDetected:
            return isHebrew
                ? "SPENT כבר קיבלה הפעלה דרך הפעולה האוטומטית באייפון."
                : "SPENT has already received an event through the automatic action on your iPhone."
        case .configuredAwaitingFirstCapture:
            return isHebrew
                ? "אחרי התשלום הבא ב-Apple Pay נוודא שהקליטה מגיעה ל-SPENT."
                : "After your next Apple Pay payment, we'll verify that captures are reaching SPENT."
        case .setupInProgress:
            return isHebrew
                ? "התחלת להגדיר קליטה אוטומטית. אפשר להמשיך עם הקיצור המוכן או לעבור להגדרה ידנית."
                : "You've started setting up automatic capture. You can continue with the shortcut or switch to manual setup."
        case .notConfigured:
            return isHebrew
                ? "הגדרה קצרה באייפון, ואחרי זה ההוצאות יכולות להיכנס ל-SPENT לבד."
                : "A quick iPhone setup, and then expenses can enter SPENT automatically."
        }
    }
}
