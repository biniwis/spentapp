import SwiftUI

public struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager

    private var isHebrew: Bool { l10n.language == .hebrew }

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Card
                    VStack(alignment: .center, spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.themeMint.opacity(0.12))
                                .frame(width: 60, height: 60)
                            MoneyIcon(.lock, size: 28, color: Color.themeMint)
                        }

                        Text(isHebrew ? "פרטיות פיננסית ב-SPENT" : "Financial Privacy at SPENT")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                            .multilineTextAlignment(.center)

                        Text(isHebrew ? "ב-SPENT, ההוצאות, התקציבים ונתוני העיר שלך נשמרים ומעובדים מקומית במכשירך בלבד."
                                      : "At SPENT, your expenses, budgets, and city data are processed and stored locally on your device.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                    // Policy Sections
                    policyCard(
                        icon: .lock,
                        title: isHebrew ? "עיבוד ושמירה מקומיים" : "Local Storage & Processing",
                        body: isHebrew ? "ההוצאות, התקציבים ונתוני העיר נשמרים מקומית במכשיר באמצעות SwiftData. SPENT אינה מפעילה חשבון משתמש או בסיס נתונים בענן עבור המידע הפיננסי שלך."
                                       : "Your expenses, budgets, and city data are stored locally on your device using SwiftData. SPENT does not operate user accounts or cloud databases for your financial data."
                    )

                    policyCard(
                        icon: .checkCircle,
                        title: isHebrew ? "ללא מעקב וללא פרסום" : "No Tracking & No Advertising",
                        body: isHebrew ? "SPENT אינה משתמשת במידע הפיננסי שלך לצורכי מעקב, פרסום או פרופיל משתמש, ואינה שולחת מידע על הוצאות לשירותי אנליטיקה של צד שלישי."
                                       : "SPENT does not use your financial data for tracking, advertising, or user profiling, and does not send expense information to third-party analytics services."
                    )

                    policyCard(
                        icon: .lightning,
                        title: isHebrew ? "קליטה אוטומטית" : "Automatic Capture",
                        body: isHebrew ? "SPENT אינה מקבלת גישה לכרטיסי האשראי או לחשבון הבנק שלך. כאשר קליטה אוטומטית מופעלת, האייפון יכול להעביר ל-SPENT את הסכום ושם בית העסק.\n\nSPENT אינה מקבלת מספר כרטיס, CVV, תוקף, יתרה, מסגרת אשראי או פרטי חשבון בנק. המידע אינו נשלח לשרת של SPENT או לשירות צד שלישי."
                                       : "SPENT does not get access to your credit cards or bank account. When automatic capture is enabled, your iPhone can pass SPENT the amount and merchant name.\n\nSPENT does not receive card numbers, CVV, expiration dates, balances, credit limits, or bank account details. Information is not sent to any SPENT server or third-party service."
                    )

                    policyCard(
                        icon: .refresh,
                        title: isHebrew ? "שערי מטבע" : "Foreign Exchange Rates",
                        body: isHebrew ? "לצורך המרת מט\"ח, SPENT מבקשת משירות שערי חליפין את המטבעות הדרושים לחישוב. הבקשה אינה כוללת שמות בתי עסק, סכומי עסקאות או היסטוריית הוצאות. כמו בכל בקשת אינטרנט, ספק השירות עשוי לקבל מידע טכני של החיבור בהתאם למדיניות שלו."
                                       : "For foreign exchange conversion, SPENT requests the necessary currencies for calculation from an exchange rate service. The request does not include merchant names, transaction amounts, or spending history. As with any internet request, the service provider may receive technical connection information according to its policy."
                    )

                    policyCard(
                        icon: .trash,
                        title: isHebrew ? "שליטה, ייצוא ומחיקה" : "Control, Export & Deletion",
                        body: isHebrew ? "אפשר לייצא גיבוי מקומי ולמחוק את נתוני SPENT מהמכשיר דרך ההגדרות. קבצי גיבוי שייצאת בעצמך נשארים בשליטתך ויש למחוק אותם בנפרד."
                                       : "You can export a local backup and delete SPENT data from your device through Settings. Backup files you exported yourself remain under your control and must be deleted separately."
                    )

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(isHebrew ? "מדיניות פרטיות" : "Privacy Policy")
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

    private func policyCard(icon: MoneyIconType, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                MoneyIcon(icon, size: 18, color: Color.primaryBlue)
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
            }

            Text(body)
                .font(.system(size: 12.5, weight: .regular, design: .rounded))
                .foregroundColor(Color.textMuted)
                .lineSpacing(3)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.025), radius: 6, y: 2)
    }
}


