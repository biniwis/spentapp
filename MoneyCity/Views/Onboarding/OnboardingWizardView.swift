import SwiftUI
import SwiftData

/// Onboarding Wizard:
/// A mature, modern, architectural first-run experience adhering to SPENT_DESIGN_CONSTITUTION.md:
/// - Young, modern, editorial, architectural, confident, and premium.
/// - Borderless, direct-on-canvas hierarchy: zero cards, frames, or pill stacks.
/// - SF Rounded used selectively for hero numbers, city titles, and key amounts; standard SF Pro for body/instructions.
/// - Real, directly-editable hero spending amount with keyboard support.
/// - Precise, non-judgmental copy accurately explaining Apple Shortcuts automation without misleading Wallet/bank claims.
/// - Refined 18pt corner radius CTA buttons without colored glow.
public struct OnboardingWizardView: View {
    public let onComplete: () -> Void
    public let onTriggerSampleTransaction: () -> Void

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("userName") private var storedUserName: String = ""
    @AppStorage("monthly_budget") private var storedMonthlyBudget: Double = 0

    // Persistent state across scene lifecycle (e.g. switching to Shortcuts and back)
    @SceneStorage("spent.onboarding.currentStep") private var currentStep: Int = 1
    @SceneStorage("spent.onboarding.shortcutPhase") private var shortcutPhase: String = "intro" // "intro" (4A) or "guide" (4B)

    private enum OnboardingField: Hashable {
        case mayorName
        case budget
    }
    @FocusState private var focusedField: OnboardingField?

    @State private var slideDirection: Int = 1 // 1 = forward, -1 = backward
    @State private var userNameInput: String = ""
    @State private var budgetInputText: String = "8000"
    @State private var hasOpenedShortcuts: Bool = false

    private let initialStepOverride: Int?
    private let initialPhaseOverride: String?
    private let canDismiss: Bool

    private var parsedBudget: Double? {
        guard let val = TransactionIngest.normalizedAmount(nil, budgetInputText), val > 0 else { return nil }
        return val
    }

    private var isHebrew: Bool {
        l10n.isHebrew
    }

    private var activeOnboardingStep: OnboardingStep {
        OnboardingStep(rawValue: currentStep) ?? .concept
    }

