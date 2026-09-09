import SwiftUI
import SwiftData

/// Onboarding Wizard:
/// 1. Concept: Living 3D City & Green Nature Park
/// 2. Mayor: Personalizing the city
/// 3. Budget Target: Anchoring the monthly spending budget
/// 4. Shortcuts: Apple Pay silent background ingestion
/// 5. City Born: First seed transaction celebration
///
/// Fully adhering to SPENT_VISUAL_LANGUAGE.md (no glowing neon halos, calm editorial craftsmanship,
/// authentic Apple HIG design, responsive spring animations, and tactile haptic feedback).
public struct OnboardingWizardView: View {
    public let onComplete: () -> Void
    public let onTriggerSampleTransaction: () -> Void

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager

    @AppStorage("userName") private var storedUserName: String = ""
    @AppStorage("monthly_budget") private var storedMonthlyBudget: Double = 0

    @State private var currentStep: Int = 1
    @State private var slideDirection: Int = 1 // 1 = forward, -1 = backward
    @State private var userNameInput: String = ""
    @State private var budgetInputText: String = "8000"
    @State private var isContentVisible: Bool = false

    private var parsedBudget: Double? {
        guard let val = TransactionIngest.normalizedAmount(nil, budgetInputText), val > 0 else { return nil }
        return val
    }

    private var isHebrew: Bool {
        l10n.isHebrew
    }

    public init(
        onComplete: @escaping () -> Void,
        onTriggerSampleTransaction: @escaping () -> Void
    ) {
        self.onComplete = onComplete
        self.onTriggerSampleTransaction = onTriggerSampleTransaction
    }

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Navigation Row (Back + Dots + Skip)
                topNavigationRow
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Step Dots Progress Indicator
                stepProgressIndicator
                    .padding(.bottom, 16)

                // Scrollable Animated Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        // Hero Icon Badge (Clean pastel circle, no neon glows)
                        stepHeroBadge

                        // Title & Subtitle
                        stepTitleSection

