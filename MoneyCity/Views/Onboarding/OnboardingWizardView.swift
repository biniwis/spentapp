import SwiftUI
import SwiftData

/// Onboarding: how the automation works, and the one number the app cannot invent.
public struct OnboardingWizardView: View {
    public let onComplete: () -> Void
    public let onTriggerSampleTransaction: () -> Void

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager

    @State private var currentStep: Int = 1
    @State private var incomeText: String = ""

    /// Step 3 asks for monthly income. Without it the app falls back to a ₪8,000 figure
    /// it made up, and every savings number on every screen is derived from that guess.
    private var parsedIncome: Double? {
        guard let value = TransactionIngest.normalizedAmount(nil, incomeText), value > 0 else { return nil }
        return value
    }
    
    public var body: some View {
        ZStack {
            Color(red: 248/255, green: 250/255, blue: 252/255).ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Step Visual Icon
                ZStack {
                    Circle()
                        .fill(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.12))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: stepIcon)
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                }
                
                // Titles
                VStack(spacing: 8) {
                    Text(stepTitle)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                        .multilineTextAlignment(.center)
                    
                    Text(stepDescription)
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 100/255, green: 116/255, blue: 139/255))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                if currentStep == 2 {
                    VStack(alignment: .leading, spacing: 12) {
                        onboardingStepRow(num: "1", title: "הורד את הקיצור המוכן", desc: "הקיצור כבר מוגדר עם כל הפעולות הנדרשות לקליטה חלקה.")
                        onboardingStepRow(num: "2", title: "צור אוטומציה ב'קיצורים'", desc: "פתח את 'קיצורים' > לשונית 'אוטומציה' > בחר 'עסקה' (Transaction).")
                        onboardingStepRow(num: "3", title: "בחר 'הפעל מיד'", desc: "סמן 'הפעל מיד' (ללא אישור ידני) ובחר להריץ את הקיצור שהורדת.")
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.slate200, lineWidth: 1))
                    .padding(.horizontal, 24)

                    Text("💡 הקיצור יהיה זמין להורדה תמיד גם במסך הפרופיל וההגדרות")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if currentStep == 3 {
                    HStack(spacing: 8) {
                        Text(l10n.baseCurrency.symbol)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        #if os(iOS)
                        TextField("0", text: $incomeText)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                        #else
                        TextField("0", text: $incomeText)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .multilineTextAlignment(.center)
                        #endif
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.slate200, lineWidth: 1))
                    .padding(.horizontal, 40)
                }

                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    if currentStep == 1 {
                        Button(action: { currentStep = 2 }) {
                            Text("איך זה עובד?")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Capsule().fill(Color(red: 16/255, green: 185/255, blue: 129/255)))
                                .shadow(color: Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.3), radius: 8, y: 3)
                        }
                    } else if currentStep == 2 {
                        VStack(spacing: 10) {
                            #if os(iOS)
                            if let url = URL(string: "https://www.icloud.com/shortcuts/62f2a9f1d7324f9d872bbd30fd9ea8c3") {
                                Link(destination: url) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.down.app.fill")
                                            .font(.system(size: 17, weight: .bold))
                                        Text("הורד קיצור מוכן ל-SPENT (קליק אחד)")
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Capsule().fill(Color(red: 16/255, green: 185/255, blue: 129/255)))
                                    .shadow(color: Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.3), radius: 8, y: 3)
                                }
                            }
                            #endif
                            
                            Button(action: { currentStep = 3 }) {
                                Text("המשך לשלב הבא")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.textDark)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                        }
                    } else if currentStep == 3 {
                        Button(action: { saveIncomeAndContinue() }) {
                            Text(parsedIncome == nil ? "אעשה את זה אחר כך" : "המשך")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Capsule().fill(Color(red: 16/255, green: 185/255, blue: 129/255)))
                                .shadow(color: Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.3), radius: 8, y: 3)
                        }
                    } else {
                        Button(action: {
                            onTriggerSampleTransaction()
                            onComplete()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.system(size: 15, weight: .bold))
                                Text("שתול זרע ראשון (קפה בדיקה ב-₪14)")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(Color(red: 16/255, green: 185/255, blue: 129/255)))
                            .shadow(color: Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.3), radius: 8, y: 3)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
        }
    }
    
    private func saveIncomeAndContinue() {
        if let income = parsedIncome {
            modelContext.insert(IncomeSource(
                name: "הכנסה חודשית",
                amount: income,
                currency: l10n.baseCurrency.symbol
            ))
            try? modelContext.save()
        }
        currentStep = 4
    }

    private var stepIcon: String {
        switch currentStep {
        case 1: return "building.2.fill"
        case 2: return "bolt.fill"
        case 3: return "banknote.fill"
        default: return "leaf.fill"
        }
    }
    
    private var stepTitle: String {
        switch currentStep {
        case 1: return "ההוצאות שלך הופכות לעיר חיה"
        case 2: return "מעקב אוטומטי שקט — בלי בנקים"
        case 3: return "כמה נכנס לך בחודש?"
        default: return "העיר שלך מוכנה להיוולד!"
        }
    }
    
    private var stepDescription: String {
        switch currentStep {
        case 1: return "כל תשלום בונה מבנה מסוגנן, וכסף שלא בוזבז מייצר פארקים ירוקים ואגמים."
        case 2: return "דרך Personal Automation של אפל, תשלומים בחנות נתפסים ברקע ישירות מהמכשיר. רכישות אונליין תזין ידנית — iOS לא חושף אותן לאף אפליקציה."
        case 3: return "זה המספר היחיד שהאפליקציה לא יכולה לנחש. בלעדיו גודל העיר ופארק החיסכון מבוססים על הערכה. אפשר לשנות בכל רגע בהגדרות."
        default: return "לחץ כדי להזרים עסקת הדגמה ראשונה ולראות את בית הקפה הראשון נבנה בעיר!"
        }
    }
    
    private func onboardingStepRow(num: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                    .frame(width: 22, height: 22)
                Text(num)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                Text(desc)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
            }
        }
    }
}
