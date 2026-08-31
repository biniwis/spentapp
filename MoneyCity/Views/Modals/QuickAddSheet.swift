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
    public let onSave: (_ amount: Double, _ category: SpendingCategory, _ merchant: String, _ originalAmount: Double?, _ originalCurrency: String?, _ exchangeRate: Double?) -> Void
    
    @State private var amountText: String = ""
    @State private var note: String = ""
    @State private var selectedCurrency: CurrencyType = .ils
    @State private var selectedCategory: SpendingCategory? = nil
    @State private var showErrorHint = false
    @State private var paymentCount: Int = 1

    #if canImport(PhotosUI)
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    #endif
    @State private var isScanningScreenshot = false

    @Environment(\.modelContext) private var modelContext
    @FocusState private var isAmountFocused: Bool
    
    private func parseAmount(_ text: String) -> Double? {
        let clean = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(clean)
    }

    private var perPaymentPreview: Int? {
        guard paymentCount > 1, let total = parseAmount(amountText), total > 0 else { return nil }
        return Int(round(total / Double(paymentCount)))
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        #if canImport(PhotosUI)
                        scannerPill
                        #endif

                        currencyPickerRow
                        amountInputField
                        merchantNoteInput
                        installmentsSelector
                        categoryGridSection
                        saveTransactionButton
                        
                        Spacer(minLength: 30)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    #if os(iOS)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    #endif
                }
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
            }
        }
    }

    #if canImport(PhotosUI)
    private var scannerPill: some View {
        Group {
            if isScanningScreenshot {
                ReceiptScanningSkeletonView()
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.themeMintSoft)
                                .frame(width: 34, height: 34)
                            CameraVectorIcon(color: Color.themeMint)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.language == .hebrew ? "סריקת צילום מסך או קבלה" : "Scan Screenshot or Receipt")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            Text(l10n.language == .hebrew ? "זיהוי אוטומטי של סכום ועסק מתמונת אישור תשלום" : "Auto-extract amount & merchant from receipt")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(Color.textMuted)
                        }
                        
                        Spacer()
                        
                        Text(verbatim: l10n.language == .hebrew ? "‹" : "›")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Color.textMuted)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.borderSubtle, lineWidth: 1.2))
                    .shadow(color: Color.deepNavy.opacity(0.03), radius: 6, y: 2)
                }
                .bouncyPress(scale: 0.96)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .onChange(of: selectedPhotoItem) { _, newItem in
                    guard let newItem else { return }
                    Task {
                        await processPickedPhoto(newItem)
                    }
                }
            }
        }
    }
    #endif

    private var currencyPickerRow: some View {
        HStack(spacing: 8) {
            ForEach(CurrencyType.allCases) { cur in
                Button(action: {
                    withAnimation(.spring(response: 0.25)) {
                        selectedCurrency = cur
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(cur.symbol)
                            .font(.system(size: 14, weight: .black, design: .rounded))
                        Text(cur.rawValue)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(selectedCurrency == cur ? Color.white : Color.deepNavy)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(selectedCurrency == cur ? Color.primaryBlue : Color.cardBackground)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(selectedCurrency == cur ? Color.clear : Color.borderSubtle, lineWidth: 1.2))
                    .shadow(color: selectedCurrency == cur ? Color.primaryBlue.opacity(0.3) : Color.deepNavy.opacity(0.02), radius: 4, y: 2)
                }
                .bouncyPress(scale: 0.92)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var amountInputField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(selectedCurrency.symbol)
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundColor(Color.primaryBlue)
                
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
                Text(l10n.language == .hebrew ? "אנא הזן סכום תקין ובחר קטגוריה" : "Please enter a valid amount and category")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color.red)
                    .transition(.opacity)
            }
            
            if selectedCurrency != .ils, let val = parseAmount(amountText), val > 0 {
                let inILS = val * selectedCurrency.rateToILS
                HStack(spacing: 4) {
                    ExchangeVectorIcon(color: Color.themeMint)
                    Text(l10n.language == .hebrew ? "שווה ערך ל-₪\(String(format: "%.2f", inILS)) (שער: 1\(selectedCurrency.symbol) = ₪\(String(format: "%.2f", selectedCurrency.rateToILS)))" : "Equivalent to ₪\(String(format: "%.2f", inILS)) (Rate: 1\(selectedCurrency.symbol) = ₪\(String(format: "%.2f", selectedCurrency.rateToILS)))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color.themeMint)
                .padding(.top, 2)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(showErrorHint ? Color.red.opacity(0.4) : Color.borderSubtle, lineWidth: 1.5))
                .shadow(color: Color.deepNavy.opacity(0.04), radius: 8, y: 3)
        )
        .padding(.horizontal, 20)
    }

    private var merchantNoteInput: some View {
        HStack(spacing: 10) {
            NoteVectorIcon(color: Color.textMuted)
            TextField(l10n.language == .hebrew ? "שם בית העסק / הערה (אופציונלי)" : "Note / Merchant name (optional)", text: $note)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color.deepNavy)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.borderSubtle, lineWidth: 1.2))
        .padding(.horizontal, 20)
    }

    private var installmentsSelector: some View {
        HStack(spacing: 10) {
            Text(l10n.language == .hebrew ? "תשלום" : "Payment")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)

            Spacer()

            HStack(spacing: 6) {
                ForEach([1, 3, 6, 12], id: \.self) { count in
                    let isSelected = paymentCount == count
                    Button(action: {
                        Haptics.selection()
                        paymentCount = count
                    }) {
                        Text(count == 1 ? (l10n.language == .hebrew ? "רגיל" : "1x") : "\(count)x")
                            .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                            .foregroundColor(isSelected ? Color.primaryBlue : Color.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color.primaryBlue.opacity(0.12) : Color.borderSubtle.opacity(0.5))
                            .clipShape(Capsule())
                    }
                    .bouncyPress(scale: 0.92)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.borderSubtle, lineWidth: 1.2))
        .padding(.horizontal, 20)
    }

    private var categoryGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n.language == .hebrew ? "בחר קטגוריה ורובע בעיר" : "Select Category & District")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(Color.deepNavy)
                .padding(.horizontal, 20)
            
            let topCats: [SpendingCategory] = [.food, .shopping, .transport, .housing]
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(topCats) { cat in
                    let isSelected = selectedCategory == cat
                    Button(action: {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                            selectedCategory = cat
                        }
                    }) {
                        HStack(spacing: 10) {
                            CategoryBadge(category: cat, size: 36, isSelected: isSelected)
                            
                            Text(cat.displayName)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                                .lineLimit(1)
                            
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? Color.primaryBlue : Color.borderSubtle, lineWidth: isSelected ? 2 : 1.2)
                        )
                        .shadow(color: isSelected ? Color.primaryBlue.opacity(0.12) : Color.deepNavy.opacity(0.03), radius: 6, y: 2)
                        .scaleEffect(isSelected ? 1.02 : 1.0)
                    }
                    .bouncyPress(scale: 0.94)
                }
            }
            .padding(.horizontal, 20)

            let otherCats: [SpendingCategory] = [.entertainment, .health, .subscriptions, .savings, .other]
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.language == .hebrew ? "כל הקטגוריות" : "All categories")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(otherCats) { cat in
                            let isSelected = selectedCategory == cat
                            Button(action: {
                                Haptics.selection()
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                                    selectedCategory = cat
                                }
                            }) {
                                VStack(spacing: 4) {
                                    CategoryBadge(category: cat, size: 44, isSelected: isSelected)
                                        .scaleEffect(isSelected ? 1.08 : 1.0)
                                    
                                    Text(cat.shortName)
                                        .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                                        .foregroundColor(isSelected ? Color.primaryBlue : Color.textSecondary)
                                }
                                .frame(width: 58)
                            }
                            .bouncyPress(scale: 0.90)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var saveTransactionButton: some View {
        Button(action: {
            if let cat = selectedCategory {
                submit(category: cat)
            } else {
                showErrorHint = true
                Haptics.notify(.warning)
            }
        }) {
            Text(l10n.language == .hebrew ? "שמור הוצאה" : "Save Transaction")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.primaryBlue)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: Color.primaryBlue.opacity(0.35), radius: 10, y: 5)
        }
        .bouncyPress(scale: 0.96)
        .padding(.horizontal, 20)
        .padding(.top, 8)
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

        onSave(converted, category, merchant, origAmt, origCurr, rate)
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

    #if canImport(PhotosUI)
    private func processPickedPhoto(_ item: PhotosPickerItem) async {
        await MainActor.run { isScanningScreenshot = true }
        defer { Task { @MainActor in isScanningScreenshot = false } }
        
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let rules = DatabaseService.shared.fetchMerchantRules()
        
        do {
            let result = try await ReceiptOCRService.scanImage(data: data, rules: rules)
            await MainActor.run {
                amountText = (result.amount.truncatingRemainder(dividingBy: 1) == 0) ? String(format: "%.0f", result.amount) : String(format: "%.2f", result.amount)
                note = result.merchant
                selectedCategory = result.category
                isAmountFocused = false
                Haptics.notify(.success)
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
