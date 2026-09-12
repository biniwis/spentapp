import SwiftUI
import SwiftData
import AppIntents

/// Fast-Add modal sheet matching the art-directed modern design system.
@MainActor
public struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager
    public let initialCategory: SpendingCategory?
    public let onSave: (_ amount: Double, _ category: SpendingCategory, _ merchant: String, _ originalAmount: Double?, _ originalCurrency: String?, _ exchangeRate: Double?, _ buildingId: String?) -> Void
    
    public init(
        initialCategory: SpendingCategory? = nil,
        onSave: @escaping (_ amount: Double, _ category: SpendingCategory, _ merchant: String, _ originalAmount: Double?, _ originalCurrency: String?, _ exchangeRate: Double?, _ buildingId: String?) -> Void
    ) {
        self.initialCategory = initialCategory
        self.onSave = onSave
    }
    
    @State private var amountText: String = ""
    @State private var note: String = ""
    @State private var selectedCurrency: CurrencyType = .ils
    @State private var selectedCategory: SpendingCategory? = nil
    @State private var selectedBuildingId: String? = nil
    @State private var showErrorHint = false
    @State private var paymentCount: Int = 1

    @State private var showAdvancedOptions = false
    @State private var cursorVisible = true
    @State private var transactionDate = Date()
    @State private var showDatePicker = false
    @State private var showCategoryPickerSheet = false
    @State private var categoryPickerSubcategoryCategory: SpendingCategory? = nil
    @State private var amountPunchScale: CGFloat = 1.0

    @Environment(\.modelContext) private var modelContext
    @FocusState private var isAmountFocused: Bool
    
    private func parseAmount(_ text: String) -> Double? {
        let clean = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
        // Everything the user can type goes through the shared ceiling. A long paste used to
        // become 1e20, save fine, and then trap every Int() money display in the app.
        return MoneyAmount.sanitized(Double(clean))
    }

    private func dismissKeyboard() {
        isAmountFocused = false
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

    private func handleKeypadPress(_ key: String) {
        if key == "⌫" {
            Haptics.impact(.medium)
            if !amountText.isEmpty {
                amountText.removeLast()
            }
        } else if key == "." {
            Haptics.selection()
            if !amountText.contains(".") {
                if amountText.isEmpty {
                    amountText = "0."
                } else {
                    amountText += "."
                }
            }
        } else {
            Haptics.impact(.light)
            // Digits 0-9
            if amountText == "0" {
                amountText = key
            } else {
                // Prevent more than 2 decimal places
                if let dotIndex = amountText.firstIndex(of: ".") {
                    let decimals = amountText.distance(from: dotIndex, to: amountText.endIndex)
                    if decimals <= 2 {
                        amountText += key
                    }
                } else if amountText.count < 8 {
                    amountText += key
                }
            }
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
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
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
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                        .padding(.bottom, 6)

                        // Currency switcher pill if not ILS
                        if selectedCurrency != .ils, let val = parseAmount(amountText), val > 0 {
                            let inILS = val * selectedCurrency.rateToILS
                            HStack(spacing: 4) {
                                ExchangeVectorIcon(color: Color.themeMint)
                                Text("≈ \(l10n.format(amount: inILS, showDecimals: true))")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(Color.themeMint)
                        }

                        // ── 2. Built-in Numeric Keypad (Reference Screen 5) ──
                        numericKeypadView
                            .padding(.horizontal, 20)

                        // ── 3. Meta Rows (Merchant, Category, Date) ── Grouped Clean White Card
                        VStack(spacing: 0) {
                            // Merchant Input Row
                            HStack(spacing: 12) {
                                MoneyIcon(.pencil, size: 18)
                                    .frame(width: 24)

                                TextField(l10n.language == .hebrew ? "בית עסק / תיאור" : "Merchant", text: $note)
                                    .font(.system(size: 15, weight: .medium, design: .default))
                                    .foregroundColor(Color.deepNavy)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)

                            Divider()
                                .padding(.horizontal, 16)
                                .opacity(0.5)

                            // Category Selector Row
                            Button(action: {
                                categoryPickerSubcategoryCategory = nil
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    showCategoryPickerSheet.toggle()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    if let cat = selectedCategory {
                                        ZStack {
                                            Circle()
                                                .fill(cat.softBackgroundColor)
                                                .frame(width: 32, height: 32)
                                            CategoryVectorIcon(category: cat, size: 20)
                                        }
                                    } else {
                                        Circle()
                                            .fill(MoneyCityTheme.warmCream)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                MoneyIcon(.bookmark, size: 16)
                                            )
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(l10n.language == .hebrew ? "קטגוריה" : "Category")
                                            .font(.system(size: 15, weight: .medium, design: .default))
                                            .foregroundColor(Color.deepNavy)

                                        if let bId = selectedBuildingId, let b = CityBuilding.find(id: bId), selectedCategory != nil {
                                            Text(b.displayName(for: l10n.language))
                                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                .foregroundColor(selectedCategory?.themeColor ?? Color.textMuted)
                                        }
                                    }

                                    Spacer()

                                    HStack(spacing: 4) {
                                        Text(selectedCategory?.displayName ?? (l10n.language == .hebrew ? "בחר ∨" : "Select ∨"))
                                            .font(.system(size: 14, weight: .semibold, design: .default))
                                            .foregroundColor(selectedCategory != nil ? Color.deepNavy : Color.textMuted)

                                        MoneyIcon(.chevronDown, size: 11)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .contentShape(Rectangle())
                            }
                            .bouncyPress(scale: 0.98)

                            Divider()
                                .padding(.horizontal, 16)
                                .opacity(0.5)

                            // Date Row
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    showDatePicker.toggle()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    MoneyIcon(.calendar, size: 18)
                                        .frame(width: 24)

                                    Text(formattedDateString(transactionDate))
                                        .font(.system(size: 15, weight: .medium, design: .default))
                                        .foregroundColor(Color.deepNavy)

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .contentShape(Rectangle())
                            }
                            .bouncyPress(scale: 0.98)

                            if showDatePicker {
                                Divider()
                                    .padding(.horizontal, 16)
                                    .opacity(0.5)

                                DatePicker("", selection: $transactionDate, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.graphical)
                                    .padding(12)
                                    .transition(.opacity)
                            }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)
                        .padding(.horizontal, 20)

                        // Dynamic Building Chips
                        if let cat = selectedCategory {
                            let buildings = CityBuilding.buildings(for: cat)
                            if buildings.count > 1 {
                                buildingChipsSection(cat: cat, buildings: buildings)
                            }
                        }

                        // Installment options toggle
                        expandableMoreOptionsSection

                        // ── 4. Save Button (Solid Black Rounded Button) ──
                        saveTransactionButton

                        Spacer(minLength: 20)
                    }
                    .padding(.vertical, 8)
                }

                // Modal Popup Overlay for Category Selection (fast popup, no page scrolling)
                if showCategoryPickerSheet {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                showCategoryPickerSheet = false
                            }
                        }
                        .transition(.opacity)

                    categoryPickerModalView
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                        .zIndex(100)
                }
            }
            .navigationTitle(l10n.language == .hebrew ? "הוספת הוצאה" : "Add Expense")
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
                if let initial = initialCategory {
                    selectedCategory = initial
                } else if selectedCategory == nil {
                    selectedCategory = .food
                }
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 550_000_000)
                    cursorVisible.toggle()
                }
            }
        }
    }

    // MARK: - Numeric Keypad View (Tactile Micro-Interactions)
    @ViewBuilder @MainActor
    private var numericKeypadView: some View {
        let keys: [[String]] = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            [".", "0", "⌫"]
        ]

        VStack(spacing: 8) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        Button(action: {
                            handleKeypadPress(key)
                        }) {
                            keypadCell(key: key)
                        }
                        .buttonStyle(KeypadInteractiveButtonStyle(isDelete: key == "⌫"))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keypadCell(key: String) -> some View {
        ZStack {
            if key == "⌫" {
                MoneyIcon(.backspace, size: 22)
            } else if key == "." {
                Text("•")
                    .font(.system(size: 24, weight: .black, design: .rounded))
            } else {
                Text(key)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .contentShape(Rectangle())
    }

    private func formattedDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: l10n.language == .hebrew ? "he_IL" : "en_US")
        if Calendar.current.isDateInToday(date) {
            return l10n.language == .hebrew ? "היום" : "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return l10n.language == .hebrew ? "אתמול" : "Yesterday"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    // MARK: - Dynamic Building Chips (Prominent & Clean, No Circle Stroke)
    @ViewBuilder @MainActor
    private func buildingChipsSection(cat: SpendingCategory, buildings: [CityBuilding]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(buildings) { b in
                    let isBSelected = (selectedBuildingId == b.id)
                    Button(action: {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.25)) {
                            selectedBuildingId = b.id
                        }
                    }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(isBSelected ? cat.themeColor.opacity(0.18) : cat.softBackgroundColor)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    MoneyIcon(b.iconType, size: 18)
                                )

                            Text(b.displayName(for: l10n.language))
                                .font(.system(size: 13, weight: isBSelected ? .bold : .semibold, design: .rounded))
                                .foregroundColor(isBSelected ? cat.themeColor : Color.deepNavy)
                        }
                        .padding(.leading, 6)
                        .padding(.trailing, 14)
                        .padding(.vertical, 8)
                        .background(isBSelected ? cat.softBackgroundColor.opacity(0.5) : Color.white)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isBSelected ? cat.themeColor.opacity(0.40) : Color.borderSubtle, lineWidth: isBSelected ? 1.2 : 1)
                        )
                        .shadow(color: Color.black.opacity(isBSelected ? 0.08 : 0.04), radius: isBSelected ? 5 : 3, y: 1.5)
                    }
                    .bouncyPress(scale: 0.95)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Category Picker Popup Modal (2-Step Flow, Clean Circles Without Strokes)
    @ViewBuilder @MainActor
    private var categoryPickerModalView: some View {
        VStack(spacing: 16) {
            if let pendingCat = categoryPickerSubcategoryCategory {
                // ── STEP 2: Choose Building / Subcategory ──
                let buildings = CityBuilding.buildings(for: pendingCat)

                // Header: Back Button + Category Title + Close
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            categoryPickerSubcategoryCategory = nil
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: l10n.language == .hebrew ? "chevron.right" : "chevron.left")
                                .font(.system(size: 12, weight: .bold))
                            Text(l10n.language == .hebrew ? "קטגוריות" : "Categories")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(Color.deepNavy)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(pendingCat.displayName(for: l10n.language))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)

                    Spacer()

                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            categoryPickerSubcategoryCategory = nil
                            showCategoryPickerSheet = false
                        }
                    }) {
                        MoneyIcon(.xmarkCircle, size: 22, color: Color.deepNavy)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)

                // Buildings List
                VStack(spacing: 8) {
                    ForEach(buildings) { b in
                        let isSelected = (selectedBuildingId == b.id && selectedCategory == pendingCat)
                        Button(action: {
                            Haptics.selection()
                            selectedCategory = pendingCat
                            selectedBuildingId = b.id
                            showErrorHint = false
                            isAmountFocused = false
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                categoryPickerSubcategoryCategory = nil
                                showCategoryPickerSheet = false
                            }
                        }) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(isSelected ? pendingCat.themeColor.opacity(0.18) : pendingCat.softBackgroundColor)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        MoneyIcon(b.iconType, size: 22)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(b.displayName(for: l10n.language))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(isSelected ? pendingCat.themeColor : Color.deepNavy)

                                    Text(b.description(for: l10n.language))
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(Color.textSecondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(pendingCat.themeColor)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(isSelected ? pendingCat.softBackgroundColor.opacity(0.4) : Color(red: 248/255, green: 249/255, blue: 251/255))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(isSelected ? pendingCat.themeColor.opacity(0.5) : Color.borderSubtle.opacity(0.6), lineWidth: 1)
                            )
                            .shadow(color: isSelected ? pendingCat.themeColor.opacity(0.12) : Color.clear, radius: 5, y: 2)
                        }
                        .bouncyPress(scale: 0.96)
                    }
                }
            } else {
                // ── STEP 1: Choose Category Grid ──
                HStack {
                    Text(l10n.language == .hebrew ? "בחר קטגוריה" : "Select Category")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)

                    Spacer()

                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            showCategoryPickerSheet = false
                        }
                    }) {
                        MoneyIcon(.xmarkCircle, size: 22, color: Color.deepNavy)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(allCategories) { cat in
                        let isSelected = selectedCategory == cat
                        Button(action: {
                            Haptics.selection()
                            let available = CityBuilding.buildings(for: cat)
                            if available.count > 1 {
                                withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                                    categoryPickerSubcategoryCategory = cat
                                }
                            } else {
                                selectedCategory = cat
                                selectedBuildingId = available.first?.id
                                showErrorHint = false
                                isAmountFocused = false
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                    showCategoryPickerSheet = false
                                }
                            }
                        }) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(isSelected ? cat.themeColor.opacity(0.18) : cat.softBackgroundColor)
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        CategoryVectorIcon(
                                            category: cat,
                                            size: 26
                                        )
                                    )
                                
                                Text(cat.shortName)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isSelected ? cat.themeColor : Color.deepNavy)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isSelected ? cat.softBackgroundColor.opacity(0.4) : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(isSelected ? cat.themeColor.opacity(0.5) : Color.borderSubtle.opacity(0.8), lineWidth: 1)
                            )
                            .shadow(color: isSelected ? cat.themeColor.opacity(0.15) : Color.black.opacity(0.02), radius: 5, y: 2)
                        }
                        .bouncyPress(scale: 0.94)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 24, y: 8)
        .padding(.horizontal, 20)
    }

    // MARK: - 3. Expandable More Options (Note, Installments)
    @ViewBuilder @MainActor
    private var expandableMoreOptionsSection: some View {
        VStack(spacing: 8) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showAdvancedOptions.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    MoneyIcon(showAdvancedOptions ? .chevronUp : .plusCircle, size: 14)
                    Text(showAdvancedOptions
                         ? (l10n.language == .hebrew ? "הסתר אפשרויות נוספות" : "Hide additional options")
                         : (l10n.language == .hebrew ? "＋ אפשרויות נוספות (הערה, תשלומים)" : "＋ Additional options (note, installments)")
                    )
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color.primaryBlue)
                .padding(.vertical, 4)
            }
            
            if showAdvancedOptions {
                VStack(spacing: 8) {
                    // Note Field
                    HStack(spacing: 8) {
                        NoteVectorIcon(color: Color.textMuted)
                        TextField(l10n.language == .hebrew ? "שם בית העסק / הערה (אופציונלי)" : "Note / Merchant name (optional)", text: $note)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
                    
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
                .padding(.horizontal, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - 4. Big Save Button
    @ViewBuilder @MainActor
    private var saveTransactionButton: some View {
        let canSave = parseAmount(amountText) != nil && selectedCategory != nil
        Button(action: {
            if let cat = selectedCategory {
                submit(category: cat)
            } else {
                showErrorHint = true
                Haptics.notify(.warning)
            }
        }) {
            HStack(spacing: 8) {
                MoneyIcon(.checkCircle, size: 20, color: canSave ? MoneyCityTheme.jetBlack : MoneyCityTheme.jetBlack.opacity(0.40))
                Text(l10n.language == .hebrew ? "שמור הוצאה" : "Save Transaction")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(canSave ? MoneyCityTheme.jetBlack : MoneyCityTheme.jetBlack.opacity(0.40))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                canSave
                    ? MoneyCityTheme.brandPrimary
                    : MoneyCityTheme.brandPrimary.opacity(0.35)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
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

        let converted = selectedCurrency == .ils ? amount : (amount * selectedCurrency.rateToILS)
        let typed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackMerchant: String = {
            if let bId = selectedBuildingId, let building = CityBuilding.find(id: bId) {
                return building.displayName(for: l10n.language)
            }
            return category.displayName
        }()
        let merchant = typed.isEmpty ? fallbackMerchant : typed
        let origAmt: Double? = selectedCurrency == .ils ? nil : amount
        let origCurr: String? = selectedCurrency == .ils ? nil : selectedCurrency.symbol
        let rate: Double? = selectedCurrency == .ils ? nil : selectedCurrency.rateToILS

        onSave(converted, category, merchant, origAmt, origCurr, rate, selectedBuildingId)
        Haptics.notify(.success)
        dismiss()
    }

    /// Splitting a purchase used to quietly drop two things the user had already told us:
    /// the building they picked, and the currency they entered it in. Both are passed on now,
    /// so a split payment records exactly what a single payment would.
    private func submitInstallments(category: SpendingCategory, total: Double) {
        let converted = selectedCurrency == .ils ? total : (total * selectedCurrency.rateToILS)
        let origAmt: Double? = selectedCurrency == .ils ? nil : total
        let origCurr: String? = selectedCurrency == .ils ? nil : selectedCurrency.symbol
        let rate: Double? = selectedCurrency == .ils ? nil : selectedCurrency.rateToILS
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
            firstChargeDate: Date(),
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

// MARK: - Keypad Button Style with Tactile Compression & Tint Pulse
private struct KeypadInteractiveButtonStyle: ButtonStyle {
    let isDelete: Bool

    init(isDelete: Bool = false) {
        self.isDelete = isDelete
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(
                configuration.isPressed
                    ? (isDelete ? Color.deleteRed : Color.primaryBlue)
                    : Color.deepNavy
            )
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        configuration.isPressed
                            ? (isDelete ? Color.deleteRed.opacity(0.18) : Color.primaryBlue.opacity(0.16))
                            : Color.white
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                configuration.isPressed
                                    ? (isDelete ? Color.deleteRed.opacity(0.85) : Color.primaryBlue.opacity(0.85))
                                    : Color.borderSubtle.opacity(0.40),
                                lineWidth: configuration.isPressed ? 2.0 : 1.0
                            )
                    )
                    .shadow(
                        color: configuration.isPressed
                            ? (isDelete ? Color.deleteRed.opacity(0.25) : Color.primaryBlue.opacity(0.25))
                            : Color.black.opacity(0.04),
                        radius: configuration.isPressed ? 6 : 3.5,
                        y: configuration.isPressed ? 0.5 : 1.5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.86 : 1.0)
            .animation(.spring(response: 0.14, dampingFraction: 0.58), value: configuration.isPressed)
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
