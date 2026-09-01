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
        VStack(spacing: 12) {
            Image(systemName: "repeat")
                .font(.system(size: 38, weight: .bold))
                .foregroundColor(Color.primaryBlue)
            Text(isHebrew ? "אין עדיין הוצאות קבועות" : "No fixed expenses yet")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
            Text(isHebrew
                 ? "שכר דירה, ארנונה, מנויים — הגדר פעם אחת והם ייווצרו לבד כל חודש."
                 : "Rent, bills, subscriptions — set them up once and they post themselves each month.")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(Color.slate400)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                isAdding = true
            } label: {
                Text(isHebrew ? "הוספת הוצאה קבועה" : "Add fixed expense")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.primaryBlue))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
    }

    private var summaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(isHebrew ? "סה״כ קבוע בחודש" : "Fixed monthly total")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.slate400)
                Text("\(l10n.baseCurrency.symbol)\(Int(monthlyTotal))")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
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
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.slate200, lineWidth: 1))
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
                        .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                    Text(isHebrew ? "כל \(template.dayOfMonth) בחודש" : "Day \(template.dayOfMonth) each month")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(Color.slate400)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(template.currency)\(String(format: "%.2f", template.amount))")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                    if !template.isActive {
                        Text(isHebrew ? "מושהה" : "Paused")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Color.slate400)
                    }
                }
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.slate200, lineWidth: 1))
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

    private var isHebrew: Bool { l10n.language == .hebrew }

    private var canSave: Bool {
        !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (TransactionIngest.normalizedAmount(nil, amountText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 248/255, green: 250/255, blue: 252/255).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {

                        field(title: isHebrew ? "שם ההוצאה" : "Name") {
                            TextField(isHebrew ? "שכר דירה" : "Rent", text: $merchant)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }

                        field(title: isHebrew ? "סכום חודשי" : "Monthly amount") {
                            HStack(spacing: 6) {
                                Text(l10n.baseCurrency.symbol)
                                    .font(.system(size: 17, weight: .black, design: .rounded))
                                    .foregroundColor(Color.primaryBlue)
                                #if os(iOS)
                                TextField("0", text: $amountText)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .keyboardType(.decimalPad)
                                #else
                                TextField("0", text: $amountText)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                #endif
                            }
                        }

                        field(title: isHebrew ? "יום החיוב בחודש" : "Charged on day") {
                            Picker("", selection: $dayOfMonth) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("\(day)").tag(day)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color.primaryBlue)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(isHebrew ? "קטגוריה" : "Category")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(Color.slate400)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(SpendingCategory.primaryCategories) { cat in
                                    Button {
                                        category = cat
                                    } label: {
                                        HStack(spacing: 8) {
                                            CategoryVectorIcon(category: cat, size: 16)
                                            Text(cat.localizedShortName(for: l10n.language))
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                                            Spacer(minLength: 0)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(category == cat ? cat.themeColor.opacity(0.14) : Color.white)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .stroke(category == cat ? cat.themeColor : Color.slate200, lineWidth: category == cat ? 1.6 : 1)
                                                )
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
                            .foregroundColor(Color.slate400)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(template == nil
                             ? (isHebrew ? "הוצאה קבועה חדשה" : "New fixed expense")
                             : (isHebrew ? "עריכת הוצאה קבועה" : "Edit fixed expense"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.text(for: "cancel")) { dismiss() }
                        .foregroundColor(Color.slate400)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(isHebrew ? "שמור" : "Save") { save() }
                        .foregroundColor(canSave ? Color.primaryBlue : Color.slate300)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(Color.slate400)
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.slate200, lineWidth: 1))
        }
    }

    private func load() {
        guard let template else { return }
        merchant = template.merchant
        amountText = String(format: "%.2f", template.amount)
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
