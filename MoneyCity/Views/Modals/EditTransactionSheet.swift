import SwiftUI
import SwiftData

/// Bottom-sheet for editing an existing transaction's merchant name, amount, and category.
public struct EditTransactionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager
    @Query(sort: \Transaction.timestamp, order: .reverse) private var allTransactions: [Transaction]

    let transaction: Transaction

    @State private var merchantText: String = ""
    @State private var amountText: String = ""
    @State private var selectedCategory: SpendingCategory = .food
    @State private var selectedBuildingId: String = "food_bistro"
    @State private var hasUserExplicitlySelectedCategory: Bool = false
    @State private var showAmountError: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var showMerchantDetails: Bool = false

    @FocusState private var isMerchantFocused: Bool
    @State private var isEditingAmount: Bool = false
    @State private var cursorVisible: Bool = true
    #if os(iOS)
    @State private var sheetDetent: PresentationDetent = .medium
    #endif

    private var liveAmount: Double? {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let val = Double(normalized), val > 0 else { return nil }
        return val
    }

    private var merchantVisitsCount: Int {
        let name = merchantText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return 1 }
        return allTransactions.filter {
            $0.merchant.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(name) == .orderedSame
        }.count
    }

    private var merchantTotalSpent: Double {
        let name = merchantText.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentDraft = liveAmount ?? abs(transaction.amount)
        guard !name.isEmpty else { return currentDraft }
        let otherTotal = allTransactions.filter {
            $0.id != transaction.id &&
            $0.merchant.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(name) == .orderedSame
        }.reduce(0) { $0 + $1.amount }
        return otherTotal + currentDraft
    }

    private let appBg = Color(red: 248/255, green: 250/255, blue: 252/255)

    public init(transaction: Transaction) {
        self.transaction = transaction
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Text(l10n.language == .hebrew ? "ביטול" : "Cancel")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                }
                Spacer()
                Text(l10n.language == .hebrew ? "עריכת הוצאה" : "Edit Transaction")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                Spacer()
                Button(action: save) {
                    Text(l10n.language == .hebrew ? "שמור" : "Save")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color.primaryBlue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Refund Review Banner
                        if transaction.note?.contains("זיכוי") == true || transaction.amount < 0 {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.themeMint.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    MoneyIcon(.refresh, size: 20)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(l10n.language == .hebrew ? "זוהה זיכוי / החזר מ-Apple Pay" : "Apple Pay Refund Detected")
                                        .font(.system(size: 13, weight: .black, design: .rounded))
                                        .foregroundColor(Color.deepNavy)
                                    Text(l10n.language == .hebrew ? "אישור עסקה זו יקזז את הסכום מסך ההוצאות החודשי שלך" : "Confirming will deduct this amount from your monthly spending")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(Color.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.themeMintSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Merchant
                        VStack(alignment: .leading, spacing: 6) {
                            Text(l10n.language == .hebrew ? "שם העסק" : "Merchant")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Color.textMuted)
                                .padding(.leading, 4)
                            TextField(l10n.language == .hebrew ? "שם העסק" : "Merchant name", text: $merchantText)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .focused($isMerchantFocused)
                                .onChange(of: isMerchantFocused) { _, isFocused in
                                    if isFocused {
                                        withAnimation(.spring(response: 0.25)) {
                                            isEditingAmount = false
                                        }
                                    }
                                }
                                .padding(14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)

                            if merchantVisitsCount > 1 {
                                Button(action: { showMerchantDetails = true }) {
                                    HStack(spacing: 6) {
                                        MoneyIcon(.clock, size: 14)
                                        Text(l10n.language == .hebrew ? "ביקרת כאן \(merchantVisitsCount) פעמים (סה״כ \(l10n.format(amount: merchantTotalSpent))) • צפה בהיסטוריה" : "\(merchantVisitsCount) visits (\(l10n.format(amount: merchantTotalSpent)) total) • View Details")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundColor(Color.primaryBlue)
                                        MoneyIcon(l10n.language == .hebrew ? .chevronLeft : .chevronRight, size: 10)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(red: 238/255, green: 242/255, blue: 255/255))
                                    .clipShape(Capsule())
                                }
                                .bouncyPress(scale: 0.95)
                                .padding(.top, 2)
                            }
                        }

                        // Amount
                        VStack(alignment: .leading, spacing: 6) {
                            Text(l10n.language == .hebrew ? "סכום" : "Amount")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Color.textMuted)
                                .padding(.leading, 4)

                            Button(action: {
                                isMerchantFocused = false
                                #if canImport(UIKit)
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                #endif
                                #if os(iOS)
                                sheetDetent = .large
                                #endif
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                    isEditingAmount = true
                                    scrollProxy.scrollTo("amountRow", anchor: .top)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                        scrollProxy.scrollTo("amountRow", anchor: .top)
                                    }
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Text(l10n.baseCurrency.symbol)
                                        .font(.system(size: 18, weight: .black, design: .rounded))
                                        .foregroundColor(Color.deepNavy)

                                    Text(amountText.isEmpty ? "0" : amountText)
                                        .font(.system(size: 22, weight: .black, design: .rounded))
                                        .foregroundColor(showAmountError ? Color.red : (amountText.isEmpty ? Color.textMuted : Color.deepNavy))

                                    if isEditingAmount {
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(Color.primaryBlue)
                                            .frame(width: 2, height: 22)
                                            .opacity(cursorVisible ? 1.0 : 0.0)
                                    }

                                    Spacer()
                                }
                                .environment(\.layoutDirection, .leftToRight)
                                .padding(14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(
                                            showAmountError ? Color.red.opacity(0.8) :
                                            (isEditingAmount ? Color.primaryBlue.opacity(0.8) : Color.clear),
                                            lineWidth: (showAmountError || isEditingAmount) ? 1.5 : 0
                                        )
                                )
                                .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
                            }
                            .buttonStyle(.plain)

                            if showAmountError {
                                Text(l10n.language == .hebrew ? "נא להזין סכום תקין" : "Please enter a valid amount")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.red)
                                    .padding(.leading, 4)
                            }
                        }
                        .id("amountRow")

                        // Category picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text(l10n.language == .hebrew ? "קטגוריה ראשית" : "Main Category")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Color.textMuted)
                                .padding(.leading, 4)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                                ForEach(SpendingCategory.primaryCategories, id: \.self) { cat in
                                    categoryCell(cat)
                                }
                            }
                        }

                        // 3D Building Association Selector
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(l10n.language == .hebrew ? "שיוך לבניין בעיר" : "Assign to 3D Building")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.textMuted)
                                Spacer()
                                if let b = CityBuilding.find(id: selectedBuildingId) {
                                    Text(b.displayName(for: l10n.language))
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(selectedCategory.themeColor)
                                }
                            }
                            .padding(.horizontal, 4)

                            let buildings = CityBuilding.buildings(for: selectedCategory)
                            VStack(spacing: 8) {
                                ForEach(buildings) { b in
                                    let isSelected = (selectedBuildingId == b.id)
                                    Button(action: {
                                        withAnimation(.spring(response: 0.25)) {
                                            selectedBuildingId = b.id
                                            hasUserExplicitlySelectedCategory = true
                                        }
                                        Haptics.impact(.light)
                                    }) {
                                        HStack(spacing: 12) {
                                            Text(b.emoji)
                                                .font(.system(size: 20))
                                                .frame(width: 38, height: 38)
                                                .background(isSelected ? selectedCategory.themeColor.opacity(0.15) : Color(red: 243/255, green: 244/255, blue: 246/255))
                                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(b.displayName(for: l10n.language))
                                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                                    .foregroundColor(isSelected ? selectedCategory.themeColor : Color.deepNavy)
                                                Text(b.description(for: l10n.language))
                                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                                    .foregroundColor(Color.textMuted)
                                            }

                                            Spacer()

                                            if isSelected {
                                                MoneyIcon(.checkCircle, size: 18)
                                            } else {
                                                Circle()
                                                    .stroke(Color.borderSubtle, lineWidth: 1.5)
                                                    .frame(width: 18, height: 18)
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(isSelected ? selectedCategory.softBackgroundColor.opacity(0.6) : Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(isSelected ? selectedCategory.themeColor : Color.clear, lineWidth: isSelected ? 1.5 : 0)
                                        )
                                        .shadow(color: Color.black.opacity(0.02), radius: 4, y: 1)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Delete Transaction Button
                        Button(role: .destructive, action: { showDeleteConfirm = true }) {
                            HStack(spacing: 8) {
                                TrashVectorIcon(color: Color(red: 239/255, green: 68/255, blue: 68/255))
                                Text(l10n.language == .hebrew ? "מחק הוצאה זו" : "Delete Transaction")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(Color(red: 239/255, green: 68/255, blue: 68/255))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 254/255, green: 242/255, blue: 242/255))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.top, 12)

                        Spacer(minLength: isEditingAmount ? 260 : 40)
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
                .contentShape(Rectangle())
                .onTapGesture {
                    isMerchantFocused = false
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        isEditingAmount = false
                    }
                    #if canImport(UIKit)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    #endif
                }
                .onChange(of: isEditingAmount) { _, isEditing in
                    if isEditing {
                        #if os(iOS)
                        sheetDetent = .large
                        #endif
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                scrollProxy.scrollTo("amountRow", anchor: .top)
                            }
                        }
                    }
                }
            }

            // Bottom-docked Numeric Keypad
            if isEditingAmount {
                VStack(spacing: 0) {
                    // Keyboard accessory bar
                    HStack {
                        Text(l10n.language == .hebrew ? "עריכת סכום" : "Edit Amount")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.textMuted)

                        Spacer()

                        Button(action: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                isEditingAmount = false
                            }
                        }) {
                            Text(l10n.language == .hebrew ? "סיום" : "Done")
                                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                .foregroundColor(Color.primaryBlue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color.primaryBlue.opacity(0.10))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 243/255, green: 245/255, blue: 248/255))

                    Divider()

                    SpentAmountKeypad(amountText: $amountText) { _ in
                        showAmountError = false
                    }
                    .environment(\.layoutDirection, .leftToRight)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                    .background(Color(red: 248/255, green: 250/255, blue: 252/255))
                }
                .background(
                    Color(red: 248/255, green: 250/255, blue: 252/255)
                        .shadow(color: Color.black.opacity(0.06), radius: 8, y: -2)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: isEditingAmount)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(l10n.language == .hebrew ? "סיום" : "Done") {
                    isMerchantFocused = false
                }
                .fontWeight(.semibold)
            }
        }
        .task(id: isEditingAmount) {
            guard isEditingAmount else { return }
            cursorVisible = true
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 550_000_000)
                cursorVisible.toggle()
            }
        }
        .background(appBg.ignoresSafeArea())
        #if os(iOS)
        .presentationDetents([.medium, .large], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
        #endif
        .confirmationDialog(
            l10n.language == .hebrew ? "האם למחוק הוצאה זו?" : "Delete this transaction?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(l10n.language == .hebrew ? "מחק הוצאה" : "Delete", role: .destructive) {
                deleteTransaction()
            }
            Button(l10n.language == .hebrew ? "ביטול" : "Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showMerchantDetails) {
            MerchantDetailSheet(merchantName: merchantText.trimmingCharacters(in: .whitespaces).isEmpty ? transaction.merchant : merchantText.trimmingCharacters(in: .whitespaces))
                .presentationDetents([.medium, .large])
                .environmentObject(l10n)
        }
        .onAppear {
            merchantText = transaction.merchant
            amountText = formatAmount(abs(transaction.amount))
            selectedCategory = transaction.category
            selectedBuildingId = transaction.buildingIdRaw ?? transaction.buildingId
        }
    }

    // MARK: - Category Cell

    private func categoryCell(_ cat: SpendingCategory) -> some View {
        let isSelected = selectedCategory == cat
        return Button(action: {
            withAnimation(.spring(response: 0.25)) {
                selectedCategory = cat
                hasUserExplicitlySelectedCategory = true
                updateBuildingForCategory(cat)
            }
            Haptics.impact(.light)
        }) {
            VStack(spacing: 4) {
                CategoryBadge(category: cat, size: 48, isSelected: isSelected)
                Text(cat.localizedShortName(for: l10n.language))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? cat.themeColor : Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .scaleEffect(isSelected ? 1.06 : 1.0)
            .animation(.spring(response: 0.25), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func updateBuildingForCategory(_ cat: SpendingCategory) {
        let available = CityBuilding.buildings(for: cat)
        if available.contains(where: { $0.id == selectedBuildingId }) {
            // Keep matching
        } else {
            selectedBuildingId = CategorizationEngine.shared.mapToBuildingId(category: cat, merchant: merchantText)
            if !available.contains(where: { $0.id == selectedBuildingId }), let first = available.first {
                selectedBuildingId = first.id
            }
        }
    }

    // MARK: - Save

    private func save() {
        let normalized = amountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let amount = MoneyAmount.sanitized(Double(normalized)) else {
            withAnimation { showAmountError = true }
            Haptics.notify(.error)
            return
        }
        let isRefund = transaction.note?.contains("זיכוי") == true || transaction.amount < 0
        let finalMerchant = merchantText.trimmingCharacters(in: .whitespaces).isEmpty ? transaction.merchant : merchantText.trimmingCharacters(in: .whitespaces)
        transaction.merchant = finalMerchant
        transaction.amount = isRefund ? -amount : amount
        if isRefund {
            transaction.note = "זיכוי מאושר"
        }
        // Only create/update a MerchantRule when the user's action genuinely represents
        // an explicit category choice/confirmation. Editing merchant text, note, amount,
        // date, etc. must NOT automatically convert an inferred category into a learned rule.
        let isExplicitCategoryAction = hasUserExplicitlySelectedCategory || (transaction.needsCategorization && selectedCategory != .other)
        if isExplicitCategoryAction && !finalMerchant.isEmpty && selectedCategory != .other {
            DatabaseService.shared.rememberCorrection(
                merchant: finalMerchant,
                category: selectedCategory,
                buildingId: selectedBuildingId
            )
        }
        transaction.category = selectedCategory
        transaction.buildingIdRaw = selectedBuildingId
        transaction.currency = l10n.baseCurrency.symbol
        transaction.isConfirmed = true
        transaction.confidenceScore = 1.0
        guard DatabaseService.safeSave(modelContext) else {
            Haptics.notify(.error)
            return
        }
        if transaction.savingsGoalId != nil {
            SavingsGoalService.reconcileAll(context: modelContext)
        }
        Haptics.notify(.success)
        dismiss()
    }

    // MARK: - Delete

    private func deleteTransaction() {
        let hadGoal = transaction.savingsGoalId != nil
        withAnimation {
            modelContext.delete(transaction)
        }
        guard DatabaseService.safeSave(modelContext) else {
            Haptics.notify(.error)
            return
        }
        if hadGoal {
            SavingsGoalService.reconcileAll(context: modelContext)
        }
        Haptics.notify(.success)
        dismiss()
    }

    private func formatAmount(_ v: Double) -> String {
        if v == v.rounded() { return "\(MoneyAmount.displayInt(v))" }
        return String(format: "%.2f", v)
    }
}
