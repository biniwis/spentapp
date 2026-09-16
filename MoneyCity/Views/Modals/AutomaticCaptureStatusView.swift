import SwiftUI

/// Status screen for Automatic Capture when configured or detected.
/// Restrained, quiet, functional design adhering strictly to SPENT Design Constitution.
public struct AutomaticCaptureStatusView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager

    @State private var showSetupGuide: Bool = false

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
                    VStack(spacing: 10) {
                        Button(action: openShortcuts) {
                            Text(isHebrew ? "פתח את קיצורים" : "Open Shortcuts")
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

                        Button(action: replaySetupGuide) {
                            Text(isHebrew ? "מדריך ההגדרה" : "Setup guide")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.jetBlack.opacity(0.05))
                                )
                        }
                        .buttonStyle(.plain)
                    }
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
    }

    // MARK: - Copy resolution
    private var mainStateTitle: String {
        switch state {
        case .captureDetected:
            return isHebrew ? "זוהתה קליטה" : "Capture detected"
        case .configuredAwaitingFirstCapture, .notConfigured, .setupInProgress:
            return isHebrew ? "מחכה לקליטה הראשונה" : "Waiting for first capture"
        }
    }

    private var bodyDescription: String {
        switch state {
        case .captureDetected:
            return isHebrew
                ? "SPENT כבר קיבלה הפעלה דרך הפעולה האוטומטית באייפון."
                : "SPENT has already received an event through the automatic action on your iPhone."
        case .configuredAwaitingFirstCapture, .notConfigured, .setupInProgress:
            return isHebrew
                ? "אחרי התשלום הבא ב-Apple Pay נוכל לוודא שהקליטה מגיעה ל-SPENT."
                : "After your next Apple Pay payment, we'll be able to confirm that captures are reaching SPENT."
        }
    }

    // MARK: - Actions
    private func openShortcuts() {
        Haptics.impact(.medium)
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }
    }

    private func replaySetupGuide() {
        Haptics.selection()
        AutomaticCaptureStateStore.resetGuideProgress()
        showSetupGuide = true
    }
}
