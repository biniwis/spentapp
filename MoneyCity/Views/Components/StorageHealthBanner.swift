import SwiftUI

/// Tells the user when the store did not open normally.
///
/// Both degraded modes look exactly like "my data vanished" from the user's side, and in one
/// of them nothing they type will survive closing the app. Staying silent about that is how a
/// person re-enters a month of expenses into a store that is about to discard them, so this
/// banner is deliberately loud and sits above the city rather than inside a settings screen.
public struct StorageHealthBanner: View {
    private let mode: DatabaseService.StorageMode
    @ObservedObject private var l10n = LocalizationManager.shared
    @State private var expanded = false

    public init(mode: DatabaseService.StorageMode) {
        self.mode = mode
    }

    private var isHebrew: Bool { l10n.language == .hebrew }

    public var body: some View {
        switch mode {
        case .persistent:
            EmptyView()
        case .recoveredFreshStore(let backupPath):
            banner(
                icon: "arrow.counterclockwise.circle.fill",
                tint: MoneyCityTheme.yellow,
                surface: MoneyCityTheme.yellowSoft,
                title: isHebrew
                    ? "הנתונים הקודמים לא נטענו"
                    : "Previous data could not be loaded",
                detail: isHebrew
                    ? "האפליקציה התחילה מסד נתונים חדש. הקובץ הישן לא נמחק. לשחזור: פרופיל ← גיבוי ושחזור ← בחר תצלום."
                    : "The app started a fresh database. The old file was not deleted. To go back: Profile → Backup & Restore → pick a snapshot.",
                extra: backupPath
            )
        case .memoryOnly:
            banner(
                icon: "exclamationmark.triangle.fill",
                tint: MoneyCityTheme.orange,
                surface: MoneyCityTheme.orangeSoft,
                title: isHebrew
                    ? "הוצאות שתזין עכשיו לא יישמרו"
                    : "Expenses you enter now will not be saved",
                detail: isHebrew
                    ? "לא הצלחנו לפתוח את האחסון במכשיר. האפליקציה עובדת, אבל כל מה שייכנס יימחק בסגירה. אל תזין הוצאות עד שזה ייפתר."
                    : "Storage on this device could not be opened. The app works, but anything entered will be gone when it closes. Don't enter expenses until this is fixed.",
                extra: nil
            )
        }
    }

    @ViewBuilder
    private func banner(
        icon: String,
        tint: Color,
        surface: Color,
        title: String,
        detail: String,
        extra: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(MoneyCityTheme.textPrimary)
                    Text(detail)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(MoneyCityTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if let extra, !extra.isEmpty {
                Button {
                    expanded.toggle()
                } label: {
                    Text(expanded
                         ? extra
                         : (isHebrew ? "היכן נשמר הקובץ הישן" : "Where the old file is"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(tint)
                        .multilineTextAlignment(isHebrew ? .trailing : .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