    public init(
        initialStep: Int? = nil,
        initialPhase: String? = nil,
        canDismiss: Bool = false,
        onComplete: @escaping () -> Void,
        onTriggerSampleTransaction: @escaping () -> Void
    ) {
        self.initialStepOverride = initialStep
        self.initialPhaseOverride = initialPhase
        self.canDismiss = canDismiss
        self.onComplete = onComplete
        self.onTriggerSampleTransaction = onTriggerSampleTransaction
    }

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Navigation (Back button + quiet progress indicators)
                topNavigationRow
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 6)

                // 5 Dots Progress Indicator (Quiet, subtle)
                stepProgressIndicator
                    .padding(.bottom, 6)

                // Continuous Miniature City Scene (Direct on canvas, zero frames)
                OnboardingCityScene(
                    step: activeOnboardingStep,
                    mayorName: userNameInput,
                    targetAmountText: budgetInputText,
                    isRTL: isHebrew,
                    height: (focusedField != nil) ? 110 : 180
                )
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: focusedField)
                .padding(.bottom, focusedField != nil ? 4 : 10)

                // Scrollable Step Body (Direct on canvas, intentional whitespace)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Title & Subtitle Section
                        stepTitleSection

                        // Interactive Step Form Content
                        stepBodyContent

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 26)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Tapping background dismisses keyboard
                        focusedField = nil
                    }
                    .id("\(currentStep)_\(shortcutPhase)")
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .offset(x: CGFloat(slideDirection) * 24).combined(with: .opacity),
                                removal: .offset(x: CGFloat(-slideDirection) * 24).combined(with: .opacity)
                            )
                    )
                }

                // Sticky Bottom Action Bar
                bottomActionBar
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.appBackground)
            }
        }
        .onAppear {
            if let initialStep = initialStepOverride {
                currentStep = initialStep
            }
            if let initialPhase = initialPhaseOverride {
                shortcutPhase = initialPhase
            }
            if !storedUserName.isEmpty && userNameInput.isEmpty {
                userNameInput = storedUserName
            }
            if storedMonthlyBudget > 0 {
                budgetInputText = String(format: "%.0f", storedMonthlyBudget)
            }
        }
        .onChange(of: currentStep) { _, _ in
            focusedField = nil
        }
        .environment(\.layoutDirection, isHebrew ? .rightToLeft : .leftToRight)
    }

    // MARK: - Top Navigation Row
    private var topNavigationRow: some View {
        HStack {
            if currentStep > 1 || (currentStep == 4 && shortcutPhase == "guide") {
                Button(action: handleBackNavigation) {
                    HStack(spacing: 4) {
                        Image(systemName: isHebrew ? "chevron.right" : "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text(isHebrew ? "חזרה" : "Back")
                            .font(.system(size: 14, weight: .medium, design: .default))
                    }
                    .foregroundColor(Color.textSecondary)
                }
                .buttonStyle(.plain)
                .bouncyPress(scale: 0.96)
            }

            Spacer()

            if canDismiss {
                Button(action: onComplete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .bouncyPress(scale: 0.94)
            }
        }
        .frame(height: 28)
    }

    private func handleBackNavigation() {
        Haptics.selection()
        if currentStep == 4 && shortcutPhase == "guide" {
            slideDirection = -1
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                shortcutPhase = "intro"
            }
        } else if currentStep > 1 {
            slideDirection = -1
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                currentStep -= 1
                if currentStep == 4 {
                    shortcutPhase = "intro"
                }
            }
        }
    }

    // MARK: - 5 Dots Progress Indicator (Quiet, mature)
    private var stepProgressIndicator: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { stepNumber in
                Capsule()
                    .fill(stepNumber == currentStep ? Color.deepNavy : Color.borderSubtle.opacity(0.8))
                    .frame(width: stepNumber == currentStep ? 18 : 5, height: 5)
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: currentStep)
            }
        }
    }

    // MARK: - Title Section
    private var stepTitleSection: some View {
        VStack(spacing: 6) {
            Text(stepTitleText)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
                .multilineTextAlignment(.center)

            Text(stepSubtitleText)
                .font(.system(size: 13.5, weight: .regular, design: .default))
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
            step1ConceptBody
        case 2:
            step2MayorInput
        case 3:
            step3BudgetConfig
        case 4:
            if shortcutPhase == "guide" {
                step4BGuideContent
            } else {
                step4AIntroContent
            }
        default:
            step5LaunchSummary
        }
    }

    // MARK: Step 1 - Concept Body (Clean typographic narrative, subtle colored dots)
    private var step1ConceptBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            editorialFactRow(
                dotColor: Color.themeOrange,
                text: isHebrew ? "הוצאות משנות את העיר" : "Spending shapes the city"
            )

            editorialFactRow(
                dotColor: Color.spentGreen,
                text: isHebrew ? "הפארק משקף איך החודש מתקדם מול היעד" : "The park reflects month progress against target"
            )

            editorialFactRow(
                dotColor: Color.primaryBlue,
                text: isHebrew ? "המידע נשאר על המכשיר" : "Data stays strictly on your device"
            )
        }
        .padding(.top, 14)
        .padding(.horizontal, 12)
    }

    private func editorialFactRow(dotColor: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(Color.deepNavy)

            Spacer()
        }
    }

    // MARK: Step 2 - Mayor Input (Tonal editable surface; direct keyboard interaction)
    private var step2MayorInput: some View {
        VStack(spacing: 8) {
            Text(isHebrew ? "השם שלך" : "Your Name")
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundColor(Color.textMuted)

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.spentGreen.opacity(focusedField == .mayorName ? 0.08 : 0.045))
                    .frame(height: 64)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField = .mayorName
                    }

                if userNameInput.isEmpty && focusedField != .mayorName {
                    Text(isHebrew ? "השם שלך" : "Your name")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Color.textMuted.opacity(0.35))
                        .allowsHitTesting(false)
                }

                TextField("", text: $userNameInput)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .multilineTextAlignment(.center)
                    .focused($focusedField, equals: .mayorName)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .submitLabel(.next)
                    .onSubmit {
                        saveMayor()
                        nextStep()
                    }
                    .accessibilityLabel(isHebrew ? "השם שלך" : "Your name")
                    .padding(.horizontal, 16)
            }
            .animation(.easeOut(duration: 0.18), value: focusedField)
        }
        .padding(.top, 14)
    }

    // MARK: Step 3 - Monthly Spending Target (Tonal editable surface, clean presets, BUDGET ≠ INCOME)
    private var formattedBudgetText: String {
        let digits = budgetInputText.filter { $0.isNumber }
        guard let val = Double(digits), val > 0 else {
            return budgetInputText.isEmpty ? "0" : budgetInputText
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: val)) ?? budgetInputText
    }

    private var step3BudgetConfig: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.spentGreen.opacity(focusedField == .budget ? 0.08 : 0.045))
                    .frame(height: 72)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField = .budget
                    }

                HStack(spacing: 6) {
                    Text(l10n.baseCurrency.symbol)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.spentGreen)

                    ZStack {
                        if focusedField != .budget {
                            Text(formattedBudgetText)
                                .font(.system(size: 38, weight: .heavy, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                                .allowsHitTesting(false)
                        }

                        TextField("", text: $budgetInputText)
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundColor(focusedField == .budget ? Color.deepNavy : Color.clear)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .focused($focusedField, equals: .budget)
                            .accessibilityLabel(isHebrew ? "יעד הוצאה חודשי" : "Monthly spending target")
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
            }
            .animation(.easeOut(duration: 0.18), value: focusedField)
            .padding(.top, 4)

            // Preset Quick Suggestions (Quiet suggestions, not heavy buttons)
            HStack(spacing: 8) {
                budgetPresetOption(amount: "5000")
                budgetPresetOption(amount: "8000")
                budgetPresetOption(amount: "12000")
                budgetPresetOption(amount: "15000")
            }

            // Quiet supporting label
            Text(isHebrew ? "יעד הוצאה חודשי · אפשר לשנות אחר כך" : "Monthly spending target · can be changed later")
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundColor(Color.textMuted)
        }
        .padding(.top, 6)
    }

    private func budgetPresetOption(amount: String) -> some View {
        let isSelected = budgetInputText == amount
        return Button(action: {
            Haptics.selection()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                budgetInputText = amount
                focusedField = nil
            }
        }) {
            Text("₪\(amount)")
                .font(.system(size: 12.5, weight: isSelected ? .bold : .regular, design: .rounded))
                .foregroundColor(isSelected ? Color.white : Color.deepNavy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.deepNavy : Color.black.opacity(0.04))
                )
        }
        .buttonStyle(.plain)
        .bouncyPress(scale: 0.96)
    }

    // MARK: Step 4A - Shortcuts Intro (Flatter, mature typographic flow)
    private var step4AIntroContent: some View {
        VStack(spacing: 20) {
            // Mature 3-node flow: Payment → Shortcuts → SPENT
            HStack(spacing: 16) {
                if isHebrew {
                    // RTL reading: תשלום (Right) → קיצורים (Center) → SPENT (Left)
                    flowConceptNode(label: "תשלום", sublabel: "Apple Pay")
                    flowArrowIndicator
                    flowConceptNode(label: "קיצורים", sublabel: "אוטומציה")
                    flowArrowIndicator
                    flowConceptNode(label: "SPENT", sublabel: "בניית העיר")
                } else {
                    // LTR reading: Payment (Left) → Shortcuts (Center) → SPENT (Right)
                    flowConceptNode(label: "Payment", sublabel: "Apple Pay")
                    flowArrowIndicator
                    flowConceptNode(label: "Shortcuts", sublabel: "Automation")
                    flowArrowIndicator
                    flowConceptNode(label: "SPENT", sublabel: "Builds City")
                }
            }
            .padding(.top, 12)

            // Technical accuracy & privacy clarification directly on canvas
            Text(isHebrew
                ? "\u{200F}SPENT לא מתחבר לבנק ולא קורא את Wallet ישירות."
                : "SPENT never connects to your bank or reads Wallet directly.")
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(Color.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(.top, 4)
    }

    private func flowConceptNode(label: String, sublabel: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
            Text(sublabel)
                .font(.system(size: 10.5, weight: .regular, design: .default))
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var flowArrowIndicator: some View {
        Image(systemName: isHebrew ? "arrow.left" : "arrow.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Color.textMuted.opacity(0.8))
    }

    // MARK: Step 4B - Shortcuts Setup Guide (Direct-on-canvas editorial numbered flow: 01 / 02 / 03)
    private var step4BGuideContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Step 01
            editorialNumberedStep(
                number: "01",
                title: isHebrew ? "צור אוטומציה מסוג עסקה" : "Create Transaction Automation",
                instruction: isHebrew
                    ? "בקיצורים: אוטומציה ← + ← עסקה (Transaction) ← הפעל מיד."
                    : "In Shortcuts: Automation → + → Transaction → Run Immediately."
            )

            Divider().overlay(Color.borderSubtle.opacity(0.6))

            // Step 02
            editorialNumberedStep(
                number: "02",
                title: isHebrew ? "בחר את הפעולה של SPENT" : "Select SPENT Action",
                instruction: isHebrew
                    ? "אוטומציה חדשה ← הוסף פעולה ← חפש SPENT ← הקלטת עסקת Apple Pay."
                    : "New Action → Search SPENT → Record Apple Pay Transaction."
            )

            Divider().overlay(Color.borderSubtle.opacity(0.6))

            // Step 03 with compact field mapping
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("03")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(isHebrew ? "חבר את השדות" : "Connect the Fields")
                            .font(.system(size: 13.5, weight: .semibold, design: .default))
                            .foregroundColor(Color.deepNavy)

                        Text(isHebrew ? "התאם את השדות לקלט הקיצור:" : "Map the fields to Shortcut Input:")
                            .font(.system(size: 11.5, weight: .regular, design: .default))
                            .foregroundColor(Color.textSecondary)
                    }
                }

                // Compact inline mapping
                VStack(alignment: .leading, spacing: 4) {
                    compactMappingRow(
                        source: isHebrew ? "סכום העסקה" : "Transaction Amount",
                        dest: isHebrew ? "סכום" : "Amount"
                    )
                    compactMappingRow(
                        source: isHebrew ? "שם בית העסק" : "Merchant Name",
                        dest: isHebrew ? "שם העסק" : "Merchant"
                    )
                }
                .padding(.leading, 32)
            }
        }
        .padding(.top, 4)
        .padding(.horizontal, 4)
    }

    private func editorialNumberedStep(number: String, title: String, instruction: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(number)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold, design: .default))
                    .foregroundColor(Color.deepNavy)

                Text(instruction)
                    .font(.system(size: 11.5, weight: .regular, design: .default))
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
                .font(.system(size: 8.5, weight: .bold))
                .foregroundColor(Color.textMuted)

            Text(dest)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Color.spentGreen)
        }
    }

    // MARK: Step 5 - Final City Reveal (Cinematic city payoff, minimal copy)
    private var step5LaunchSummary: some View {
        VStack(spacing: 8) {
            let name = userNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let mayorDisplayName = name.isEmpty ? (isHebrew ? "ראש העיר" : "Mayor") : name
            let amount = parsedBudget ?? (storedMonthlyBudget > 0 ? storedMonthlyBudget : 8000)
            let formattedBudget: String = {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                return formatter.string(from: NSNumber(value: amount)) ?? budgetInputText
            }()

            // Quiet metadata line directly on canvas
            Text(isHebrew ? "\(mayorDisplayName) · יעד חודשי ₪\(formattedBudget)" : "\(mayorDisplayName) · Monthly Target ₪\(formattedBudget)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Color.deepNavy)
                .padding(.top, 14)
        }
    }

    // MARK: - Bottom Action Bar
    @ViewBuilder
    private var bottomActionBar: some View {
        switch currentStep {
        case 1:
            primaryActionButton(title: isHebrew ? "בוא נבנה" : "Let's Build") {
                nextStep()
            }
        case 2:
            primaryActionButton(title: isHebrew ? "המשך ליעד" : "Continue to Target") {
                saveMayor()
                nextStep()
            }
        case 3:
            primaryActionButton(title: isHebrew ? "המשך לאוטומציה" : "Continue to Automation") {
                saveBudget()
                nextStep()
            }
        case 4:
            if shortcutPhase == "guide" {
                step4BActionButtons
            } else {
                step4AActionButtons
            }
        default:
            primaryActionButton(title: isHebrew ? "כניסה לעיר" : "Enter City") {
                Haptics.notify(.success)
                saveAllAndFinish()
            }
        }
    }

    // Step 4A Actions
    private var step4AActionButtons: some View {
        VStack(spacing: 8) {
            primaryActionButton(title: isHebrew ? "יאללה, בוא נגדיר" : "Let's Set It Up") {
                slideDirection = 1
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    shortcutPhase = "guide"
                }
            }

            Button(action: {
                Haptics.selection()
                slideDirection = 1
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    currentStep = 5
                }
            }) {
                Text(isHebrew ? "אעשה את זה אחר כך" : "I'll do this later")
                    .font(.system(size: 13.5, weight: .medium, design: .default))
                    .foregroundColor(Color.textSecondary)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    // Step 4B Actions: Open Shortcuts link + Continue
    private var step4BActionButtons: some View {
        VStack(spacing: 8) {
            #if os(iOS)
            if let url = URL(string: "shortcuts://") {
                Button(action: {
                    hasOpenedShortcuts = true
                    Haptics.impact(.medium)
                    UIApplication.shared.open(url)
                }) {
                    HStack(spacing: 6) {
                        MoneyIcon(.lightning, size: 15, color: .white)
                        Text(isHebrew ? "פתח את קיצורים" : "Open Shortcuts")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.themeOrange)
                    )
                }
                .buttonStyle(.plain)
                .bouncyPress(scale: 0.97)
            }
            #endif

            primaryActionButton(
                title: hasOpenedShortcuts
                    ? (isHebrew ? "סיימתי, המשך" : "Done, Continue")
                    : (isHebrew ? "אמשיך בלי לפתוח כרגע" : "Continue without opening")
            ) {
                nextStep()
            }
        }
    }

    // Refined, mature primary CTA: 54pt height, 18pt corner radius, flat with subtle neutral depth
    private func primaryActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.impact(.medium)
            action()
        }) {
            Text(title)
                .font(.system(size: 15.5, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.spentGreen)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1.5)
        }
        .buttonStyle(.plain)
        .bouncyPress(scale: 0.97)
    }

    private func nextStep() {
        slideDirection = 1
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            currentStep += 1
            if currentStep == 4 {
                shortcutPhase = "intro"
            }
        }
    }

    private func saveMayor() {
        let trimmed = userNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            storedUserName = trimmed
        }
    }

    /// BUDGET ≠ INCOME:
    /// Monthly budget is strictly a spending target, persisted via @AppStorage("monthly_budget").
    /// It must NOT create or update any IncomeSource record.
    private func saveBudget() {
        if let b = parsedBudget {
            storedMonthlyBudget = b
        }
        // Remove legacy onboarding IncomeSource entries if any exist
        let descriptor = FetchDescriptor<IncomeSource>()
        if let items = try? modelContext.fetch(descriptor) {
            var didDelete = false
            for item in items where item.name == "יעד חודשי" || item.name == "Monthly Target" {
                modelContext.delete(item)
                didDelete = true
            }
            if didDelete {
                try? modelContext.save()
            }
        }
    }

    private func saveAllAndFinish() {
        saveMayor()
        saveBudget()
        onTriggerSampleTransaction()
        onComplete()
    }

    // MARK: - Dynamic Step Titles & Subtitles (Final Approved Reference Copy)
    private var stepTitleText: String {
        switch currentStep {
        case 1:
            return isHebrew ? "ההוצאות שלך בונות עיר" : "Your Spending Builds a City"
        case 2:
            return isHebrew ? "מי ראש העיר?" : "Who's the Mayor?"
        case 3:
            return isHebrew ? "כמה היית רוצה להוציא החודש?" : "How much would you like to spend?"
        case 4:
            if shortcutPhase == "guide" {
                return isHebrew ? "הגדרת האוטומציה" : "Configure Automation"
            } else {
                return isHebrew ? "רוצה שהעיר תתעדכן לבד?" : "Want your city to update automatically?"
            }
        default:
            return isHebrew ? "העיר שלך מוכנה" : "Your City Is Ready"
        }
    }

    private var stepSubtitleText: String {
        switch currentStep {
        case 1:
            return isHebrew
                ? "כל תשלום משאיר משהו בעיר. לאורך החודש היא משתנה ומקבלת צורה."
                : "Every payment leaves something in the city. Over the month it takes shape."
        case 2:
            return isHebrew
                ? "רק שם קטן כדי שהעיר תדע למי היא שייכת."
                : "Just a name so the city knows who it belongs to."
        case 3:
            return isHebrew
                ? "זה יעד להוצאות, לא הכנסה. הוא נותן לחודש שלך מסגרת בלי לשפוט אותך."
                : "A spending target, not income. It gives your month context without judgment."
        case 4:
            if shortcutPhase == "guide" {
                return isHebrew
                    ? "שלושה שלבים ב״קיצורים״, ואז העסקאות יכולות להגיע ל־SPENT אוטומטית."
                    : "Three steps in Shortcuts, then transactions can reach SPENT automatically."
            } else {
                return isHebrew
                    ? "אפשר להגדיר אוטומציה ב״קיצורים״ שמופעלת אחרי תשלום ומעבירה ל־SPENT את פרטי העסקה שהאייפון מספק."
                    : "You can set up a Shortcuts automation that runs after payment and passes the transaction details iOS provides to SPENT."
            }
        default:
            return isHebrew
                ? "מכאן היא תשתנה יחד עם החודש שלך."
                : "From here, it will grow and change alongside your month."
        }
    }
}
