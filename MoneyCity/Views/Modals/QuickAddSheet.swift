import SwiftUI
import SwiftData
import AppIntents

/// Fast-Add modal sheet matching the art-directed modern design system.
@MainActor
public struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var l10n: LocalizationManager
    public let initialCategory: SpendingCategory?
    public let initialCategoryIsExplicit: Bool
    public let initialMerchant: String?
    public let initialBuildingId: String?
    public let initialDate: Date
    public let allowsDateEditing: Bool
    public typealias OnSaveAction = (
        _ amount: Double,
        _ category: SpendingCategory,
        _ merchant: String,
        _ originalAmount: Double?,
        _ originalCurrency: String?,
        _ exchangeRate: Double?,
        _ buildingId: String?,
        _ isCategoryExplicit: Bool,
        _ transactionDate: Date
    ) -> Void

    public let titleOverride: String?
    public let onSave: OnSaveAction
    
    public init(
        initialCategory: SpendingCategory? = nil,
        initialCategoryIsExplicit: Bool = false,
        initialCurrency: CurrencyType? = nil,
        initialMerchant: String? = nil,
        initialBuildingId: String? = nil,
        initialDate: Date = Date(),
        allowsDateEditing: Bool = true,
        titleOverride: String? = nil,
        onSave: @escaping (_ amount: Double, _ category: SpendingCategory, _ merchant: String, _ originalAmount: Double?, _ originalCurrency: String?, _ exchangeRate: Double?, _ buildingId: String?) -> Void
    ) {
        self.initialCategory = initialCategory
        self.initialCategoryIsExplicit = initialCategoryIsExplicit
        self.initialMerchant = initialMerchant
        self.initialBuildingId = initialBuildingId
        self.initialDate = initialDate
        self.allowsDateEditing = allowsDateEditing
        self.titleOverride = titleOverride
        self.onSave = { amount, cat, merch, origAmt, origCurr, rate, bId, _, _ in
            onSave(amount, cat, merch, origAmt, origCurr, rate, bId)
        }
        _selectedCurrency = State(initialValue: initialCurrency ?? LocalizationManager.shared.baseCurrency)
        _transactionDate = State(initialValue: initialDate)
        if let initialMerchant, !initialMerchant.isEmpty {
            _note = State(initialValue: initialMerchant)
        }
        if let initialBuildingId {
            _selectedBuildingId = State(initialValue: initialBuildingId)
        }
    }

    public init(
        initialCategory: SpendingCategory? = nil,
        initialCategoryIsExplicit: Bool = false,
        initialCurrency: CurrencyType? = nil,
        initialMerchant: String? = nil,
        initialBuildingId: String? = nil,
        initialDate: Date = Date(),
        allowsDateEditing: Bool = true,
        titleOverride: String? = nil,
        onSaveWithExplicitFlag: @escaping OnSaveAction
    ) {
        self.initialCategory = initialCategory
        self.initialCategoryIsExplicit = initialCategoryIsExplicit
        self.initialMerchant = initialMerchant
        self.initialBuildingId = initialBuildingId
        self.initialDate = initialDate
        self.allowsDateEditing = allowsDateEditing
        self.titleOverride = titleOverride
        self.onSave = onSaveWithExplicitFlag
        _selectedCurrency = State(initialValue: initialCurrency ?? LocalizationManager.shared.baseCurrency)
        _transactionDate = State(initialValue: initialDate)
        if let initialMerchant, !initialMerchant.isEmpty {
            _note = State(initialValue: initialMerchant)
        }
        if let initialBuildingId {
            _selectedBuildingId = State(initialValue: initialBuildingId)
        }
    }
    
    @State private var amountText: String = ""
    @State private var note: String = ""
    @State private var selectedCurrency: CurrencyType = .ils
    @State private var selectedCategory: SpendingCategory? = nil
    @State private var userExplicitlySelectedCategory: Bool = false
    @State private var selectedBuildingId: String? = nil
    @State private var showErrorHint = false
    @State private var paymentCount: Int = 1

    @State private var showAdvancedOptions = false
    @State private var cursorVisible = true
    @State private var transactionDate = Date()
    @State private var tempSelectedDate = Date()
    @State private var showDatePickerOverlay = false
    @State private var showCategoryPickerSheet = false
    @State private var categoryPickerSubcategoryCategory: SpendingCategory? = nil
    @State private var amountPunchScale: CGFloat = 1.0

    @Environment(\.modelContext) private var modelContext
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isNoteFocused: Bool
    
    private func parseAmount(_ text: String) -> Double? {
        let clean = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
        // Everything the user can type goes through the shared ceiling. A long paste used to
        // become 1e20, save fine, and then trap every Int() money display in the app.
        return MoneyAmount.sanitized(Double(clean))
    }

    private func dismissKeyboard() {
        isAmountFocused = false
        isNoteFocused = false
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    /// The primary distinct categories for user selection (including finance and other/sorting hub)
    private var allCategories: [SpendingCategory] {
        SpendingCategory.primaryCategories
    }
    
    /// Displays the entered amount with thousands separator commas (e.g. 20000 -> 20,000)
    private var displayAmountString: String {
        if amountText.isEmpty {
            return "0.00"
        }
        let parts = amountText.split(separator: ".", omittingEmptySubsequences: false)
        let intPart = String(parts[0])

        let formattedInt: String
        if let val = Double(intPart) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            formatter.maximumFractionDigits = 0
            formattedInt = formatter.string(from: NSNumber(value: val)) ?? intPart
        } else {
            formattedInt = intPart
        }

        if parts.count > 1 {
            return "\(formattedInt).\(parts[1])"
        } else if amountText.hasSuffix(".") {
            return "\(formattedInt)."
        } else {
            return formattedInt
        }
    }

    private var displayAmountFontSize: CGFloat {
        let count = displayAmountString.count
        if count <= 6 { return 44 }
        if count <= 9 { return 38 }
        return 32
    }


    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboard()
                    }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // ── 1. Hero Amount Display (Reference: ₪0.00 with cursor) ──
                        HStack(alignment: .center, spacing: 6) {
                            Menu {
                                ForEach(CurrencyType.allCases) { curr in
                                    Button {
                                        Haptics.selection()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            selectedCurrency = curr
                                        }
                                    } label: {
                                        HStack {
                                            Text(l10n.language == .hebrew ? curr.displayNameHebrew : curr.displayNameEnglish)
                                            if selectedCurrency == curr {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Text(selectedCurrency.symbol)
                                        .font(.system(size: displayAmountFontSize, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.deepNavy)

                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.primaryBlue)
                                        .padding(4)
                                        .background(Color.primaryBlue.opacity(0.10), in: Circle())
                                        .offset(y: 2)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .bouncyPress(scale: 0.94)
                            .accessibilityLabel(l10n.language == .hebrew ? "החלף מטבע" : "Change currency")

                            Text(displayAmountString)
                                .font(.system(size: displayAmountFontSize, weight: .bold, design: .rounded))
                                .foregroundColor(amountText.isEmpty ? Color.textMuted.opacity(0.6) : Color.deepNavy)
                                .scaleEffect(amountPunchScale)
                                .animation(.spring(response: 0.18, dampingFraction: 0.6), value: amountPunchScale)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            // Blinking cursor
                            Rectangle()
                                .fill(Color.primaryBlue)
                                .frame(width: 2.5, height: displayAmountFontSize * 0.9)
                                .opacity(cursorVisible ? 1.0 : 0.0)
                        }
                        .environment(\.layoutDirection, .leftToRight)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                        .padding(.bottom, 12)

                        // Currency switcher pill if foreign
                        if selectedCurrency != l10n.baseCurrency, let val = parseAmount(amountText), val > 0 {
                            let inBase = CurrencyType.convert(amount: val, from: selectedCurrency, to: l10n.baseCurrency)
                            HStack(spacing: 4) {
                                ExchangeVectorIcon(color: Color.themeMint)
                                Text("≈ \(l10n.format(amount: inBase, showDecimals: true))")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                            .environment(\.layoutDirection, .leftToRight)
                            .foregroundColor(Color.themeMint)
                            .padding(.bottom, 8)
                        }

                        // ── 2. Built-in Numeric Keypad (Reference Screen 5) ──
                        numericKeypadView
                            .environment(\.layoutDirection, .leftToRight)
                            .padding(.horizontal, 20)

                        // ── 3. Category Cluster (Category + Subcategory Chips) ──
                        categoryClusterSection
                            .padding(.top, 18)

                        // ── 4. Merchant Field ──
                        merchantField
                            .padding(.top, 14)

                        // ── 5. Secondary Utility Row (Date + More Options) ──
                        utilityRow
                            .padding(.top, 10)

                        if showAdvancedOptions {
                            expandableMoreOptionsSection
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        }

                        // ── 6. Save Button (Solid Black Rounded Button) ──
                        saveTransactionButton
                            .padding(.top, 18)

                        Spacer(minLength: 24)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isNoteFocused {
                            dismissKeyboard()
                        }
                    }
                }
                .scrollDismissesKeyboard(.immediately)

                // Modal Popup Overlay for Category Selection (fast popup, no page scrolling)
                if showCategoryPickerSheet {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                showCategoryPickerSheet = false
                            }
                        }
                        .transition(.opacity)

                    categoryPickerModalView
                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                        .zIndex(100)
                }

                // Modal Popup Overlay for Date Selection (no page scrolling, fast modal popup)
                if showDatePickerOverlay {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                showDatePickerOverlay = false
                            }
                        }
                        .transition(.opacity)

                    datePickerModalView
                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                        .zIndex(100)
                }
            }
            .navigationTitle(titleOverride ?? (l10n.language == .hebrew ? "הוספת הוצאה" : "Add Expense"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        MoneyIcon(.xmarkCircle, size: 24)
                            .frame(width: 32, height: 32)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.05), radius: 3, y: 1)
                    }
                }

            }
            .onAppear {
                if amountText.isEmpty && selectedCurrency != l10n.baseCurrency {
                    selectedCurrency = l10n.baseCurrency
                }
                if let initial = initialCategory {
                    selectedCategory = initial
                } else if selectedCategory == nil {
                    selectedCategory = .food
                }
                if let initialMerchant, note.isEmpty {
                    note = initialMerchant
                }
                if let initialBuildingId, selectedBuildingId == nil {
                    selectedBuildingId = initialBuildingId
                }
            }
            .task(id: scenePhase == .active && !reduceMotion) {
                guard scenePhase == .active, !reduceMotion else {
                    cursorVisible = true
                    return
                }
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(nanoseconds: 550_000_000)
                    } catch {
                        return
                    }
                    cursorVisible.toggle()
                }
            }
        }
    }

    // MARK: - Numeric Keypad View (Tactile Micro-Interactions)
    @ViewBuilder @MainActor
    private var numericKeypadView: some View {
        SpentAmountKeypad(amountText: $amountText) { _ in
            if isNoteFocused {
                dismissKeyboard()
            }
            // Tactile punch micro-interaction on hero amount display
            withAnimation(.spring(response: 0.12, dampingFraction: 0.48)) {
                amountPunchScale = 1.09
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.65)) {
                    amountPunchScale = 1.0
                }
            }
        }
    }

    private func formattedDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: l10n.language == .hebrew ? "he_IL" : "en_US")
        if Calendar.current.isDateInToday(date) {
            return l10n.language == .hebrew ? "היום" : "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return l10n.language == .hebrew ? "אתמול" : "Yesterday"
        } else if Calendar.current.isDateInTomorrow(date) {
            return l10n.language == .hebrew ? "מחר" : "Tomorrow"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    // MARK: - Dynamic Building Chips (Inside Category Cluster)
    @ViewBuilder @MainActor
    private func buildingChipsRow(cat: SpendingCategory, buildings: [CityBuilding]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(buildings) { b in
                    let isBSelected = (selectedBuildingId == b.id)
                    Button(action: {
                        dismissKeyboard()
                        Haptics.selection()
                        withAnimation(.spring(response: 0.25)) {
                            selectedBuildingId = b.id
                        }
                    }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isBSelected ? cat.themeColor.opacity(0.18) : cat.softBackgroundColor.opacity(0.70))
                                .frame(width: 26, height: 26)
                                .overlay(
                                    MoneyIcon(b.iconType, size: 15)
                                )

                            Text(b.displayName(for: l10n.language))
                                .font(.system(size: 13, weight: isBSelected ? .bold : .medium, design: .rounded))
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundColor(isBSelected ? cat.themeColor : Color.deepNavy)
                        }
                        .padding(.leading, 6)
                        .padding(.trailing, 12)
                        .padding(.vertical, 6)
                        .background(isBSelected ? Color.white : Color.white.opacity(0.90))
                        .clipShape(Capsule())
                        .overlay {
                            if isBSelected {
                                Capsule()
                                    .stroke(cat.themeColor.opacity(0.35), lineWidth: 1)
                            }
                        }
                        .shadow(color: Color.black.opacity(isBSelected ? 0.05 : 0.02), radius: isBSelected ? 3 : 1.5, y: 1)
                    }
                    .bouncyPress(scale: 0.95)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    // MARK: - Date Picker Popup Modal Overlay
    @ViewBuilder @MainActor
    private var datePickerModalView: some View {
        VStack(spacing: 12) {
            // Header: Title + Close Button
            HStack {
                Text(l10n.language == .hebrew ? "בחר תאריך" : "Select Date")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                Spacer()

                Button(action: {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        showDatePickerOverlay = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.deepNavy)
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
                .bouncyPress(scale: 0.92)
                .accessibilityLabel(l10n.language == .hebrew ? "סגור" : "Close")
            }
            .padding(.horizontal, 2)

            // Quick shortcut chips (Today, Yesterday, Tomorrow)
            quickDateShortcutsRow
                .padding(.top, 2)

            // Graphical Calendar Picker
            DatePicker(
                "",
                selection: $tempSelectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(Color.primaryBlue)
            .environment(\.locale, l10n.language == .hebrew ? Locale(identifier: "he_IL") : Locale(identifier: "en_US"))

            // Save / Confirm Button
            Button(action: {
                Haptics.impact(.medium)
                transactionDate = tempSelectedDate
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    showDatePickerOverlay = false
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                    Text(l10n.language == .hebrew ? "אישור" : "Done")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.deepNavy)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .bouncyPress(scale: 0.97)
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 24, y: 10)
        .frame(maxWidth: 360)
        .padding(.horizontal, 20)
    }

    @ViewBuilder @MainActor
    private var quickDateShortcutsRow: some View {
        let cal = Calendar.current
        let today = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today

        let isToday = cal.isDate(tempSelectedDate, inSameDayAs: today)
        let isYesterday = cal.isDate(tempSelectedDate, inSameDayAs: yesterday)
        let isTomorrow = cal.isDate(tempSelectedDate, inSameDayAs: tomorrow)

        HStack(spacing: 8) {
            shortcutDateChip(title: l10n.language == .hebrew ? "היום" : "Today", isSelected: isToday) {
                Haptics.selection()
                tempSelectedDate = today
            }

            shortcutDateChip(title: l10n.language == .hebrew ? "אתמול" : "Yesterday", isSelected: isYesterday) {
                Haptics.selection()
                tempSelectedDate = yesterday
            }

            shortcutDateChip(title: l10n.language == .hebrew ? "מחר" : "Tomorrow", isSelected: isTomorrow) {
                Haptics.selection()
                tempSelectedDate = tomorrow
            }
        }
    }

    @ViewBuilder @MainActor
    private func shortcutDateChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? Color.white : Color.deepNavy)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.primaryBlue : Color.black.opacity(0.04))
                )
        }
        .buttonStyle(.plain)
        .bouncyPress(scale: 0.95)
    }

    // MARK: - Category Picker Popup Modal (Responsive Content Height)
    @ViewBuilder @MainActor
    private var categoryPickerModalView: some View {
        VStack(spacing: 0) {
            if let pendingCat = categoryPickerSubcategoryCategory {
                subcategoryPickerContent(for: pendingCat)
            } else {
                primaryCategoryPickerContent
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.09), radius: 24, y: 10)
        .frame(maxWidth: 420)
        .padding(.horizontal, 20)
    }

    // MARK: - Step 1: Primary Categories = Vertical Fast-Scan Navigation List
    @ViewBuilder @MainActor
    private var primaryCategoryPickerContent: some View {
        VStack(spacing: 16) {
            // Header: Editorial Title + Close Button
            HStack {
                Text(l10n.language == .hebrew ? "בחר קטגוריה" : "Select Category")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                Spacer()

                Button(action: {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        showCategoryPickerSheet = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.deepNavy)
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
                .bouncyPress(scale: 0.92)
                .accessibilityLabel(l10n.language == .hebrew ? "סגור" : "Close")
            }
            .padding(.horizontal, 2)
            .padding(.top, 2)

            // Scrollable Vertical Category List (Fast navigation scanning, capped at max height)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(allCategories) { cat in
                        primaryCategoryRow(for: cat)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxHeight: min(UIScreen.main.bounds.height * 0.78, 580))
    }

    @ViewBuilder @MainActor
    private func primaryCategoryRow(for cat: SpendingCategory) -> some View {
        Button(action: {
            Haptics.selection()
            let available = CityBuilding.buildings(for: cat)
            if available.count > 1 {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                    categoryPickerSubcategoryCategory = cat
                }
            } else {
                selectedCategory = cat
                userExplicitlySelectedCategory = true
                selectedBuildingId = available.first?.id
                showErrorHint = false
                isAmountFocused = false
                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                    showCategoryPickerSheet = false
                }
            }
        }) {
            HStack(spacing: 16) {
                Circle()
                    .fill(cat.softBackgroundColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        CategoryVectorIcon(
                            category: cat,
                            size: 24
                        )
                    )

                Text(cat.displayName(for: l10n.language))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer()

                Image(systemName: l10n.language == .hebrew ? "chevron.left" : "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.deepNavy.opacity(0.20))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(0.02),
                radius: 2,
                y: 1
            )
        }
        .bouncyPress(scale: 0.98)
        .accessibilityLabel(cat.displayName(for: l10n.language))
    }

    // MARK: - Step 2: Subcategories = 2-Column Large Tactile Cards with Subtitle (Snug Height)
    @ViewBuilder @MainActor
    private func subcategoryPickerContent(for pendingCat: SpendingCategory) -> some View {
        let buildings = CityBuilding.buildings(for: pendingCat)

        VStack(spacing: 16) {
            // Header: Back Button + Category Title + Close Button
            HStack(spacing: 8) {
                Button(action: {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                        categoryPickerSubcategoryCategory = nil
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: l10n.language == .hebrew ? "chevron.right" : "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                        Text(l10n.language == .hebrew ? "קטגוריות" : "Categories")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Color.deepNavy.opacity(0.70))
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .bouncyPress(scale: 0.94)

                Spacer()

                Text(pendingCat.displayName(for: l10n.language))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)

                Spacer()

                Button(action: {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        categoryPickerSubcategoryCategory = nil
                        showCategoryPickerSheet = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.deepNavy)
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
                .bouncyPress(scale: 0.92)
                .accessibilityLabel(l10n.language == .hebrew ? "סגור" : "Close")
            }
            .padding(.horizontal, 2)
            .padding(.top, 2)

            // Dynamic 2-Column Grid: Snug intrinsic height (no excess empty space)
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(buildings) { b in
                    subcategoryTile(for: b, in: pendingCat)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder @MainActor
    private func subcategoryTile(for b: CityBuilding, in cat: SpendingCategory) -> some View {
        let isSelected = (selectedBuildingId == b.id && selectedCategory == cat)
        Button(action: {
            Haptics.selection()
            selectedCategory = cat
            userExplicitlySelectedCategory = true
            selectedBuildingId = b.id
            showErrorHint = false
            isAmountFocused = false
            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                categoryPickerSubcategoryCategory = nil
                showCategoryPickerSheet = false
            }
        }) {
            VStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? cat.themeColor.opacity(0.18) : cat.softBackgroundColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        MoneyIcon(b.iconType, size: 22)
                    )

                VStack(spacing: 3) {
                    Text(b.displayName(for: l10n.language))
                        .font(.system(size: 16.5, weight: isSelected ? .bold : .semibold, design: .rounded))
                        .foregroundColor(isSelected ? cat.themeColor : Color.deepNavy)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(b.description(for: l10n.language))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 128)
            .padding(.vertical, 14)
            .padding(.horizontal, 10)
            .background(
                isSelected
                    ? cat.softBackgroundColor.opacity(0.35)
                    : Color.white
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isSelected
                            ? cat.themeColor.opacity(0.55)
                            : Color.black.opacity(0.04),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(cat.themeColor)
                        .padding(8)
                }
            }
            .shadow(
                color: isSelected
                    ? cat.themeColor.opacity(0.12)
                    : Color.black.opacity(0.03),
                radius: isSelected ? 8 : 4,
                y: 2
            )
        }
        .bouncyPress(scale: 0.95)
        .accessibilityLabel("\(b.displayName(for: l10n.language)), \(b.description(for: l10n.language))")
    }

    // MARK: - Category Cluster Section (Prominent Unified Cluster)
    private var categoryClusterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Category row button
            Button(action: {
                dismissKeyboard()
                Haptics.impact(.light)
                categoryPickerSubcategoryCategory = nil
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    showCategoryPickerSheet.toggle()
                }
            }) {
                VStack(alignment: .leading, spacing: 6) {
                    // Small secondary label
                    Text(l10n.language == .hebrew ? "קטגוריה" : "Category")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textSecondary)

                    // Icon + Category Name + tight attached Chevron
                    HStack(spacing: 10) {
                        Circle()
                            .fill(selectedCategory?.softBackgroundColor ?? MoneyCityTheme.warmCream)
                            .frame(width: 38, height: 38)
                            .overlay {
                                if let cat = selectedCategory {
                                    CategoryVectorIcon(category: cat, size: 22)
                                } else {
                                    MoneyIcon(.bookmark, size: 18)
                                }
                            }

                        Text(selectedCategory?.displayName(for: l10n.language) ?? (l10n.language == .hebrew ? "בחר קטגוריה" : "Select Category"))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.deepNavy.opacity(0.40))
                            .padding(.leading, 2)

                        Spacer()
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .bouncyPress(scale: 0.98)

            // Subcategory / Building Chips directly underneath (no divider!)
            if let cat = selectedCategory {
                let buildings = CityBuilding.buildings(for: cat)
                if buildings.count > 1 {
                    buildingChipsRow(cat: cat, buildings: buildings)
                        .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(MoneyCityTheme.warmCream.opacity(0.65))
        )
        .shadow(color: Color.black.opacity(0.02), radius: 6, y: 1.5)
        .padding(.horizontal, 20)
    }

    // MARK: - Merchant / Note Field
    private var merchantField: some View {
        HStack(spacing: 10) {
            MoneyIcon(.pencil, size: 14, color: Color.textSecondary.opacity(0.65))
            TextField(l10n.language == .hebrew ? "בית עסק / תיאור" : "Merchant / Description", text: $note)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(Color.deepNavy)
                .focused($isNoteFocused)
                .submitLabel(.done)
                .onSubmit {
                    dismissKeyboard()
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(minHeight: 50)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.025), radius: 6, y: 1.5)
        )
        .padding(.horizontal, 20)
        .contentShape(Rectangle())
        .onTapGesture {
            isNoteFocused = true
        }
    }

    // MARK: - Utility Row (Date + More Options)
    private var utilityRow: some View {
        HStack(spacing: 10) {
            if allowsDateEditing {
                dateButton
            }
            moreOptionsButton
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var dateButton: some View {
        Button(action: {
            dismissKeyboard()
            tempSelectedDate = transactionDate
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                showDatePickerOverlay = true
            }
        }) {
            HStack(spacing: 5) {
                MoneyIcon(
                    .calendar,
                    size: 12,
                    color: isFutureDate ? Color.primaryBlue : (showDatePickerOverlay ? Color.deepNavy : Color.textSecondary)
                )
                Text(formattedDateString(transactionDate))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(isFutureDate ? Color.primaryBlue : (showDatePickerOverlay ? Color.deepNavy : Color.textSecondary))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isFutureDate ? Color.primaryBlue.opacity(0.12) : (showDatePickerOverlay ? Color.black.opacity(0.07) : Color.black.opacity(0.03)))
            )
        }
        .buttonStyle(.plain)
        .bouncyPress(scale: 0.96)
    }

    private var moreOptionsButton: some View {
        Button(action: {
            dismissKeyboard()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showAdvancedOptions.toggle()
            }
        }) {
            HStack(spacing: 5) {
                MoneyIcon(showAdvancedOptions ? .chevronUp : .plusCircle, size: 12, color: showAdvancedOptions ? Color.deepNavy : Color.textSecondary)
                Text(showAdvancedOptions
                     ? (l10n.language == .hebrew ? "הסתר אפשרויות" : "Hide options")
                     : (l10n.language == .hebrew ? "אפשרויות נוספות" : "More options")
                )
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(showAdvancedOptions ? Color.deepNavy : Color.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(showAdvancedOptions ? Color.black.opacity(0.07) : Color.black.opacity(0.03))
            )
        }
        .buttonStyle(.plain)
        .bouncyPress(scale: 0.96)
    }

    // MARK: - 3. Expandable More Options (Installments)
    @ViewBuilder @MainActor
    private var expandableMoreOptionsSection: some View {
        VStack(spacing: 8) {
            if showAdvancedOptions {
                VStack(spacing: 8) {
                    // Installments Selector Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(l10n.language == .hebrew ? "פריסה לתשלומים" : "Installments")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            
                            Spacer()
                            
                            if paymentCount > 1, let total = parseAmount(amountText), total > 0 {
                                Text(l10n.language == .hebrew ? "\(l10n.format(amount: total / Double(paymentCount))) לחודש" : "\(l10n.format(amount: total / Double(paymentCount)))/mo")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.accentOrange)
                            }
                        }
                        
                        HStack(spacing: 6) {
                            ForEach([1, 2, 3, 6, 12], id: \.self) { count in
                                let isSelected = paymentCount == count
                                Button(action: {
                                    Haptics.selection()
                                    paymentCount = count
                                }) {
                                    Text(count == 1 ? (l10n.language == .hebrew ? "תשלום 1" : "1x") : "\(count)x")
                                        .font(.system(size: 12, weight: isSelected ? .black : .semibold, design: .rounded))
                                        .foregroundColor(isSelected ? .white : Color.deepNavy)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 7)
                                        .background(isSelected ? Color.accentOrange : Color.backgroundElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .bouncyPress(scale: 0.94)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var isFutureDate: Bool {
        let cal = Calendar.current
        return cal.startOfDay(for: transactionDate) > cal.startOfDay(for: Date())
    }

    // MARK: - 4. Big Save Button
    @ViewBuilder @MainActor
    private var saveTransactionButton: some View {
        let parsed = parseAmount(amountText)
        let canSave = (parsed ?? 0) > 0 && selectedCategory != nil
        let saveTitle: String = {
            if isFutureDate {
                return l10n.language == .hebrew ? "תזמן הוצאה" : "Schedule Expense"
            } else {
                return l10n.language == .hebrew ? "שמור הוצאה" : "Save Transaction"
            }
        }()
        Button(action: {
            dismissKeyboard()
            if let cat = selectedCategory {
                submit(category: cat)
            } else {
                showErrorHint = true
                Haptics.notify(.warning)
            }
        }) {
            HStack(spacing: 8) {
                MoneyIcon(.checkCircle, size: 20, color: canSave ? Color.white : Color.white.opacity(0.60))
                    .opacity(canSave ? 1.0 : 0.60)
                Text(saveTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(canSave ? Color.white : Color.white.opacity(0.60))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                canSave
                    ? MoneyCityTheme.brandPrimary
                    : MoneyCityTheme.brandPrimary.opacity(0.35)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(canSave ? 0.12 : 0.0), radius: 8, y: 3)
        }
        .buttonStyle(SaveButtonInteractiveStyle())
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private func submit(category: SpendingCategory) {
        guard let amount = parseAmount(amountText), amount > 0 else {
            showErrorHint = true
            return
        }

        if paymentCount > 1 {
            submitInstallments(category: category, total: amount)
            return
        }

        let isForeign = selectedCurrency != l10n.baseCurrency
        let converted = isForeign ? CurrencyType.convert(amount: amount, from: selectedCurrency, to: l10n.baseCurrency) : amount
        let typed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackMerchant: String = {
            if let bId = selectedBuildingId, let building = CityBuilding.find(id: bId) {
                return building.displayName(for: l10n.language)
            }
            return category.displayName
        }()
        let merchant = typed.isEmpty ? fallbackMerchant : typed
        let origAmt: Double? = isForeign ? amount : nil
        let origCurr: String? = isForeign ? selectedCurrency.rawValue : nil
        let rate: Double? = isForeign ? CurrencyType.convert(amount: 1.0, from: selectedCurrency, to: l10n.baseCurrency) : nil

        let isCategoryExplicit = userExplicitlySelectedCategory || (initialCategory != nil && initialCategoryIsExplicit)
        onSave(converted, category, merchant, origAmt, origCurr, rate, selectedBuildingId, isCategoryExplicit, transactionDate)
        Haptics.notify(.success)
        dismiss()
    }

    /// Splitting a purchase used to quietly drop two things the user had already told us:
    /// the building they picked, and the currency they entered it in. Both are passed on now,
    /// so a split payment records exactly what a single payment would.
    private func submitInstallments(category: SpendingCategory, total: Double) {
        let isForeign = selectedCurrency != l10n.baseCurrency
        let converted = isForeign ? CurrencyType.convert(amount: total, from: selectedCurrency, to: l10n.baseCurrency) : total
        let origAmt: Double? = isForeign ? total : nil
        let origCurr: String? = isForeign ? selectedCurrency.rawValue : nil
        let rate: Double? = isForeign ? CurrencyType.convert(amount: 1.0, from: selectedCurrency, to: l10n.baseCurrency) : nil
        let typed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackMerchant: String = {
            if let bId = selectedBuildingId, let building = CityBuilding.find(id: bId) {
                return l10n.language == .hebrew
                    ? "\(building.displayName(for: l10n.language)) (\(paymentCount) תשלומים)"
                    : "\(building.displayName(for: l10n.language)) (\(paymentCount) payments)"
            }
            return l10n.language == .hebrew ? "רכישה ב-\(paymentCount) תשלומים" : "\(paymentCount)-payment purchase"
        }()
        let merchant = typed.isEmpty ? fallbackMerchant : typed

        let plan = InstallmentPlan(
            merchant: merchant,
            totalAmount: converted,
            currency: l10n.baseCurrency.symbol,
            numberOfPayments: paymentCount,
            firstChargeDate: transactionDate,
            category: category,
            lastMaterializedIndex: 0,
            buildingIdRaw: selectedBuildingId
        )
        modelContext.insert(plan)

        // Only materialize payments whose charge date is due (payment 1)
        let dueTxs = InstallmentService.makeDueTransactions(
            for: plan,
            buildingId: selectedBuildingId,
            originalAmount: origAmt,
            originalCurrency: origCurr,
            exchangeRate: rate,
            asOf: Date()
        )
        for tx in dueTxs {
            modelContext.insert(tx)
            if let idx = tx.installmentIndex {
                plan.lastMaterializedIndex = max(plan.lastMaterializedIndex, idx)
            }
        }

        guard DatabaseService.safeSave(modelContext) else {
            Haptics.notify(.error)
            return
        }
        Haptics.notify(.success)
        dismiss()
    }
}


// MARK: - Save Button Interactive Style
private struct SaveButtonInteractiveStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .opacity(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.16, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

#Preview("Quick Add Sheet") {
    QuickAddSheet { _, _, _, _, _, _, _ in }
        .environmentObject(LocalizationManager.shared)
}

