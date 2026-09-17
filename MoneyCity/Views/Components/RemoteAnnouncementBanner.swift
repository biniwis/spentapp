import SwiftUI

/// Clean, native announcement banner driven strictly by Remote Config.
/// Adheres strictly to the SPENT Design Constitution:
/// No glow, no glassmorphism overload, no arbitrary URLs or execution.
public struct RemoteAnnouncementBanner: View {
    let announcement: RemoteAnnouncement
    let onAction: (RemoteAnnouncementAction) -> Void
    let onDismiss: () -> Void

    @EnvironmentObject private var l10n: LocalizationManager

    public init(
        announcement: RemoteAnnouncement,
        onAction: @escaping (RemoteAnnouncementAction) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.announcement = announcement
        self.onAction = onAction
        self.onDismiss = onDismiss
    }

    public var body: some View {
        let isHe = l10n.language == .hebrew
        let title = isHe ? (announcement.title["he"] ?? announcement.title["en"] ?? "") : (announcement.title["en"] ?? announcement.title["he"] ?? "")
        let bodyText = isHe ? (announcement.body["he"] ?? announcement.body["en"] ?? "") : (announcement.body["en"] ?? announcement.body["he"] ?? "")
        let action = announcement.safeAction

        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                        .lineLimit(1)
                }
                if !bodyText.isEmpty {
                    Text(bodyText)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 4)

            if action != .none {
                Button {
                    Haptics.impact(.light)
                    onAction(action)
                } label: {
                    Text(actionTitle(for: action, isHebrew: isHe))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(MoneyCityTheme.jetBlack)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.spentGreen)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Button {
                Haptics.impact(.light)
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.textMuted)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func actionTitle(for action: RemoteAnnouncementAction, isHebrew: Bool) -> String {
        switch action {
        case .openCaptureGuide:
            return isHebrew ? "מדריך" : "Guide"
        case .openProfile:
            return isHebrew ? "פרופיל" : "Profile"
        case .none:
            return ""
        }
    }
}
