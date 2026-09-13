import SwiftUI

public struct ApplePayGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isHebrew: Bool { l10n.language == .hebrew }

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Editorial Header matching Onboarding Step 4B
                    VStack(alignment: .leading, spacing: 10) {
                        Text(isHebrew ? "מחברים\nאת הקיצורים" : "Set up\nShortcuts.")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .tracking(isHebrew ? -1 : -1.8)
                            .foregroundStyle(Color.jetBlack)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)

                        Text(isHebrew
                            ? "שלושה שלבים ב״קיצורים״, ואז העסקאות יכולות להגיע ל־SPENT אוטומטית."
                            : "Three steps in Shortcuts, then transactions can reach SPENT automatically.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(Color.jetBlack.opacity(0.75))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 28)

                    // 3-Step Direct-on-Canvas Guide (01 / 02 / 03)
                    VStack(alignment: .leading, spacing: 18) {
                        // Step 01
                        editorialNumberedStep(
                            number: "01",
                            title: isHebrew ? "צור אוטומציה מסוג ״עסקה״" : "Create Transaction Automation",
                            instruction: isHebrew
                                ? "בקיצורים: אוטומציה ← + ← עסקה ← סמן ״הפעלה מיידית״ וכבה את ״קבלת עדכון כאשר פועל״."
                                : "In Shortcuts: Automation → + → Transaction → choose \"Run Immediately\" and turn off \"Notify When Run\"."
                        )

                        Divider().overlay(Color.borderSubtle.opacity(0.6))

                        // Step 02
                        editorialNumberedStep(
                            number: "02",
                            title: isHebrew ? "בחר את הפעולה של SPENT" : "Select SPENT Action",
                            instruction: isHebrew
                                ? "אוטומציה ריקה חדשה ← הוסף פעולה ← חפש SPENT ובחר ״הקלטת עסקת Apple Pay״."
                                : "New Blank Automation → Add Action → search SPENT and pick \"Record Apple Pay Transaction\"."
                        )

                        Divider().overlay(Color.borderSubtle.opacity(0.6))

                        // Step 03 with 2-field mapping
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("03")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(isHebrew ? "חבר את נתוני העסקה" : "Connect Transaction Data")
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                        .foregroundColor(Color.deepNavy)

                                    Text(isHebrew ? "לחץ על כל שדה, בחר ״קלט הקיצור״ ואז את המאפיין:" : "Tap each field, select \"Shortcut Input\" then the attribute:")
                                        .font(.system(.footnote, design: .rounded))
                                        .foregroundColor(Color.textSecondary)
                                }
                            }

                            // Compact inline mapping
                            VStack(alignment: .leading, spacing: 6) {
                                compactMappingRow(
                                    source: isHebrew ? "שדה הסכום" : "Amount field",
                                    dest: isHebrew ? "כמות" : "Amount"
                                )
                                compactMappingRow(
                                    source: isHebrew ? "שדה בית העסק" : "Merchant field",
                                    dest: isHebrew ? "בית העסק" : "Merchant"
                                )
                            }
                            .padding(.leading, 32)
                        }
                    }
                    .padding(.bottom, 36)

                    // Bottom CTA: Open Shortcuts + Close
                    #if os(iOS)
                    VStack(spacing: 12) {
                        if let url = URL(string: "shortcuts://") {
                            Button(action: {
                                Haptics.impact(.medium)
                                UIApplication.shared.open(url)
                            }) {
                                HStack(spacing: 6) {
                                    MoneyIcon(.lightning, size: 18, color: .jetBlack)
                                    Text(isHebrew ? "פתח את קיצורים" : "Open Shortcuts")
                                        .font(.system(.body, design: .rounded, weight: .semibold))
                                }
                                .foregroundColor(.jetBlack)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .frame(minHeight: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.themeOrange)
                                )
                            }
                            .buttonStyle(.plain)
                            .bouncyPress(scale: reduceMotion ? 1 : 0.97)
                        }

                        Button(action: {
                            dismiss()
                        }) {
                            Text(isHebrew ? "סגור" : "Close")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundColor(Color.textSecondary)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 24)
                    #endif
                }
                .padding(.horizontal, 26)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .environment(\.layoutDirection, isHebrew ? .rightToLeft : .leftToRight)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
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
        }
    }

    private func editorialNumberedStep(number: String, title: String, instruction: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(number)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(Color.deepNavy)

                Text(instruction)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                    .lineSpacing(2)
            }
        }
    }

    private func compactMappingRow(source: String, dest: String) -> some View {
        HStack(spacing: 5) {
            Text(source)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Color.primaryBlue)

            Image(systemName: isHebrew ? "arrow.left" : "arrow.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Color.textMuted)

            Text(isHebrew ? "קלט הקיצור" : "Shortcut Input")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Color.spentGreenSoft)
                .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                .foregroundColor(Color.spentGreen)

            Image(systemName: isHebrew ? "arrow.left" : "arrow.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Color.textMuted)

            Text(dest)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
        }
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
