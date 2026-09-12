import SwiftUI

public struct AboutSpentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager

    private var isHebrew: Bool { l10n.language == .hebrew }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer(minLength: 12)

                    // Hero App Emblem Card
                    VStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.themeLavenderSoft)
                                .frame(width: 76, height: 76)
                            MoneyIcon(.citySkyline, size: 38, color: Color.deepNavy)
                        }

                        VStack(spacing: 4) {
                            Text("SPENT")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                                .tracking(1)

                            Text(isHebrew ? "מעקב הוצאות שמקבל צורה בעיר" : "Spending awareness, visualized as a city")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(Color.textMuted)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .padding(.horizontal, 20)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)

                    // Details Inset Card
                    VStack(spacing: 0) {
                        infoRow(
                            label: isHebrew ? "גרסת אפליקציה" : "App Version",
                            value: StoreSnapshotService.currentVersion()
                        )

                        Divider().background(Color.borderSubtle).padding(.vertical, 6)

                        infoRow(
                            label: isHebrew ? "מספר Build" : "Build Number",
                            value: StoreSnapshotService.currentBuild()
                        )

                        Divider().background(Color.borderSubtle).padding(.vertical, 6)

                        infoRow(
                            label: isHebrew ? "זכויות יוצרים" : "Copyright",
                            value: "© 2026 Binyamin Wisemon"
                        )
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)

                    Spacer()

                    // Quiet footer note
                    Text(isHebrew ? "נוצר בישראל באהבה 🏙️" : "Crafted with care 🏙️")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textMuted.opacity(0.8))
                        .padding(.bottom, 16)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle(isHebrew ? "אודות SPENT" : "About SPENT")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.text(for: "close")) { dismiss() }
                        .foregroundColor(Color.primaryBlue)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Color.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
        }
        .padding(.vertical, 4)
    }
}

