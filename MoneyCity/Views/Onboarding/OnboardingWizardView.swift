import SwiftUI
import SwiftData

/// Editorial onboarding with adaptive forms and a shared, event-driven city illustration kit.
public struct OnboardingWizardView: View {
    public let onComplete: () -> Void
    public let onTriggerSampleTransaction: () -> Void

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize: CGFloat = 48
    @ScaledMetric(relativeTo: .title) private var inputSize: CGFloat = 34

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
    @State private var didInitializeInputs: Bool = false
    @State private var userNameInput: String = ""
    @State private var budgetInputText: String = "8,000"
    @State private var hasOpenedShortcuts: Bool = false

    private let initialStepOverride: Int?
    private let initialPhaseOverride: String?
    private let canDismiss: Bool

    private var parsedBudget: Double? {
        let digits = budgetInputText.filter { $0.isNumber }
        guard let val = Double(digits), val > 0 else { return nil }
        return val
    }

    private func formatBudgetValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }

    private func formatBudgetString(_ text: String) -> String {
        let digits = text.filter { $0.isNumber }
        guard let val = Double(digits), val > 0 else { return text }
        return formatBudgetValue(val)
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
        GeometryReader { geometry in
            ZStack {
                activeOnboardingStep.posterBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    topNavigationRow
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            stepTitleSection
                                .padding(.horizontal, 26)

                            OnboardingCityScene(
                                step: activeOnboardingStep,
                                mayorName: userNameInput,
                                targetAmountText: formatBudgetString(budgetInputText),
                                isRTL: isHebrew,
                                height: heroHeight(availableHeight: geometry.size.height)
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)

                            VStack(alignment: .leading, spacing: 18) {
                                Text(stepSubtitleText)
                                    .font(.system(.body, design: .default))
                                    .foregroundStyle(posterInk.opacity(0.75))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(3)

                                stepBodyContent
                                    .id("onboardingInput")
                            }
                            .padding(.horizontal, 26)

                            Spacer(minLength: 20)
                        }
                        .frame(maxWidth: 560, alignment: .leading)
                        .frame(maxWidth: .infinity)
                        .id("\(currentStep)_\(shortcutPhase)")
                        .transition(reduceMotion ? .opacity : .asymmetric(
                            insertion: .offset(x: transitionDirection * 30).combined(with: .opacity),
                            removal: .offset(x: -transitionDirection * 20).combined(with: .opacity)
                        ))
                    }
                    .scrollDismissesKeyboard(.interactively)

                    bottomActionBar
                        .frame(maxWidth: 508)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        .padding(.bottom, 14)
                        .frame(maxWidth: .infinity)
                        .background(activeOnboardingStep.posterBackground)
                }
            }
        }
        .onAppear {
            guard !didInitializeInputs else { return }
            didInitializeInputs = true
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
                budgetInputText = formatBudgetValue(storedMonthlyBudget)
            } else {
                budgetInputText = formatBudgetValue(8000)
            }
        }
        .onChange(of: currentStep) { _, _ in
            focusedField = nil
        }
        .onChange(of: focusedField) { oldField, newField in
            if oldField == .budget && newField != .budget {
                budgetInputText = formatBudgetString(budgetInputText)
            } else if newField == .budget {
                budgetInputText = budgetInputText.filter { $0.isNumber }
            }
        }
        .environment(\.layoutDirection, isHebrew ? .rightToLeft : .leftToRight)
    }

    private var posterInk: Color { currentStep == 5 ? .white : .jetBlack }
    private var pageAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .easeInOut(duration: 0.3)
    }
    private var transitionDirection: CGFloat {
        CGFloat(slideDirection) * (isHebrew ? -1 : 1)
    }

    private func heroHeight(availableHeight: CGFloat) -> CGFloat {
        if currentStep == 4 && shortcutPhase == "guide" { return 170 }
        if dynamicTypeSize.isAccessibilitySize { return 210 }
        return min(290, max(240, availableHeight * 0.36))
    }

    // MARK: - Stable navigation and five editorial progress rules
    private var topNavigationRow: some View {
        HStack(spacing: 18) {
            Button(action: handleBackNavigation) {
                Image(systemName: isHebrew ? "arrow.right" : "arrow.left")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(posterInk)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isHebrew ? "חזרה" : "Back")
            .opacity(currentStep > 1 ? 1 : 0)
            .disabled(currentStep == 1)
            .accessibilityHidden(currentStep == 1)

            stepProgressIndicator

            Group {
                if canDismiss {
                    Button(action: onComplete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(posterInk)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isHebrew ? "סגירה" : "Close")
                } else {
                    Color.clear.frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    private func handleBackNavigation() {
        Haptics.selection()
        if currentStep == 4 && shortcutPhase == "guide" {
            slideDirection = -1
            withAnimation(pageAnimation) {
                shortcutPhase = "intro"
            }
        } else if currentStep > 1 {
            slideDirection = -1
            withAnimation(pageAnimation) {
                currentStep -= 1
                if currentStep == 4 {
                    shortcutPhase = "intro"
                }
            }
        }
    }

    private var stepProgressIndicator: some View {
        HStack(spacing: 7) {
            ForEach(1...5, id: \.self) { stepNumber in
                Rectangle()
                    .fill(posterInk.opacity(stepNumber == currentStep ? 1 : 0.22))
                    .frame(height: 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isHebrew ? "שלב \(currentStep) מתוך 5" : "Step \(currentStep) of 5")
    }

    private var stepTitleSection: some View {
        Text(stepTitleText)
            .font(.system(size: headlineSize, weight: .heavy, design: .default))
            .tracking(isHebrew ? -1 : -1.8)
            .foregroundStyle(posterInk)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
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

    // MARK: Step 1 — one quiet supporting fact
    private var step1ConceptBody: some View {
        Label(isHebrew ? "המידע נשאר על המכשיר" : "Your data stays on your device",
              systemImage: "lock")
            .font(.system(.footnote, design: .default))
            .foregroundStyle(posterInk.opacity(0.7))
            .padding(.top, 4)
    }

    // MARK: Step 2 — live city sign, simple editable baseline
    private var step2MayorInput: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(isHebrew ? "השם שלך" : "Your name")
                .font(.system(.subheadline, design: .default))
                .foregroundStyle(Color.jetBlack.opacity(0.7))

            TextField(isHebrew ? "איך קוראים לך?" : "What’s your name?", text: $userNameInput)
                .font(.system(size: inputSize, weight: .bold))
                .foregroundStyle(Color.jetBlack)
                .tint(.jetBlack)
                .multilineTextAlignment(.leading)
                .focused($focusedField, equals: .mayorName)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .submitLabel(.next)
                .onSubmit {
                    saveMayor()
                    nextStep()
                }
                .accessibilityLabel(isHebrew ? "השם שלך" : "Your name")
                .padding(.vertical, 8)

            Rectangle()
                .fill(Color.jetBlack.opacity(focusedField == .mayorName ? 1 : 0.35))
                .frame(height: focusedField == .mayorName ? 2 : 1)
        }
    }

    // MARK: Step 3 - Monthly Spending Target (Tonal editable surface, clean presets, BUDGET ≠ INCOME)
    private var step3BudgetConfig: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(l10n.baseCurrency.symbol)
                    .font(.system(size: inputSize * 0.8, weight: .medium))

                TextField("", text: $budgetInputText)
                    .font(.system(size: inputSize * 1.4, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.jetBlack)
                    .tint(.jetBlack)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .budget)
                    .accessibilityLabel(isHebrew ? "יעד הוצאה חודשי" : "Monthly spending target")
            }
            .foregroundStyle(Color.jetBlack)
            .environment(\.layoutDirection, .leftToRight)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture { focusedField = .budget }

            Rectangle()
                .fill(Color.jetBlack.opacity(focusedField == .budget ? 1 : 0.35))
                .frame(height: focusedField == .budget ? 2 : 1)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { budgetPresets }
                VStack(alignment: .leading, spacing: 4) { budgetPresets }
            }

            Text(isHebrew ? "אפשר לשנות את היעד אחר כך" : "You can change your target later")
                .font(.system(.footnote, design: .default))
                .foregroundStyle(Color.jetBlack.opacity(0.7))
        }
    }

    private var budgetPresets: some View {
        ForEach(["5000", "8000", "12000", "15000"], id: \.self) { amount in
            budgetPresetOption(amount: amount)
        }
    }

    private func budgetPresetOption(amount: String) -> some View {
        let isSelected = budgetInputText.filter { $0.isNumber } == amount
        return Button(action: {
            Haptics.selection()
            budgetInputText = formatBudgetString(amount)
            focusedField = nil
        }) {
            Text("\(l10n.baseCurrency.symbol)\(formatBudgetString(amount))")
                .font(.system(.subheadline, design: .rounded, weight: isSelected ? .bold : .regular))
                .fixedSize()
                .foregroundStyle(Color.jetBlack)
                .padding(.horizontal, 8)
                .frame(minHeight: 44)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(isSelected ? Color.jetBlack : .clear).frame(height: 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Step 4A — the hero scene carries the payment → Shortcuts → city relationship
    private var step4AIntroContent: some View {
        Text(isHebrew
            ? "\u{200F}SPENT לא מתחבר לבנק ולא קורא את Wallet ישירות."
            : "SPENT never connects to your bank or reads Wallet directly.")
            .font(.system(.footnote, design: .default))
            .foregroundStyle(Color.jetBlack.opacity(0.7))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Step 4B - Shortcuts Setup Guide (Direct-on-canvas editorial numbered flow: 01 / 02 / 03)
    private var step4BGuideContent: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            // Step 03 with explicit 2-step field mapping
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("03")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(isHebrew ? "חבר את נתוני העסקה" : "Connect Transaction Data")
                            .font(.system(.subheadline, design: .default, weight: .semibold))
                            .foregroundColor(Color.deepNavy)

                        Text(isHebrew ? "לחץ על כל שדה, בחר ״קלט הקיצור״ ואז את המאפיין:" : "Tap each field, select \"Shortcut Input\" then the attribute:")
                            .font(.system(.footnote, design: .default))
                            .foregroundColor(Color.textSecondary)
                    }
                }

                // Compact inline mapping
                VStack(alignment: .leading, spacing: 5) {
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
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundColor(Color.deepNavy)

                Text(instruction)
                    .font(.system(.footnote, design: .default))
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

    // MARK: Step 5 - Final City Reveal (Cinematic city payoff, minimal copy)
    private var step5LaunchSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.white)
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
                withAnimation(pageAnimation) {
                    shortcutPhase = "guide"
                }
            }

            Button(action: {
                Haptics.selection()
                slideDirection = 1
                withAnimation(pageAnimation) {
                    currentStep = 5
                }
            }) {
                Text(isHebrew ? "אעשה את זה אחר כך" : "I'll do this later")
                    .font(.system(.subheadline, design: .default, weight: .medium))
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
                        MoneyIcon(.lightning, size: 18, color: .jetBlack)
                        Text(isHebrew ? "פתח את קיצורים" : "Open Shortcuts")
                            .font(.system(.body, design: .default, weight: .semibold))
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

    // One graphic primary action across the sequence.
    private func primaryActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.impact(.medium)
            action()
        }) {
            Text(title)
                .font(.system(.body, design: .default, weight: .semibold))
                .foregroundColor(currentStep == 5 ? .jetBlack : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .frame(minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(currentStep == 5 ? Color.neonLime : Color.jetBlack)
                )
        }
        .buttonStyle(.plain)
        .bouncyPress(scale: reduceMotion ? 1 : 0.97)
    }

    private func nextStep() {
        slideDirection = 1
        withAnimation(pageAnimation) {
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
            return isHebrew ? "ההוצאות שלך\nבונות עיר" : "Your spending.\nA city in the making."
        case 2:
            return isHebrew ? "עיר עם\nהשם שלך" : "A city with\nyour name."
        case 3:
            return isHebrew ? "מסגרת\nלחודש שלך" : "Your month.\nYour target."
        case 4:
            if shortcutPhase == "guide" {
                return isHebrew ? "מחברים\nאת הקיצורים" : "Set up\nShortcuts."
            } else {
                return isHebrew ? "משלמים.\nהעיר מתעדכנת." : "Make a payment.\nShape your city."
            }
        default:
            return isHebrew ? "העיר שלך\nמוכנה" : "Your city\nis ready."
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
                ? "כמה היית רוצה להוציא החודש? זה יעד להוצאות, לא הכנסה."
                : "How much would you like to spend this month? This is a spending target, not income."
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

// Isolated previews use an in-memory model container; no onboarding navigation is required.
#Preview("Onboarding • Concept") {
    OnboardingWizardView(initialStep: 1, onComplete: {}, onTriggerSampleTransaction: {})
        .environmentObject(LocalizationManager())
        .modelContainer(for: IncomeSource.self, inMemory: true)
}

#Preview("Onboarding • Name") {
    OnboardingWizardView(initialStep: 2, onComplete: {}, onTriggerSampleTransaction: {})
        .environmentObject(LocalizationManager())
        .modelContainer(for: IncomeSource.self, inMemory: true)
}

#Preview("Onboarding • Target") {
    OnboardingWizardView(initialStep: 3, onComplete: {}, onTriggerSampleTransaction: {})
        .environmentObject(LocalizationManager())
        .modelContainer(for: IncomeSource.self, inMemory: true)
}

#Preview("Onboarding • Shortcuts") {
    OnboardingWizardView(initialStep: 4, onComplete: {}, onTriggerSampleTransaction: {})
        .environmentObject(LocalizationManager())
        .modelContainer(for: IncomeSource.self, inMemory: true)
}

#Preview("Onboarding • Shortcuts guide") {
    OnboardingWizardView(initialStep: 4, initialPhase: "guide", onComplete: {}, onTriggerSampleTransaction: {})
        .environmentObject(LocalizationManager())
        .modelContainer(for: IncomeSource.self, inMemory: true)
}

#Preview("Onboarding • Reveal") {
    OnboardingWizardView(initialStep: 5, onComplete: {}, onTriggerSampleTransaction: {})
        .environmentObject(LocalizationManager())
        .modelContainer(for: IncomeSource.self, inMemory: true)
}
