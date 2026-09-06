import SwiftUI
import SwiftData
import AppIntents
#if canImport(PhotosUI)
import PhotosUI
#endif

/// Fast-Add modal sheet matching the art-directed modern design system.
@MainActor
public struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager
    public let initialOpenScan: Bool
    public let onSave: (_ amount: Double, _ category: SpendingCategory, _ merchant: String, _ originalAmount: Double?, _ originalCurrency: String?, _ exchangeRate: Double?, _ buildingId: String?) -> Void
    
    public init(
        initialOpenScan: Bool = false,
        onSave: @escaping (_ amount: Double, _ category: SpendingCategory, _ merchant: String, _ originalAmount: Double?, _ originalCurrency: String?, _ exchangeRate: Double?, _ buildingId: String?) -> Void
    ) {
        self.initialOpenScan = initialOpenScan
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

    #if canImport(PhotosUI)
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showPhotoPicker = false
    #endif
    @State private var isScanningScreenshot = false
    @State private var scannedMultiCandidates: [ParsedTransactionCandidate] = []
    @State private var scanErrorMessage: String? = nil

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
    
    private var displayAmountString: String {
        if amountText.isEmpty {
            return "0.00"
        }
        return amountText
    }

    private func handleKeypadPress(_ key: String) {
        Haptics.selection()
        if key == "⌫" {
            if !amountText.isEmpty {
                amountText.removeLast()
            }
        } else if key == "." {
            if !amountText.contains(".") {
                if amountText.isEmpty {
                    amountText = "0."
                } else {
                    amountText += "."
                }
            }
        } else {
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
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if isScanningScreenshot {
                            ReceiptScanningSkeletonView()
                                .padding(.horizontal, 20)
                                .padding(.top, 4)
                        }

                        // Multi-transaction review if screenshot contained multiple
                        multiTransactionReviewSection

                        // ── 1. Hero Amount Display (Reference: ₪0.00 with cursor) ──
                        HStack(alignment: .center, spacing: 4) {
                            Text(selectedCurrency.symbol)
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)

                            Text(displayAmountString)
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundColor(amountText.isEmpty ? Color.textMuted.opacity(0.6) : Color.deepNavy)

                            // Blinking cursor
                            Rectangle()
                                .fill(Color.primaryBlue)
                                .frame(width: 2.5, height: 40)
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
                                MoneyIcon(.user, size: 18)
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
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    showCategoryPickerSheet.toggle()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    if let cat = selectedCategory {
                                        CategoryBadge(category: cat, size: 28)
                                    } else {
                                        Circle()
                                            .fill(Color(red: 255/255, green: 237/255, blue: 213/255))
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                MoneyIcon(.bookmark, size: 14)
                                            )
                                    }

                                    Text(l10n.language == .hebrew ? "קטגוריה" : "Category")
                                        .font(.system(size: 15, weight: .medium, design: .default))
                                        .foregroundColor(Color.deepNavy)

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
                            .buttonStyle(.plain)

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
                            .buttonStyle(.plain)

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

                #if canImport(PhotosUI)
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        MoneyIcon(.camera, size: 22)
                            .frame(width: 32, height: 32)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.05), radius: 3, y: 1)
                    }
                }
                #endif
            }
            .onAppear {
                // Default to food category if none selected
                if selectedCategory == nil {
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

    // MARK: - Numeric Keypad View (Reference Screen 5)
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
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.04), radius: 3.5, y: 1.5)

                                if key == "⌫" {
                                    MoneyIcon(.backspace, size: 22)
                                } else {
                                    Text(key)
                                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color.deepNavy)
                                }
                            }
                            .frame(height: 50)
                        }
                        .buttonStyle(.plain)
                        .bouncyPress(scale: 0.94)
                    }
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
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    // MARK: - Dynamic Building Chips
    @ViewBuilder @MainActor
    private func buildingChipsSection(cat: SpendingCategory, buildings: [CityBuilding]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(l10n.language == .hebrew ? "בניין בעיר:" : "3D Building:")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                Spacer()
                if let bId = selectedBuildingId, let building = CityBuilding.find(id: bId) {
                    Text(building.displayName(for: l10n.language))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(cat.themeColor)
                }
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(buildings) { b in
                        let isBSelected = (selectedBuildingId == b.id)
                        Button(action: {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.25)) {
                                selectedBuildingId = b.id
                            }
                        }) {
                            HStack(spacing: 5) {
                                Text(b.emoji)
                                    .font(.system(size: 13))
                                Text(b.displayName(for: l10n.language))
                                    .font(.system(size: 11, weight: isBSelected ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isBSelected ? cat.themeColor : Color.deepNavy)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isBSelected ? cat.softBackgroundColor : Color.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isBSelected ? cat.themeColor : Color.clear, lineWidth: isBSelected ? 1.5 : 0)
                            )
                            .shadow(color: Color.black.opacity(isBSelected ? 0 : 0.03), radius: 3, y: 1)
                        }
                        .bouncyPress(scale: 0.95)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Category Picker Popup Modal (Screen 6 Modal / Popup)
    @ViewBuilder @MainActor
    private var categoryPickerModalView: some View {
        VStack(spacing: 16) {
            // Header: Title + Close Button
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
                    MoneyIcon(.xmarkCircle, size: 22)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            if let scanError = scanErrorMessage {
                HStack(spacing: 8) {
                    MoneyIcon(.warningCircle, size: 16)
                    Text(scanError)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                        .lineLimit(2)
                }
                .padding(.horizontal, 4)
            }

            // 3x3 Category Grid
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
                        selectedCategory = cat
                        showErrorHint = false
                        let available = CityBuilding.buildings(for: cat)
                        if !available.contains(where: { $0.id == selectedBuildingId }) {
                            selectedBuildingId = CategorizationEngine.shared.mapToBuildingId(category: cat, merchant: note)
                            if !available.contains(where: { $0.id == selectedBuildingId }), let first = available.first {
                                selectedBuildingId = first.id
                            }
                        }
                        isAmountFocused = false
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                            showCategoryPickerSheet = false
                        }
                    }) {
                        VStack(spacing: 8) {
                            // Circular Pastel Container
                            ZStack {
                                Circle()
                                    .fill(isSelected ? cat.themeColor : cat.softBackgroundColor)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(isSelected ? cat.themeColor : Color.black.opacity(0.04), lineWidth: 1)
                                    )
                                    .shadow(color: isSelected ? cat.themeColor.opacity(0.28) : Color.clear, radius: 4, y: 2)

                                CategoryVectorIcon(
                                    category: cat,
                                    color: isSelected ? Color.white : cat.themeColor,
                                    size: 22
                                )
                            }
                            
                            Text(cat.shortName)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                                .foregroundColor(isSelected ? Color.deepNavy : Color.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isSelected ? cat.softBackgroundColor.opacity(0.5) : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(isSelected ? cat.themeColor : Color.clear, lineWidth: isSelected ? 1.6 : 0)
                        )
                        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                    .bouncyPress(scale: 0.94)
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
        Button(action: {
            if let cat = selectedCategory {
                submit(category: cat)
            } else {
                showErrorHint = true
                Haptics.notify(.warning)
            }
        }) {
            HStack(spacing: 8) {
                MoneyIcon(.checkCircle, size: 20)
                Text(l10n.language == .hebrew ? "שמור הוצאה" : "Save Transaction")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                (parseAmount(amountText) != nil && selectedCategory != nil)
                    ? Color(red: 17/255, green: 24/255, blue: 39/255)
                    : Color(red: 17/255, green: 24/255, blue: 39/255).opacity(0.4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
        }
        .bouncyPress(scale: 0.96)
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
        let merchant = typed.isEmpty ? category.displayName : typed
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
        let merchant = typed.isEmpty
            ? (l10n.language == .hebrew ? "רכישה ב-\(paymentCount) תשלומים" : "\(paymentCount)-payment purchase")
            : typed

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

        DatabaseService.safeSave(modelContext)
        Haptics.notify(.success)
        dismiss()
    }

    // MARK: - Multi-Transaction Review Card

    @ViewBuilder @MainActor
    private var multiTransactionReviewSection: some View {
        if !scannedMultiCandidates.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                multiHeaderView
                multiCandidatesListView
                multiSaveAllButton
            }
            .padding(14)
            .background(Color.themeLavenderSoft.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder @MainActor
    private var multiHeaderView: some View {
        HStack {
            MoneyIcon(.photo, size: 16)
            let titleText = scannedMultiCandidates.count > 1
                ? (l10n.language == .hebrew ? "זוהו \(scannedMultiCandidates.count) עסקאות בצילום המסך" : "Found \(scannedMultiCandidates.count) Purchases")
                : (l10n.language == .hebrew ? "זוהתה עסקה 1 בצילום המסך" : "Found 1 Purchase")
            Text(titleText)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
            Spacer()
            Button(action: {
                withAnimation(.spring(response: 0.25)) {
                    scannedMultiCandidates = []
                }
            }) {
                MoneyIcon(.xmarkCircle, size: 18)
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder @MainActor
    private var multiCandidatesListView: some View {
        VStack(spacing: 8) {
            ForEach(scannedMultiCandidates) { candidate in
                multiCandidateRow(for: candidate)
            }
        }
    }

    @ViewBuilder @MainActor
    private func multiCandidateRow(for candidate: ParsedTransactionCandidate) -> some View {
        let isInt = candidate.amount.truncatingRemainder(dividingBy: 1) == 0
        let displayAmt = isInt ? String(format: "%.0f", candidate.amount) : String(format: "%.2f", candidate.amount)

        HStack(spacing: 10) {
            // Category Icon
            CategoryBadge(category: candidate.category, size: 36)

            // Info (Merchant + Category)
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.merchant)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .lineLimit(1)
                Text(candidate.category.displayName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textSecondary)
            }

            Spacer()

            // Amount
            Text("₪\(displayAmt)")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(Color.deepNavy)

            // Delete single candidate button
            Button(action: {
                withAnimation(.spring(response: 0.25)) {
                    Haptics.impact(.light)
                    scannedMultiCandidates.removeAll(where: { $0.id == candidate.id })
                }
            }) {
                MoneyIcon(.trash, size: 20)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.25)) {
                amountText = displayAmt
                note = candidate.merchant
                selectedCategory = candidate.category
                selectedBuildingId = candidate.buildingId
                isAmountFocused = false
                scannedMultiCandidates = []
            }
        }
    }

    @ViewBuilder @MainActor
    private var multiSaveAllButton: some View {
        let totalSum = scannedMultiCandidates.reduce(0.0) { $0 + $1.amount }
        let isTotalInt = totalSum.truncatingRemainder(dividingBy: 1) == 0
        let formattedTotal = "₪" + (isTotalInt ? String(format: "%.0f", totalSum) : String(format: "%.2f", totalSum))

        let buttonText = scannedMultiCandidates.count > 1
            ? (l10n.language == .hebrew ? "שמור את כל \(scannedMultiCandidates.count) העסקאות (\(formattedTotal))" : "Save All \(scannedMultiCandidates.count) Purchases (\(formattedTotal))")
            : (l10n.language == .hebrew ? "שמור עסקה זו (\(formattedTotal))" : "Save Purchase (\(formattedTotal))")

        Button(action: {
            saveAllScannedMultiTransactions()
        }) {
            HStack(spacing: 6) {
                MoneyIcon(.checkCircle, size: 16)
                Text(buttonText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.primaryBlue, Color.primaryBlue.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.top, 2)
    }

    private func saveAllScannedMultiTransactions() {
        for candidate in scannedMultiCandidates {
            let tx = Transaction(
                amount: candidate.amount,
                merchant: candidate.merchant,
                category: candidate.category,
                timestamp: candidate.date ?? Date(),
                confidenceScore: candidate.confidence,
                isConfirmed: candidate.confidence >= 0.85,
                buildingId: candidate.buildingId
            )
            modelContext.insert(tx)
        }
        DatabaseService.safeSave(modelContext)
        Haptics.notify(.success)
        dismiss()
    }

    #if canImport(PhotosUI)
    private func processPickedPhoto(_ item: PhotosPickerItem) async {
        await MainActor.run {
            isScanningScreenshot = true
            scanErrorMessage = nil
        }
        defer { Task { @MainActor in isScanningScreenshot = false } }
        
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            await MainActor.run {
                scanErrorMessage = l10n.language == .hebrew ? "שגיאה בטעינת התמונה מהגלריה" : "Failed to load image from gallery"
                Haptics.notify(.warning)
            }
            return
        }
        let rules = DatabaseService.shared.fetchMerchantRules()
        
        do {
            let result = try await ExpenseExtractionService.shared.processImageData(data, rules: rules, allowFallback: true)
            await MainActor.run {
                scanErrorMessage = nil
                showErrorHint = false
                if result.candidates.count > 1 {
                    scannedMultiCandidates = result.candidates
                    Haptics.notify(.success)
                } else if let single = result.candidates.first {
                    // Logged on success as well as failure, so the success rate is something
                    // that can be counted from the device rather than estimated from memory.
                    ReceiptOCRService.recordScanAttempt(
                        outcome: "success",
                        failureReason: nil,
                        trace: nil,
                        resolvedAmount: single.amount,
                        resolvedMerchant: single.merchant
                    )
                    scannedMultiCandidates = []
                    amountText = (single.amount.truncatingRemainder(dividingBy: 1) == 0) ? String(format: "%.0f", single.amount) : String(format: "%.2f", single.amount)
                    note = single.merchant
                    selectedCategory = single.category
                    selectedBuildingId = single.buildingId
                    isAmountFocused = false
                    Haptics.notify(.success)
                } else {
                    scanErrorMessage = l10n.language == .hebrew ? "לא זוהתה קבלה ברורה בתמונה. נסה לקרב או לצלם ישירות." : "No clear receipt detected. Try zooming in."
                    ReceiptOCRService.recordScanAttempt(
                        outcome: "no_candidates",
                        failureReason: "OCR returned no usable candidate",
                        trace: nil
                    )
                    Haptics.notify(.warning)
                }
            }
        } catch {
            MoneyCityLog.sensitive("[QuickAddSheet Scan Error] \(error.localizedDescription)")
            await MainActor.run {
                // Every failed scan now leaves a record. Debug-only logging compiles out of
                // release, so before this a user could report "scanning does not work" and
                // there was nothing on the device to look at.
                let failure = error as? ReceiptOCRService.OCRFailure
                ReceiptOCRService.recordScanAttempt(
                    outcome: failure.map { "failed_\($0.reason)" } ?? "failed",
                    failureReason: error.localizedDescription,
                    trace: failure?.trace
                )
                Haptics.notify(.warning)
                scanErrorMessage = scanFailureMessage(for: error)
            }
        }
    }
    /// Different failures need different advice. One message for all of them told a user whose
    /// device cannot read Hebrew to zoom in, which would never have helped.
    private func scanFailureMessage(for error: Error) -> String {
        let isHebrew = l10n.language == .hebrew
        guard let failure = error as? ReceiptOCRService.OCRFailure else {
            return isHebrew ? "לא זוהתה קבלה ברורה בתמונה. נסה לקרב או לצלם ישירות."
                            : "No clear receipt detected. Try zooming in."
        }
        switch failure.reason {
        case .noTextFound:
            return isHebrew ? "לא נמצא טקסט קריא בתמונה. נסה תאורה טובה יותר או לקרב."
                            : "No readable text in the image. Try better light or move closer."
        case .parsingFailed:
            if !ReceiptOCRService.canReadHebrew {
                return isHebrew
                    ? "המכשיר קרא טקסט אך אינו תומך בזיהוי עברית, אז שם בית העסק לא זוהה. הסכום עשוי עדיין לעבוד — נסה שוב או הזן ידנית."
                    : "Text was read, but this device cannot recognise Hebrew, so the merchant was not identified."
            }
            return isHebrew ? "הטקסט נקרא אך לא נמצא בו סכום. ודא שהסכום הכולל מופיע בתמונה."
                            : "Text was read but no total was found. Make sure the total is in the photo."
        case .imageProcessingFailed:
            return isHebrew ? "לא הצלחתי לעבד את התמונה. נסה תמונה אחרת."
                            : "Could not process that image. Try another one."
        }
    }
    #endif
}