                        // Step Body Content (Clean white cards, editorial layout)
                        stepBodyContent

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 24)
                    .id(currentStep)
                    .transition(
                        .asymmetric(
                            insertion: .offset(x: CGFloat(slideDirection) * 36).combined(with: .opacity),
                            removal: .offset(x: CGFloat(-slideDirection) * 36).combined(with: .opacity)
                        )
                    )
                }

                // Sticky Bottom Action Button
                bottomActionBar
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.appBackground)
            }
        }
        .onAppear {
            userNameInput = storedUserName
            if storedMonthlyBudget > 0 {
                budgetInputText = String(format: "%.0f", storedMonthlyBudget)
            }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                isContentVisible = true
            }
        }
    }

    // MARK: - Top Navigation Row
    private var topNavigationRow: some View {
        HStack {
            if currentStep > 1 {
                Button(action: {
                    Haptics.selection()
                    slideDirection = -1
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        currentStep -= 1
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isHebrew ? "chevron.right" : "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text(isHebrew ? "חזרה" : "Back")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Color.textSecondary)
                }
                .bouncyPress(scale: 0.95)
            }

            Spacer()

            Button(action: {
                Haptics.selection()
                saveAllAndFinish()
            }) {
                Text(isHebrew ? "דלג" : "Skip")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textSecondary)
            }
            .bouncyPress(scale: 0.95)
        }
    }

    // MARK: - Step Progress Indicator
    private var stepProgressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { step in
                Capsule()
                    .fill(step == currentStep ? Color.deepNavy : Color.borderSubtle)
                    .frame(width: step == currentStep ? 24 : 7, height: 7)
                    .animation(.spring(response: 0.32, dampingFraction: 0.75), value: currentStep)
            }
        }
    }

    // MARK: - Hero Badge (Editorial Pastel Circle)
    private var stepHeroBadge: some View {
        ZStack {
            Circle()
                .fill(stepBadgeBg)
                .frame(width: 76, height: 76)

            MoneyIcon(stepBadgeIcon, size: 36, color: stepBadgeColor)
        }
        .padding(.top, 4)
    }

    // MARK: - Title Section
    private var stepTitleSection: some View {
        VStack(spacing: 8) {
            Text(stepTitleText)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
                .multilineTextAlignment(.center)

            Text(stepSubtitleText)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 10)
        }
    }

    // MARK: - Step Body Content Router
    @ViewBuilder
    private var stepBodyContent: some View {
        switch currentStep {
        case 1:
            step1ConceptCards
        case 2:
            step2MayorInput
        case 3:
            step3BudgetConfig
        case 4:
            step4AutomationGuide
        default:
            step5LaunchSummary
        }
    }

    // MARK: Step 1 - Concept Cards
    private var step1ConceptCards: some View {
        VStack(spacing: 12) {
            conceptCardRow(
                icon: .citySkyline,
                color: Color.primaryBlue,
                bgColor: Color.primaryBlue.opacity(0.10),
                title: isHebrew ? "כל קנייה בונה מבנה" : "Every Spend Builds A Building",
                desc: isHebrew ? "סופר, מסעדה או טיסות — כל הוצאה מקימה מבנה תלת-ממדי מסוגנן בעיר שלך." : "Groceries, dining or flights — each payment spawns an isometric structure."
            )

            conceptCardRow(
                icon: .leaf,
                color: Color.spentGreen,
                bgColor: Color.spentGreenSoft,
                title: isHebrew ? "החיסכון מייצר פארק ירוק" : "Savings Grow Green Parks",
                desc: isHebrew ? "התקציב שלא בוזבז מטפח פארקים מלבלבים, עצים ואגמים ככל שאתה חוסך." : "Unspent money blossoms into vibrant parks, trees, and serene lakes."
            )

            conceptCardRow(
                icon: .lock,
                color: Color.themeLavender,
                bgColor: Color.themeLavenderSoft,
                title: isHebrew ? "פרטיות מוחלטת — ללא בנקים" : "Pure Privacy — Zero Bank Logins",
                desc: isHebrew ? "המידע נשמר רק על מכשירך. אפס סיסמאות או חיבורי בנק חיצוניים." : "All data stays strictly on device. No bank credentials needed."
            )
        }
        .padding(.top, 4)
    }

    private func conceptCardRow(
        icon: MoneyIconType,
        color: Color,
        bgColor: Color,
        title: String,
        desc: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(bgColor)
                    .frame(width: 44, height: 44)
                MoneyIcon(icon, size: 20, color: color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                Text(desc)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(Color.textSecondary)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.borderSubtle, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.02), radius: 6, y: 2)
    }

    // MARK: Step 2 - Mayor Input
    private var step2MayorInput: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                MoneyIcon(.user, size: 20, color: Color.primaryBlue)

                TextField(isHebrew ? "הכנס את שמך (למשל: בנימין)" : "Enter your name (e.g. Benjamin)", text: $userNameInput)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.borderSubtle, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.02), radius: 6, y: 2)

            let trimmed = userNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                HStack(spacing: 8) {
                    Text("🏛️")
                        .font(.system(size: 15))
                    Text(isHebrew ? "ראש העיר הרשמי: \(trimmed)" : "Official Mayor: \(trimmed)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.themeYellowSoft)
                .clipShape(Capsule())
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.top, 8)
    }

    // MARK: Step 3 - Budget Config
    private var step3BudgetConfig: some View {
        VStack(spacing: 18) {
            // Main Amount Card
            HStack(spacing: 8) {
                Text(l10n.baseCurrency.symbol)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(Color.spentGreen)

                #if os(iOS)
                TextField("0", text: $budgetInputText)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                #else
                TextField("0", text: $budgetInputText)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .multilineTextAlignment(.center)
                #endif
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.borderSubtle, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.02), radius: 6, y: 2)

            // Preset Quick Selection Chips
            VStack(alignment: .leading, spacing: 8) {
                Text(isHebrew ? "או בחר יעד מהיר:" : "Or select a quick target:")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textMuted)

                HStack(spacing: 8) {
                    budgetChip(amount: "5000")
                    budgetChip(amount: "8000")
                    budgetChip(amount: "12000")
                    budgetChip(amount: "15000")
                }
            }
        }
        .padding(.top, 4)
    }

    private func budgetChip(amount: String) -> some View {
        let isSelected = budgetInputText == amount
        return Button(action: {
            Haptics.selection()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                budgetInputText = amount
            }
        }) {
            Text("₪\(amount)")
                .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? Color.white : Color.deepNavy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color.deepNavy : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Color.clear : Color.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .bouncyPress(scale: 0.94)
    }

    // MARK: Step 4 - Automation Guide
    private var step4AutomationGuide: some View {
        VStack(alignment: .leading, spacing: 14) {
            automationStepRow(
                num: "1",
                title: isHebrew ? "פתח אוטומציה באייפון" : "Open Automation in iPhone",
                desc: isHebrew
                    ? "באפליקציית 'קיצורים' > לשונית 'אוטומציה' > לחץ + > בחר 'עסקה' (Transaction) וסמן 'הפעל מיד'."
                    : "In Shortcuts app > Automation tab > tap + > choose 'Transaction' and select 'Run Immediately'."
            )

            automationStepRow(
                num: "2",
                title: isHebrew ? "בחר בפעולה של SPENT" : "Choose SPENT Action",
                desc: isHebrew
                    ? "בחר 'אוטומציה ריקה חדשה' > 'הוסף פעולה' > חפש SPENT ובחר 'הקלטת עסקת Apple Pay'."
                    : "Choose 'New Blank Automation' > 'Add Action' > search SPENT and select 'Record Apple Pay Transaction'."
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.spentGreen)
                            .frame(width: 22, height: 22)
                        Text("3")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isHebrew ? "חבר את הקלט (חשוב! 💡)" : "Connect Input (Important! 💡)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        Text(isHebrew ? "לחץ על השדות הכחולים וחבר אותם ל'קלט הקיצור':" : "Tap blue fields and attach to Shortcut Input:")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Color.textMuted)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(isHebrew ? "• לחץ" : "• Tap")
                            .font(.system(size: 11, weight: .medium))
                        Text(isHebrew ? "[סכום העסקה]" : "[Transaction Amount]")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.primaryBlue)
                        Text("➔")
                            .font(.system(size: 11, weight: .medium))
                        Text(isHebrew ? "[קלט הקיצור]" : "[Shortcut Input]")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.spentGreen)
                        Text(isHebrew ? "(סכום)" : "(Amount)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    HStack(spacing: 4) {
                        Text(isHebrew ? "• לחץ" : "• Tap")
                            .font(.system(size: 11, weight: .medium))
                        Text(isHebrew ? "[שם בית העסק]" : "[Merchant Name]")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.primaryBlue)
                        Text("➔")
                            .font(.system(size: 11, weight: .medium))
                        Text(isHebrew ? "[קלט הקיצור]" : "[Shortcut Input]")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.spentGreen)
                        Text(isHebrew ? "(שם העסק)" : "(Merchant)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    Text(isHebrew ? "• לחץ 'סיום' (Done) למעלה — וזהו! 🎉" : "• Tap 'Done' at the top — and you're set! 🎉")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.spentGreen)
                        .padding(.top, 2)
                }
                .padding(.leading, 34)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.borderSubtle, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.02), radius: 6, y: 2)
    }

    private func automationStepRow(num: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.spentGreen)
                    .frame(width: 22, height: 22)
                Text(num)
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

    // MARK: Step 5 - Launch Summary
    private var step5LaunchSummary: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                let mayorName = userNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                summaryRow(
                    label: isHebrew ? "ראש עיר" : "Mayor",
                    value: mayorName.isEmpty ? (isHebrew ? "ראש העיר" : "Mayor") : mayorName
                )
                Divider()
                summaryRow(
                    label: isHebrew ? "יעד תקציב חודשי" : "Monthly Budget",
                    value: "₪\(budgetInputText)"
                )
                Divider()
                summaryRow(
                    label: isHebrew ? "אוטומציה שקטה" : "Automation",
                    value: isHebrew ? "מוכנה לפעולה" : "Ready"
                )
            }
            .padding(18)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.borderSubtle, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.02), radius: 6, y: 2)

            Text(isHebrew ? "בלחיצה למטה תיכנס לעיר שלך — כל תשלום שתבצע דרך Apple Pay או ידנית יקים את המבנים הראשונים! 🏙️" : "Tap below to step into your city — every payment builds your very first landmarks! 🏙️")
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(.top, 4)
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Color.textMuted)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Bottom Action Bar
    @ViewBuilder
    private var bottomActionBar: some View {
        switch currentStep {
        case 1:
            primaryActionButton(title: isHebrew ? "בוא נתחיל" : "Let's Get Started") {
                nextStep()
            }
        case 2:
            primaryActionButton(title: isHebrew ? "המשך לתקציב" : "Continue to Budget") {
                saveMayor()
                nextStep()
            }
        case 3:
            primaryActionButton(title: isHebrew ? "המשך לאוטומציה" : "Continue to Automation") {
                saveBudget()
                nextStep()
            }
        case 4:
            step4ActionButtons
        default:
            primaryActionButton(title: isHebrew ? "בוא נתחיל לבנות את העיר" : "Enter Your City") {
                Haptics.notify(.success)
                saveAllAndFinish()
            }
        }
    }

    private var step4ActionButtons: some View {
        VStack(spacing: 10) {
            #if os(iOS)
            if let url = URL(string: "shortcuts://") {
                Link(destination: url) {
                    HStack(spacing: 8) {
                        MoneyIcon(.lightning, size: 18, color: .white)
                        Text(isHebrew ? "פתח את אפליקציית 'קיצורים'" : "Open Shortcuts App")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.themeOrange))
                }
                .bouncyPress(scale: 0.97)
            }
            #endif

            primaryActionButton(title: isHebrew ? "המשך לסיום" : "Continue") {
                nextStep()
            }
        }
    }

    private func primaryActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.impact(.medium)
            action()
        }) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(Color.spentGreen))
                .shadow(color: Color.spentGreen.opacity(0.25), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .bouncyPress(scale: 0.97)
    }

    private func nextStep() {
        slideDirection = 1
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            currentStep += 1
        }
    }

    private func saveMayor() {
        let trimmed = userNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            storedUserName = trimmed
        }
    }

    private func saveBudget() {
        if let b = parsedBudget {
            storedMonthlyBudget = b
            modelContext.insert(IncomeSource(
                name: isHebrew ? "יעד חודשי" : "Monthly Target",
                amount: b,
                currency: l10n.baseCurrency.symbol
            ))
            try? modelContext.save()
        }
    }

    private func saveAllAndFinish() {
        saveMayor()
        saveBudget()
        onTriggerSampleTransaction()
        onComplete()
    }

    // MARK: - Dynamic Step Helpers
    private var stepBadgeIcon: MoneyIconName {
        switch currentStep {
        case 1: return .citySkyline
        case 2: return .user
        case 3: return .target
        case 4: return .lightning
        default: return .star
        }
    }

    private var stepBadgeColor: Color {
        switch currentStep {
        case 1: return Color.primaryBlue
        case 2: return Color.themeTurquoise
        case 3: return Color.spentGreen
        case 4: return Color.themeOrange
        default: return Color.spentGreen
        }
    }

    private var stepBadgeBg: Color {
        switch currentStep {
        case 1: return Color.primaryBlue.opacity(0.10)
        case 2: return Color.themeTurquoiseSoft
        case 3: return Color.spentGreenSoft
        case 4: return Color.themeOrangeSoft
        default: return Color.spentGreenSoft
        }
    }

    private var stepTitleText: String {
        switch currentStep {
        case 1:
            return isHebrew ? "ההוצאות שלך בונות עיר חיה" : "Your Spending Builds A Living City"
        case 2:
            return isHebrew ? "מי ראש העיר החדש?" : "Who is the New Mayor?"
        case 3:
            return isHebrew ? "מה יעד ההוצאות החודשי שלך?" : "What's Your Monthly Budget Target?"
        case 4:
            return isHebrew ? "מעקב אוטומטי שקט — בלי בנקים" : "Silent Apple Pay Tracking — No Banks"
        default:
            return isHebrew ? "העיר שלך מוכנה להיוולד!" : "Your City Is Ready To Be Born!"
        }
    }

    private var stepSubtitleText: String {
        switch currentStep {
        case 1:
            return isHebrew
                ? "כל תשלום שאתה מבצע מקים מבנה תלת-ממדי מסוגנן, וכסף שלא הוצאת מייצר פארקים ירוקים ואגמים."
                : "Every payment constructs a stylish 3D building, and unspent money grows vibrant green parks and lakes."
        case 2:
            return isHebrew
                ? "העיר תפנה אליך בתואר ראש העיר בכל סיכום חודשי והישג שתפתח."
                : "Personalize your city. You'll be addressed as Mayor across recaps and achievements."
        case 3:
            return isHebrew
                ? "זהו העוגן של העיר. ככל שתשמור על התקציב, שטחי הטבע והחיסכון בעיר ישגשגו."
                : "This is the anchor for your city. Remaining within budget expands your lush savings parks."
        case 4:
            return isHebrew
                ? "באמצעות אוטומציה אישית של Apple Pay, תשלומים בחנות נתפסים ברקע ישירות מהמכשיר."
                : "With Apple Pay Personal Automation, in-store payments are ingested silently in the background."
        default:
            return isHebrew
                ? "הכל מוגדר ומכוון! לחץ למטה לכניסה לעיר שלך — היא תצמח ותתפתח עם כל פעולה והוצאה שתבצע."
                : "Everything is set! Tap below to enter your city — it will grow and evolve with every expense you make."
        }
    }
}
