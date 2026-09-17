import SwiftUI

/// Status screen for Automatic Capture when configured or detected.
/// Restrained, quiet, functional design adhering strictly to SPENT Design Constitution.
public struct AutomaticCaptureStatusView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager

    @State private var showSetupGuide: Bool = false
    @State private var showTrouble: Bool = false

    private var isHebrew: Bool { l10n.language == .hebrew }
    private var state: AutomaticCaptureState { AutomaticCaptureStateStore.state() }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 24)

                    // Status Header
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

                    Spacer()

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
            ApplePayGuideSheet()
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
        switch state {
        case .captureDetected:
            // Working state: calm screen with only a quiet secondary action
            Button(action: {
                Haptics.selection()
                showTrouble = true
            }) {
                Text(isHebrew ? "פתרון בעיות" : "Troubleshooting")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)

        case .configuredAwaitingFirstCapture:
            Button(action: {
                Haptics.selection()
                showTrouble = true
            }) {
                Text(isHebrew ? "לא עובד?" : "Not working?")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)

        case .setupInProgress:
            Button(action: {
                Haptics.impact(.medium)
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

        case .notConfigured:
            Button(action: {
                Haptics.impact(.medium)
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
