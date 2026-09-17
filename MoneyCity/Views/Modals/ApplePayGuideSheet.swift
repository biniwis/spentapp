import SwiftUI

/// Thin wrapper — presents AutomaticCaptureSetupGuide with full-screen chrome.
/// Opened from ProfileView via `.fullScreenCover`.
public struct ApplePayGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager

    public var entryMode: FastSetupEntryMode

    public init(entryMode: FastSetupEntryMode = .restart) {
        self.entryMode = entryMode
    }

    public var body: some View {
        AutomaticCaptureSetupGuide(
            entryMode: entryMode,
            skipIntro: false,
            showCloseButton: true,
            onFinished: { dismiss() }
        )
        .environmentObject(l10n)
    }
}

#Preview("Apple Pay Guide Sheet • Hebrew") {
    ApplePayGuideSheet()
        .environmentObject(LocalizationManager.shared)
}

#Preview("Apple Pay Guide Sheet • English") {
    ApplePayGuideSheet()
        .environmentObject({
            let m = LocalizationManager.shared
            m.language = .english
            return m
        }())
}
