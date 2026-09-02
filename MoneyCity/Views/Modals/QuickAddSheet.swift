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

    #if canImport(PhotosUI)
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showPhotoPicker = false
    #endif
    @State private var isScanningScreenshot = false
    @State private var scannedMultiCandidates: [ParsedTransactionCandidate] = []

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

    /// The 9 primary distinct categories for the 3x3 grid (no duplicate aliases)
    private var allCategories: [SpendingCategory] {
        [.food, .shopping, .transport, .housing, .entertainment, .health, .subscriptions, .savings, .miscellaneous]
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboard()
                    }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        if isScanningScreenshot {
                            ReceiptScanningSkeletonView()
                                .padding(.horizontal, 20)
                                .padding(.top, 4)
                        }

                        // 0. MULTI-TRANSACTION CARDS (if multiple detected in screenshot)
                        multiTransactionReviewSection

                        // 1. HERO AMOUNT CARD (Integrated Currency Dropdown)
                        amountHeroCard

                        // 2. UNIFIED 3x3 CATEGORY GRID (Clean single-layer cards)
                        categoryGridSection

                        // 3. EXPANDABLE MORE OPTIONS (Note, Installments)
                        expandableMoreOptionsSection

                        // 4. BIG SAVE BUTTON
                        saveTransactionButton
                        
                        Spacer(minLength: 30)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboard()
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle(l10n.language == .hebrew ? "הוספת הוצאה" : "Add Transaction")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.language == .hebrew ? "ביטול" : "Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                }
                
                #if canImport(PhotosUI)
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack(spacing: 4) {
                            CameraVectorIcon(color: Color.primaryBlue)
                            Text(l10n.language == .hebrew ? "סריקה" : "Scan")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color.primaryBlue)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.primaryBlue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                #endif
                
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(l10n.language == .hebrew ? "סיום" : "Done") {
                        isAmountFocused = false
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color.primaryBlue)
                }
                #endif
            }
            .onAppear {
                isAmountFocused = true
                #if canImport(PhotosUI)
                if initialOpenScan {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showPhotoPicker = true
                    }
                }
                #endif
            }
            #if canImport(PhotosUI)
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    await processPickedPhoto(newItem)
                }
            }
            #endif
        }
    }

    // MARK: - 1. Hero Amount Card (Amount + Currency Selector)
    @ViewBuilder @MainActor
    private var amountHeroCard: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                // Inline currency menu button (Takes 0 extra rows!)
                Menu {
                    ForEach(CurrencyType.allCases) { cur in
                        Button(action: {
                            Haptics.selection()
                            selectedCurrency = cur
                        }) {
                            HStack {
                                Text("\(cur.symbol) \(cur.rawValue)")
                                if selectedCurrency == cur {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(selectedCurrency.symbol)
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(Color.primaryBlue)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.primaryBlue.opacity(0.6))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.primaryBlue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                
                #if os(iOS)
                TextField("0", text: $amountText)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .multilineTextAlignment(.leading)
                    .onChange(of: amountText) { _, _ in
                        showErrorHint = false
                    }
                #else
                TextField("0", text: $amountText)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .multilineTextAlignment(.leading)
                #endif
            }
            
            if showErrorHint {
                Text(l10n.language == .hebrew ? "נא להזין סכום ולבחור קטגוריה" : "Please enter amount and pick category")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color.red)
                    .transition(.opacity)
            }
            
            if selectedCurrency != .ils, let val = parseAmount(amountText), val > 0 {
                let inILS = val * selectedCurrency.rateToILS
                HStack(spacing: 4) {
                    ExchangeVectorIcon(color: Color.themeMint)
                    Text(l10n.language == .hebrew ? "שווה ערך ל-\(l10n.format(amount: inILS, showDecimals: true))" : "≈ \(l10n.format(amount: inILS, showDecimals: true))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color.themeMint)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(showErrorHint ? Color.red.opacity(0.4) : Color.borderSubtle, lineWidth: 1.5))
                .shadow(color: Color.deepNavy.opacity(0.04), radius: 8, y: 3)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - 2. Unified 3x3 Category Grid (Single-layer clean cards)
    @ViewBuilder @MainActor
    private var categoryGridSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n.language == .hebrew ? "בחר קטגוריה" : "Select Category")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(Color.deepNavy)
                .padding(.horizontal, 20)
            
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
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            selectedCategory = cat
                            showErrorHint = false
                            let available = CityBuilding.buildings(for: cat)
                            if !available.contains(where: { $0.id == selectedBuildingId }) {
                                selectedBuildingId = CategorizationEngine.shared.mapToBuildingId(category: cat, merchant: note)
                                if !available.contains(where: { $0.id == selectedBuildingId }), let first = available.first {
                                    selectedBuildingId = first.id
                                }
                            }
                        }
                        // Dismiss keyboard so user has full view of save button & options
                        isAmountFocused = false
                    }) {
                        VStack(spacing: 6) {
                            CategoryVectorIcon(
                                category: cat,
                                color: isSelected ? cat.themeColor : Color.deepNavy.opacity(0.85),
                                size: 22
                            )
                            
                            Text(cat.shortName)
                                .font(.system(size: 13, weight: isSelected ? .black : .semibold, design: .rounded))
                                .foregroundColor(isSelected ? cat.themeColor : Color.deepNavy)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(isSelected ? cat.softBackgroundColor : Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isSelected ? cat.themeColor : Color.borderSubtle, lineWidth: isSelected ? 2 : 1)
                        )
                        .shadow(color: isSelected ? cat.themeColor.opacity(0.16) : Color.deepNavy.opacity(0.02), radius: 4, y: 2)
                        .scaleEffect(isSelected ? 1.04 : 1.0)
                    }
                    .bouncyPress(scale: 0.94)
                }
            }
            .padding(.horizontal, 20)

            // Dynamic Building Chips
            if let cat = selectedCategory {
                let buildings = CityBuilding.buildings(for: cat)
                if buildings.count > 1 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(l10n.language == .hebrew ? "בניין בעיר:" : "3D Building:")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(Color.slate400)
                            Spacer()
                            if let bId = selectedBuildingId, let building = CityBuilding.find(id: bId) {
                                Text(building.displayName(for: l10n.language))
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(cat.themeColor)
                            }
                        }
                        .padding(.horizontal, 22)

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
                                        .background(isBSelected ? cat.softBackgroundColor : Color.cardBackground)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(isBSelected ? cat.themeColor : Color.borderSubtle, lineWidth: isBSelected ? 1.5 : 1))
                                    }
                                    .bouncyPress(scale: 0.95)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
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
                    Image(systemName: showAdvancedOptions ? "chevron.up.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 13, weight: .bold))
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
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.borderSubtle, lineWidth: 1))
                    
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
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.borderSubtle, lineWidth: 1))
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
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                Text(l10n.language == .hebrew ? "שמור הוצאה" : "Save Transaction")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                (parseAmount(amountText) != nil && selectedCategory != nil)
                    ? Color.primaryBlue
                    : Color.primaryBlue.opacity(0.65)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.primaryBlue.opacity(0.35), radius: 10, y: 5)
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

    private func submitInstallments(category: SpendingCategory, total: Double) {
        let converted = selectedCurrency == .ils ? total : (total * selectedCurrency.rateToILS)
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
            category: category
        )
        modelContext.insert(plan)

        for tx in InstallmentService.makeTransactions(for: plan) {
            modelContext.insert(tx)
        }

        try? modelContext.save()
        Haptics.notify(.success)
        dismiss()
    }

    // MARK: - Multi-Transaction Review Card

    @ViewBuilder @MainActor
    private var multiTransactionReviewSection: some View {
        if scannedMultiCandidates.count > 1 {
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
            Image(systemName: "sparkles.rectangle.stack.fill")
                .foregroundColor(Color.primaryBlue)
                .font(.system(size: 14))
            Text(l10n.language == .hebrew ? "זוהו \(scannedMultiCandidates.count) עסקאות בצילום המסך" : "Found \(scannedMultiCandidates.count) Purchases")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
            Spacer()
            Button(action: {
                withAnimation(.spring(response: 0.25)) {
                    scannedMultiCandidates = []
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color.slate400)
                    .font(.system(size: 16))
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

        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(candidate.category.themeColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: candidate.category.sfSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(candidate.category.themeColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.merchant)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .lineLimit(1)
                Text(candidate.category.displayName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.slate500)
            }

            Spacer()

            Text("₪\(displayAmt)")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(Color.deepNavy)
        }
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.slate200, lineWidth: 0.8)
        )
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

        Button(action: {
            saveAllScannedMultiTransactions()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                Text(l10n.language == .hebrew ? "שמור את כל \(scannedMultiCandidates.count) העסקאות (\(formattedTotal))" : "Save All \(scannedMultiCandidates.count) Purchases (\(formattedTotal))")
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
        try? modelContext.save()
        Haptics.notify(.success)
        dismiss()
    }

    #if canImport(PhotosUI)
    private func processPickedPhoto(_ item: PhotosPickerItem) async {
        await MainActor.run { isScanningScreenshot = true }
        defer { Task { @MainActor in isScanningScreenshot = false } }
        
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let rules = DatabaseService.shared.fetchMerchantRules()
        
        do {
            let result = try await ReceiptOCRService.scanImage(data: data, rules: rules)
            await MainActor.run {
                if result.candidates.count > 1 {
                    scannedMultiCandidates = result.candidates
                    Haptics.notify(.success)
                } else if let single = result.primary {
                    scannedMultiCandidates = []
                    amountText = (single.amount.truncatingRemainder(dividingBy: 1) == 0) ? String(format: "%.0f", single.amount) : String(format: "%.2f", single.amount)
                    note = single.merchant
                    selectedCategory = single.category
                    selectedBuildingId = single.buildingId
                    isAmountFocused = false
                    Haptics.notify(.success)
                }
            }
        } catch {
            await MainActor.run {
                Haptics.notify(.warning)
                showErrorHint = true
            }
        }
    }
    #endif
}
