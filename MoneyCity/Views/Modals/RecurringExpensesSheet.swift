import SwiftUI
import SwiftData

/// Manages fixed monthly expenses — the charges the Wallet automation can never see.
public struct RecurringExpensesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager

    @Query(sort: \RecurringExpense.dayOfMonth) private var templates: [RecurringExpense]

    @State private var editing: RecurringExpense? = nil
    @State private var isAdding = false

    private let sheetBg = Color(red: 248/255, green: 250/255, blue: 252/255)

    public init() {}

    private var isHebrew: Bool { l10n.language == .hebrew }

    private var monthlyTotal: Double {
        templates.filter { $0.isActive }.reduce(0) { $0 + $1.amount }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                sheetBg.ignoresSafeArea()

                if templates.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            summaryCard
                            ForEach(templates) { template in
                                row(template)
                            }
                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
            }
            .navigationTitle(isHebrew ? "הוצאות קבועות" : "Fixed Expenses")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.text(for: "close")) { dismiss() }
                        .foregroundColor(Color.primaryBlue)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { isAdding = true } label: {
                        ZStack {
                            Circle()
                                .fill(Color.primaryBlue.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Text(verbatim: "+")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(Color.primaryBlue)
                        }
                    }
                }
            }
            .sheet(isPresented: $isAdding) {
                RecurringExpenseEditor(template: nil)
                    .environmentObject(l10n)
            }
            .sheet(item: $editing) { template in
                RecurringExpenseEditor(template: template)
                    .environmentObject(l10n)
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
            SpentEmptyState(
                icon: .calendar,
                title: isHebrew ? "יש הוצאות שחוזרות כל חודש" : "Some expenses come around every month",
                message: isHebrew ? "שכירות, חשבונות ומנויים — הגדר אותם פעם אחת, והם יירשמו אוטומטית ביומן בכל חודש. אפשר לערוך או להשהות בכל רגע."
                    : "Set up rent, bills and subscriptions once. They will be recorded each month, and you can edit or pause them anytime.",
                actionTitle: isHebrew ? "הוספת הוצאה קבועה" : "Add fixed expense",
                action: { isAdding = true }
            ).padding(.top, 40)
        }
    }

    private var summaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(isHebrew ? "סה״כ קבוע בחודש" : "Fixed monthly total")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                Text(l10n.format(amount: monthlyTotal))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
            }
            Spacer()
            Text("\(templates.filter { $0.isActive }.count) \(isHebrew ? "פעילות" : "active")")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Color.primaryBlue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.primaryBlue.opacity(0.10))
                .clipShape(Capsule())
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.02), radius: 6, y: 2)
    }

    private func row(_ template: RecurringExpense) -> some View {
        Button {
            editing = template
        } label: {
            HStack(spacing: 12) {
                CategoryBadge(category: template.category, size: 42)
                    .opacity(template.isActive ? 1 : 0.45)

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.merchant)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    Text(isHebrew ? "כל \(template.dayOfMonth) בחודש" : "Day \(template.dayOfMonth) each month")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(Color.textMuted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(template.currency)\(String(format: "%.2f", template.amount))")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    if !template.isActive {
                        Text(isHebrew ? "מושהה" : "Paused")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Color.textMuted)
                    }
                }
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.02), radius: 6, y: 2)
            .opacity(template.isActive ? 1 : 0.7)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                template.isActive.toggle()
                try? modelContext.save()
                Haptics.impact(.light)
            } label: {
                Text(template.isActive ? (isHebrew ? "השהה" : "Pause") : (isHebrew ? "הפעל" : "Resume"))
            }
            Button(role: .destructive) {
                modelContext.delete(template)
                try? modelContext.save()
                Haptics.notify(.warning)
            } label: {
                Text(isHebrew ? "מחק" : "Delete")
            }
        }
    }
}

// MARK: - Add / Edit

