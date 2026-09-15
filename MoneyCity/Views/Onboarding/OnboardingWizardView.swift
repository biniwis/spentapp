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
    @AppStorage("spent.onboarding.currentStep") private var storedCurrentStep: Int = 1
    @AppStorage("spent.onboarding.shortcutPhase") private var storedShortcutPhase: String = "intro" // "intro" (4A) or "guide" (4B)
    @State private var currentStep: Int = 1
    @State private var shortcutPhase: String = "intro"

    private enum OnboardingField: Hashable {
        case mayorName
        case budget
    }
    @FocusState private var focusedField: OnboardingField?

    @State private var slideDirection: Int = 1 // 1 = forward, -1 = backward
    @State private var didInitializeInputs: Bool = false
    @State private var userNameInput: String = ""
    @State private var budgetInputText: String = ""
    @State private var hasOpenedShortcuts: Bool = false
    @State private var showCaptureGuide: Bool = false

    private let initialStepOverride: Int?
    private let initialPhaseOverride: String?
    private let canDismiss: Bool
    private let isPreview: Bool

    public static func sanitizedBudgetDigits(_ text: String) -> String {
        let beforeDecimal = text.components(separatedBy: ".").first ?? text
        return String(beforeDecimal.filter { $0 >= "0" && $0 <= "9" }.prefix(9))
    }

    private func sanitizedBudgetDigits(_ text: String) -> String {
        Self.sanitizedBudgetDigits(text)
    }

    private var parsedBudget: Double? {
        let digits = sanitizedBudgetDigits(budgetInputText)
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
        let digits = sanitizedBudgetDigits(text)
        guard let val = Double(digits), val > 0 else { return text }
        return formatBudgetValue(val)
    }

    private var isHebrew: Bool {
        l10n.isHebrew
    }

    private struct NumericLTRTextFieldModifier: ViewModifier {
        @ViewBuilder
        func body(content: Content) -> some View {
            if #available(iOS 26.0, *) {
                content
                    .environment(\.layoutDirection, .leftToRight)
                    .multilineTextAlignment(.leading)
                    .multilineTextAlignment(strategy: .layoutBased)
                    .writingDirection(strategy: .layoutBased)
            } else {
                content
                    .environment(\.layoutDirection, .leftToRight)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private var activeOnboardingStep: OnboardingStep {
        OnboardingStep(rawValue: currentStep) ?? .concept
    }

    public init(
        initialStep: Int? = nil,
        initialPhase: String? = nil,
        canDismiss: Bool = false,
        isPreview: Bool = false,
        onComplete: @escaping () -> Void,
        onTriggerSampleTransaction: @escaping () -> Void
    ) {
        self.initialStepOverride = initialStep
        self.initialPhaseOverride = initialPhase
        self.canDismiss = canDismiss
        self.isPreview = isPreview
        self.onComplete = onComplete
        self.onTriggerSampleTransaction = onTriggerSampleTransaction
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                activeOnboardingStep.posterBackground.ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField = nil
                    }

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
                                currencySymbol: l10n.baseCurrency.symbol,
                                isRTL: isHebrew,
                                height: heroHeight(availableHeight: geometry.size.height)
                            )
                            .environment(\.layoutDirection, .leftToRight)
                            .padding(.horizontal, 12)

                            VStack(alignment: .leading, spacing: 18) {
                                Text(stepSubtitleText)
                                    .font(.system(.body, design: .rounded))
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

                    Spacer(minLength: 16)

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
            if canDismiss || isPreview {
                currentStep = initialStepOverride ?? 1
                shortcutPhase = initialPhaseOverride ?? "intro"
            } else {
                currentStep = initialStepOverride ?? storedCurrentStep
                shortcutPhase = initialPhaseOverride ?? storedShortcutPhase
            }
            if !storedUserName.isEmpty && userNameInput.isEmpty {
                userNameInput = storedUserName
            } else if isPreview && userNameInput.isEmpty {
                userNameInput = isHebrew ? "דניאל" : "Alex"
            }
            if storedMonthlyBudget > 0 {
                budgetInputText = String(format: "%.0f", storedMonthlyBudget)
            } else if isPreview && budgetInputText.isEmpty {
                budgetInputText = "8000"
            }
        }
        .onChange(of: currentStep) { _, newStep in
            if !canDismiss && !isPreview {
                storedCurrentStep = newStep
            }
            focusedField = nil
        }
        .onChange(of: shortcutPhase) { _, newPhase in
            if !canDismiss && !isPreview {
                storedShortcutPhase = newPhase
            }
        }
        .onChange(of: budgetInputText) { _, newValue in
            let sanitized = sanitizedBudgetDigits(newValue)
            if sanitized != newValue {
                budgetInputText = sanitized
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(isHebrew ? "סיום" : "Done") {
                    focusedField = nil
                }
                .fontWeight(.semibold)
            }
        }
        .fullScreenCover(isPresented: $showCaptureGuide) {
            AutomaticCaptureSetupGuide(
                skipIntro: true,       // 4A already served as the intro
                showCloseButton: true,
                onFinished: {
                    showCaptureGuide = false
                    // Advance to the city reveal (step 5)
                    slideDirection = 1
                    withAnimation(pageAnimation) {
                        currentStep = 5
                    }
                }
            )
            .environmentObject(l10n)
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
                Image(systemName: "arrow.left")
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
            .font(.system(size: headlineSize, weight: .heavy, design: .rounded))
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
            // Guide (step4B) is now a fullScreenCover (AutomaticCaptureSetupGuide).
            // Step 4 always shows the intro reassurance.
            step4AIntroContent
        default:
            step5LaunchSummary
        }
    }

    // MARK: Step 1 — one quiet supporting fact
    private var step1ConceptBody: some View {
        Label(isHebrew ? "המידע נשאר על המכשיר" : "Your data stays on your device",
              systemImage: "lock")
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(posterInk.opacity(0.7))
            .padding(.top, 4)
    }

    // MARK: Step 2 — live city sign, simple editable baseline
    private var step2MayorInput: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(isHebrew ? "השם שלך" : "Your name")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.jetBlack.opacity(0.7))

            TextField(isHebrew ? "איך קוראים לך?" : "What’s your name?", text: $userNameInput)
                .font(.system(size: inputSize, weight: .bold, design: .rounded))
                .foregroundStyle(Color.jetBlack)
                .tint(.jetBlack)
                .multilineTextAlignment(.leading)
                .focused($focusedField, equals: .mayorName)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .submitLabel(.next)
                .onSubmit {
                    let isNameValid = !userNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    if isNameValid {
                        saveMayor()
                        nextStep()
                    }
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
            HStack(alignment: .center, spacing: 8) {
                Text(l10n.baseCurrency.symbol)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.jetBlack)

                TextField("8,000", text: $budgetInputText)
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.jetBlack)
                    .tint(Color.jetBlack)
                    .keyboardType(.asciiCapableNumberPad)
                    .focused($focusedField, equals: .budget)
                    .modifier(NumericLTRTextFieldModifier())
                    .onSubmit {
                        let isBudgetValid = (parsedBudget ?? 0) > 0
                        if isBudgetValid {
                            saveBudget()
                            nextStep()
                        }
                    }
                    .accessibilityLabel(isHebrew ? "יעד הוצאה חודשי" : "Monthly spending target")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .leftToRight)
            .padding(.vertical, 6)

            Rectangle()
                .fill(Color.jetBlack.opacity(focusedField == .budget ? 1 : 0.35))
                .frame(height: focusedField == .budget ? 2 : 1)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { budgetPresets }
                VStack(alignment: .leading, spacing: 4) { budgetPresets }
            }

            Text(isHebrew ? "אפשר לשנות את היעד אחר כך" : "You can change your target later")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.jetBlack.opacity(0.7))
        }
    }

    private var budgetPresets: some View {
        ForEach(["5000", "8000", "12000", "15000"], id: \.self) { amount in
            budgetPresetOption(amount: amount)
        }
    }

    private func budgetPresetOption(amount: String) -> some View {
        let isSelected = budgetInputText == amount
        return Button(action: {
            Haptics.selection()
            budgetInputText = amount
            focusedField = nil
        }) {
            let displayAmount = formatBudgetString(amount)
            Text("\(l10n.baseCurrency.symbol)\(displayAmount)")
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

    // MARK: Step 4A — quiet reassurance
    private var step4AIntroContent: some View {
        Text(isHebrew
            ? "SPENT לא מקבלת גישה לכרטיס או לחשבון הבנק שלך."
            : "SPENT doesn’t get access to your card or bank account.")
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(Color.jetBlack.opacity(0.7))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }


    // MARK: Step 5 - Final City Reveal (Cinematic city payoff, minimal copy)
    private var step5LaunchSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            let name = userNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let mayorDisplayName = name.isEmpty ? (isHebrew ? "ראש העיר" : "Mayor") : name
            let amount = parsedBudget ?? (storedMonthlyBudget > 0 ? storedMonthlyBudget : nil)
            let targetText: String = {
                if let amount = amount {
                    let formatter = NumberFormatter()
                    formatter.numberStyle = .decimal
                    let formattedBudget = formatter.string(from: NSNumber(value: amount)) ?? budgetInputText
                    return "\(l10n.baseCurrency.symbol)\(formattedBudget)"
                } else {
                    return "—"
                }
            }()

            // Quiet metadata line directly on canvas
            Text(isHebrew ? "\(mayorDisplayName) · יעד חודשי \(targetText)" : "\(mayorDisplayName) · Monthly Target \(targetText)")
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
            let isNameValid = !userNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            primaryActionButton(
                title: isHebrew ? "המשך ליעד" : "Continue to Target",
                isEnabled: isNameValid
            ) {
                guard isNameValid else { return }
                saveMayor()
                nextStep()
            }
        case 3:
            let isBudgetValid = (parsedBudget ?? 0) > 0
            primaryActionButton(
                title: isHebrew ? "המשך לקליטה אוטומטית" : "Continue to Automatic Capture",
                isEnabled: isBudgetValid
            ) {
                guard isBudgetValid else { return }
                saveBudget()
                nextStep()
            }
        case 4:
            step4AActionButtons
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
            primaryActionButton(title: isHebrew ? "הגדר קליטה אוטומטית" : "Set Up Automatic Capture") {
                Haptics.impact(.medium)
                showCaptureGuide = true
            }

            Button(action: {
                Haptics.selection()
                slideDirection = 1
                withAnimation(pageAnimation) {
                    currentStep = 5
                }
            }) {
                Text(isHebrew ? "אעשה את זה אחר כך" : "I'll do this later")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(Color.textSecondary)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    // One graphic primary action across the sequence.
    private func primaryActionButton(
        title: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            guard isEnabled else { return }
            Haptics.impact(.medium)
            action()
        }) {
            Text(title)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundColor(currentStep == 5 ? .jetBlack : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .frame(minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(currentStep == 5 ? Color.neonLime : Color.jetBlack)
                )
                .opacity(isEnabled ? 1.0 : 0.38)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .bouncyPress(scale: (reduceMotion || !isEnabled) ? 1 : 0.97)
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
    }

    private func saveAllAndFinish() {
        if !isPreview {
            saveMayor()
            saveBudget()
            if !canDismiss {
                storedCurrentStep = 1
                storedShortcutPhase = "intro"
            }
            onTriggerSampleTransaction()
        }
        onComplete()
    }

    // MARK: - Dynamic Step Titles & Subtitles (Final Approved Reference Copy)
    private var stepTitleText: String {
        switch currentStep {
        case 1:
            return isHebrew ? "ההוצאות שלך\nמקבלות צורה בעיר" : "Your spending\ntakes shape in the city."
        case 2:
            return isHebrew ? "עיר עם\nהשם שלך" : "A city with\nyour name."
        case 3:
            return isHebrew ? "מסגרת\nלחודש שלך" : "Your month.\nYour target."
        case 4:
            if shortcutPhase == "guide" {
                return isHebrew ? "הגדרת\nקליטה אוטומטית" : "Set Up\nAutomatic Capture"
            } else {
                return isHebrew ? "ההוצאות יכולות\nלהיכנס לבד" : "Expenses can\nshow up automatically"
            }
        default:
            return isHebrew ? "העיר שלך\nמוכנה" : "Your city\nis ready."
        }
    }

    private var stepSubtitleText: String {
        switch currentStep {
        case 1:
            return isHebrew
                ? "כשנרשמת הוצאה, העיר משתנה ומשקפת אותה. לאורך החודש נוצרת תמונה של ההרגלים שלך."
                : "When an expense is recorded, the city reflects it. Over the month, your patterns take shape."
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
                    ? "ההגדרה נעשית באפליקציית ״קיצורים״ של Apple שכבר נמצאת באייפון שלך."
                    : "Setup is done in Apple's Shortcuts app, already on your iPhone."
            } else {
                return isHebrew
                    ? "אחרי תשלום, האייפון יכול להעביר ל-SPENT כמה שילמת ואיפה — וההוצאה נכנסת לבד."
                    : "After a payment, your iPhone can pass SPENT the amount and merchant so the expense can be added automatically."
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
