import SwiftUI
import SwiftData

/// Bottom-sheet for editing an existing transaction's merchant name, amount, and category.
public struct EditTransactionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager

    let transaction: Transaction

    @State private var merchantText: String = ""
    @State private var amountText: String = ""
    @State private var selectedCategory: SpendingCategory = .food
    @State private var showAmountError: Bool = false

    @State private var showDeleteConfirm: Bool = false

    private let appBg = Color(red: 248/255, green: 250/255, blue: 252/255)

    public init(transaction: Transaction) {
        self.transaction = transaction
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.slate200)
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Text(l10n.language == .hebrew ? "ביטול" : "Cancel")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(Color.slate500)
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

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Merchant
                    VStack(alignment: .leading, spacing: 6) {
                        Text(l10n.language == .hebrew ? "שם העסק" : "Merchant")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color.slate400)
                            .padding(.leading, 4)
                        TextField(l10n.language == .hebrew ? "שם העסק" : "Merchant name", text: $merchantText)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .padding(14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.slate200, lineWidth: 1))
                    }

                    // Amount
                    VStack(alignment: .leading, spacing: 6) {
                        Text(l10n.language == .hebrew ? "סכום" : "Amount")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color.slate400)
                            .padding(.leading, 4)
                        HStack(spacing: 8) {
                            Text(l10n.baseCurrency.symbol)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                            #if os(iOS)
                            TextField("0", text: $amountText)
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundColor(showAmountError ? Color.red : Color(red: 15/255, green: 23/255, blue: 42/255))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(TextAlignment.leading)
                                .onChange(of: amountText) { _, _ in showAmountError = false }
                            #else
                            TextField("0", text: $amountText)
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundColor(showAmountError ? Color.red : Color(red: 15/255, green: 23/255, blue: 42/255))
                                .multilineTextAlignment(TextAlignment.leading)
                                .onChange(of: amountText) { _, _ in showAmountError = false }
                            #endif
                        }
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(showAmountError ? Color.red.opacity(0.5) : Color.slate200, lineWidth: 1))
                        if showAmountError {
                            Text(l10n.language == .hebrew ? "נא להזין סכום תקין" : "Please enter a valid amount")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.red)
                                .padding(.leading, 4)
                        }
                    }

                    // Category picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text(l10n.language == .hebrew ? "קטגוריה" : "Category")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color.slate400)
                            .padding(.leading, 4)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                            ForEach(SpendingCategory.primaryCategories, id: \.self) { cat in
                                categoryCell(cat)
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
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(red: 254/255, green: 202/255, blue: 202/255), lineWidth: 1))
                    }
                    .padding(.top, 12)

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture {
                #if canImport(UIKit)
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                #endif
            }
        }
        .background(appBg.ignoresSafeArea())
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
        .onAppear {
            merchantText = transaction.merchant
            amountText = formatAmount(transaction.amount)
            selectedCategory = transaction.category
        }
    }

    // MARK: - Category Cell

    private func categoryCell(_ cat: SpendingCategory) -> some View {
        let isSelected = selectedCategory == cat
        return Button(action: {
            withAnimation(.spring(response: 0.25)) {
                selectedCategory = cat
            }
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        }) {
            VStack(spacing: 5) {
                CategoryBadge(category: cat, size: 48, isSelected: isSelected)
                Text(cat.localizedShortName(for: l10n.language))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? cat.themeColor : Color.slate500)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .scaleEffect(isSelected ? 1.06 : 1.0)
            .animation(.spring(response: 0.25), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private func save() {
        let normalized = amountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let amount = Double(normalized), amount > 0 else {
            withAnimation { showAmountError = true }
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
            return
        }
        transaction.merchant = merchantText.trimmingCharacters(in: .whitespaces).isEmpty ? transaction.merchant : merchantText.trimmingCharacters(in: .whitespaces)
        transaction.amount = amount
        // A correction here is knowledge about this merchant, not just this row.
        if transaction.category != selectedCategory {
            DatabaseService.shared.rememberCorrection(
                merchant: transaction.merchant,
                category: selectedCategory
            )
        }
        transaction.category = selectedCategory
        transaction.isConfirmed = true
        transaction.confidenceScore = 1.0
        // The user's chosen category is authoritative, including its city building.
        transaction.buildingIdRaw = CategorizationEngine.shared.mapToBuildingId(
            category: selectedCategory,
            merchant: transaction.merchant
        )
        try? modelContext.save()
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        dismiss()
    }

    // MARK: - Delete

    private func deleteTransaction() {
        withAnimation {
            modelContext.delete(transaction)
        }
        try? modelContext.save()
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        dismiss()
    }

    private func formatAmount(_ v: Double) -> String {
        if v == v.rounded() { return "\(Int(v))" }
        return String(format: "%.2f", v)
    }
}