struct RecurringExpenseEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager

    let template: RecurringExpense?

    @State private var merchant: String = ""
    @State private var amountText: String = ""
    @State private var category: SpendingCategory = .housing
    @State private var dayOfMonth: Int = 1

    private enum Field: Hashable {
        case merchant
    }

    @FocusState private var focusedField: Field?
    @State private var isEditingAmount: Bool = false
    @State private var cursorVisible: Bool = true

    private var isHebrew: Bool { l10n.language == .hebrew }

    private var canSave: Bool {
        !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (TransactionIngest.normalizedAmount(nil, amountText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { scrollProxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {

                            field(title: isHebrew ? "שם ההוצאה" : "Name") {
                                TextField(isHebrew ? "שכר דירה" : "Rent", text: $merchant)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                    .focused($focusedField, equals: .merchant)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text(isHebrew ? "סכום חודשי" : "Monthly amount")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundColor(Color.textMuted)

                                Button(action: {
                                    focusedField = nil
                                    #if canImport(UIKit)
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
                                            .font(.system(size: 20, weight: .black, design: .rounded))
                                            .foregroundColor(amountText.isEmpty ? Color.textMuted : Color.deepNavy)

                                        if isEditingAmount {
                                            RoundedRectangle(cornerRadius: 1)
                                                .fill(Color.primaryBlue)
                                                .frame(width: 2, height: 22)
                                                .opacity(cursorVisible ? 1.0 : 0.0)
                                        }

                                        Spacer()
                                    }
                                    .environment(\.layoutDirection, .leftToRight)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(
                                                isEditingAmount ? Color.primaryBlue.opacity(0.8) : Color.clear,
                                                lineWidth: isEditingAmount ? 1.5 : 0
                                            )
                                    )
                                    .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
                                }
                                .buttonStyle(.plain)
                            }
                            .id("amountRow")

                            dayOfMonthPicker

                            VStack(alignment: .leading, spacing: 8) {
                                Text(isHebrew ? "קטגוריה" : "Category")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundColor(Color.textMuted)

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(SpendingCategory.primaryCategories) { cat in
                                        Button {
                                            category = cat
                                        } label: {
                                            HStack(spacing: 8) {
                                                CategoryVectorIcon(category: cat, size: 16)
                                                Text(cat.localizedShortName(for: l10n.language))
                                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                                    .foregroundColor(Color.deepNavy)
                                                Spacer(minLength: 0)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .fill(category == cat ? cat.themeColor.opacity(0.14) : Color.white)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 14)
                                                            .stroke(category == cat ? cat.themeColor : Color.clear, lineWidth: category == cat ? 1.6 : 0)
                                                    )
                                                    .shadow(color: Color.black.opacity(0.02), radius: 4, y: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            Text(isHebrew
                                 ? "ההוצאה תיווצר אוטומטית בכל חודש ביום שנבחר. אם כבר רשומה הוצאה מאותו שם באותו חודש, היא לא תיווצר פעמיים."
                                 : "This posts automatically each month on the chosen day. If a charge with the same name already exists that month, it will not be duplicated.")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(Color.textMuted)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: isEditingAmount ? 260 : 20)
                        }
                        .padding(20)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField = nil
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            isEditingAmount = false
                        }
                        #if canImport(UIKit)
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        #endif
                    }
                    .onChange(of: isEditingAmount) { _, isEditing in
                        if isEditing {
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
                            Text(isHebrew ? "עריכת סכום" : "Edit Amount")
                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.textMuted)

                            Spacer()

                            Button(action: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                    isEditingAmount = false
                                }
                            }) {
                                Text(isHebrew ? "סיום" : "Done")
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

                        SpentAmountKeypad(amountText: $amountText)
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
            .background(Color(red: 248/255, green: 250/255, blue: 252/255).ignoresSafeArea())
            .navigationTitle(template == nil
                             ? (isHebrew ? "הוצאה קבועה חדשה" : "New fixed expense")
                             : (isHebrew ? "עריכת הוצאה קבועה" : "Edit fixed expense"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(isHebrew ? "סיום" : "Done") {
                        focusedField = nil
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.text(for: "cancel")) { dismiss() }
                        .foregroundColor(Color.textSecondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(isHebrew ? "שמור" : "Save") { save() }
                        .foregroundColor(canSave ? Color.primaryBlue : Color.borderSubtle)
                        .disabled(!canSave)
                }
            }
            .onChange(of: focusedField) { _, field in
                if field == .merchant {
                    withAnimation(.spring(response: 0.25)) {
                        isEditingAmount = false
                    }
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
            .onAppear(perform: load)
        }
    }

    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(Color.textMuted)
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
        }
    }

    private var dayOfMonthPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isHebrew ? "יום החיוב בחודש" : "Charged on day")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(Color.textMuted)

                Spacer()

                Text(isHebrew ? "כל \(dayOfMonth) בחודש" : "Day \(dayOfMonth) each month")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.primaryBlue)
            }

            HStack(spacing: 8) {
                Button {
                    if dayOfMonth > 1 {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.25)) {
                            dayOfMonth -= 1
                        }
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(dayOfMonth > 1 ? Color.deepNavy : Color.textMuted.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .background(Color(red: 243/255, green: 245/255, blue: 248/255))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(dayOfMonth <= 1)

                ScrollViewReader { dayProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(1...31, id: \.self) { day in
                                let isSelected = (dayOfMonth == day)
                                Button {
                                    Haptics.selection()
                                    withAnimation(.spring(response: 0.25)) {
                                        dayOfMonth = day
                                    }
                                } label: {
                                    Text("\(day)")
                                        .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                                        .foregroundColor(isSelected ? .white : Color.deepNavy)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(isSelected ? Color.primaryBlue : Color(red: 243/255, green: 245/255, blue: 248/255))
                                        )
                                }
                                .buttonStyle(.plain)
                                .id(day)
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 2)
                    }
                    .onAppear {
                        dayProxy.scrollTo(dayOfMonth, anchor: .center)
                    }
                    .onChange(of: dayOfMonth) { _, newDay in
                        withAnimation(.spring(response: 0.3)) {
                            dayProxy.scrollTo(newDay, anchor: .center)
                        }
                    }
                }

                Button {
                    if dayOfMonth < 31 {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.25)) {
                            dayOfMonth += 1
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(dayOfMonth < 31 ? Color.deepNavy : Color.textMuted.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .background(Color(red: 243/255, green: 245/255, blue: 248/255))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(dayOfMonth >= 31)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
        }
    }

    private func formatAmount(_ v: Double) -> String {
        if v == v.rounded() { return "\(MoneyAmount.displayInt(v))" }
        return String(format: "%.2f", v)
    }

    private func load() {
        guard let template else { return }
        merchant = template.merchant
        amountText = formatAmount(template.amount)
        category = template.category
        dayOfMonth = template.dayOfMonth
    }

    private func save() {
        guard let amount = TransactionIngest.normalizedAmount(nil, amountText), amount > 0 else { return }
        let name = merchant.trimmingCharacters(in: .whitespacesAndNewlines)

        if let template {
            template.merchant = name
            template.amount = amount
            template.category = category
            template.dayOfMonth = min(31, max(1, dayOfMonth))
            template.currency = l10n.baseCurrency.symbol
        } else {
            let new = RecurringExpense(
                merchant: name,
                amount: amount,
                currency: l10n.baseCurrency.symbol,
                category: category,
                dayOfMonth: dayOfMonth
            )
            modelContext.insert(new)
        }

        try? modelContext.save()
        // Post anything already owed so the user sees the effect immediately.
        RecurringExpenseService.materializeDue(context: modelContext)
        Haptics.notify(.success)
        dismiss()
    }
}
