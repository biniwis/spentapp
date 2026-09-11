import SwiftUI

public struct ApplePayGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager
    
    private var isHebrew: Bool { l10n.language == .hebrew }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.themeTurquoiseSoft)
                                .frame(width: 60, height: 60)
                            DistrictFinanceVectorIcon(color: Color.themeTurquoise)
                                .scaleEffect(1.3)
                        }
                        
                        Text(isHebrew ? "הגדרת קליטת Apple Pay אוטומטית" : "Automatic Apple Pay Setup")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                            .multilineTextAlignment(.center)
                        
                        Text(isHebrew
                             ? "בגלל ש-iOS שומרת על פרטיות, נדרש חיבור קצר באפליקציית 'קיצורים' (Shortcuts) כדי שכל תשלום ייקלט מיד בעיר שלך."
                             : "Due to iOS privacy, a quick Shortcuts automation is required to stream tap-to-pay charges directly into your city.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                    }
                    .padding(.top, 10)
                    
                    // Auto-Installed Notification Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.15))
                                    .frame(width: 44, height: 44)
                                DistrictFinanceVectorIcon(color: Color(red: 16/255, green: 185/255, blue: 129/255))
                                    .scaleEffect(1.1)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isHebrew ? "הפעולות של SPENT כבר מותקנות באייפון!" : "SPENT actions are already installed!")
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                Text(isHebrew ? "הפעולה מובנית במערכת — נותר רק להפעיל אוטומציה:" : "Built-in to iOS — just enable the 3-step automation:")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.textMuted)
                            }
                        }
                    }
                    .padding(18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)

                    // Simple Step-by-Step Instructions Card
                    VStack(alignment: .leading, spacing: 18) {
                        stepRow(
                            number: "1",
                            title: isHebrew ? "פתח את אפליקציית 'קיצורים' (Shortcuts)" : "Open 'Shortcuts' App",
                            desc: isHebrew ? "עבור ללשונית 'אוטומציה' בתחתית ולחץ על + ליצירת 'אוטומציה אישית'." : "Go to 'Automation' tab and tap + to create a Personal Automation."
                        )
                        
                        stepRow(
                            number: "2",
                            title: isHebrew ? "בחר בטריגר 'עסקה' (Transaction)" : "Select 'Transaction' Trigger",
                            desc: isHebrew ? "סמן 'כרטיס כלשהו', בחר 'הפעלה מיידית', וכבה את 'קבלת עדכון כאשר פועל'." : "Select 'Any Card', choose 'Run Immediately', and turn off 'Notify When Run'."
                        )
                        
                        stepRow(
                            number: "3",
                            title: isHebrew ? "הוסף פעולה: 'הקלטת עסקת Apple Pay'" : "Add Action: 'Record Apple Pay Transaction'",
                            desc: isHebrew ? "בחר 'אוטומציה ריקה חדשה' > 'הוסף פעולה' > חפש SPENT ובחר 'הקלטת עסקת Apple Pay'." : "Choose 'New Blank Automation' > 'Add Action' > search SPENT and pick 'Record Apple Pay Transaction'."
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                                        .frame(width: 24, height: 24)
                                    Text("4")
                                        .font(.system(size: 12, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isHebrew ? "חבר את נתוני העסקה (כמות ובית עסק 💡)" : "Connect Transaction Data (💡)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.deepNavy)
                                    Text(isHebrew ? "לחץ על כל שדה כחול, בחר 'קלט הקיצור' ואז את המאפיין:" : "Tap each blue field, select 'Shortcut Input' then the attribute:")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(Color.textMuted)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text(isHebrew ? "• לחץ" : "• Tap")
                                        .font(.system(size: 11.5, weight: .medium))
                                    Text(isHebrew ? "[שדה הסכום]" : "[Amount field]")
                                        .font(.system(size: 11.5, weight: .bold))
                                        .foregroundColor(Color.primaryBlue)
                                    Text(isHebrew ? "➔ בחר" : "➔ select")
                                        .font(.system(size: 11.5, weight: .medium))
                                    Text(isHebrew ? "[קלט הקיצור]" : "[Shortcut Input]")
                                        .font(.system(size: 11.5, weight: .bold))
                                        .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                                    Text(isHebrew ? "➔ סמן (כמות)" : "➔ choose (Amount)")
                                        .font(.system(size: 11.5, weight: .semibold))
                                }
                                HStack(spacing: 4) {
                                    Text(isHebrew ? "• לחץ" : "• Tap")
                                        .font(.system(size: 11.5, weight: .medium))
                                    Text(isHebrew ? "[שדה בית העסק]" : "[Merchant field]")
                                        .font(.system(size: 11.5, weight: .bold))
                                        .foregroundColor(Color.primaryBlue)
                                    Text(isHebrew ? "➔ בחר" : "➔ select")
                                        .font(.system(size: 11.5, weight: .medium))
                                    Text(isHebrew ? "[קלט הקיצור]" : "[Shortcut Input]")
                                        .font(.system(size: 11.5, weight: .bold))
                                        .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                                    Text(isHebrew ? "➔ סמן (בית העסק)" : "➔ choose (Merchant)")
                                        .font(.system(size: 11.5, weight: .semibold))
                                }
                                Text(isHebrew ? "• לחץ 'סיום' (Done) — מעכשיו הכל יקלט אוטומטית! 🎉" : "• Tap 'Done' — and you are all set! 🎉")
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                                    .padding(.top, 2)
                            }
                            .padding(.leading, 36)
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)
                    
                    // Action Links
                    #if os(iOS)
                    VStack(spacing: 10) {
                        if let url = URL(string: "shortcuts://") {
                            Link(destination: url) {
                                HStack(spacing: 8) {
                                    MoneyIcon(.lightning, size: 18)
                                    Text(isHebrew ? "פתח את אפליקציית 'קיצורים' עכשיו" : "Open Shortcuts App Now")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Capsule().fill(Color(red: 16/255, green: 185/255, blue: 129/255)))
                                .shadow(color: Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.3), radius: 8, y: 3)
                            }
                        }
                    }
                    .padding(.top, 6)
                    #endif
                    
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 18)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(isHebrew ? "הגדרת אוטומציה" : "Shortcuts Guide")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.text(for: "close")) { dismiss() }
                        .foregroundColor(Color.primaryBlue)
                }
            }
        }
    }
    
    private func stepRow(number: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primaryBlue)
                    .frame(width: 24, height: 24)
                Text(number)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                Text(desc)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
            }
        }
    }
    
}


