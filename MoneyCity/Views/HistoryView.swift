import SwiftUI
import SwiftData

public struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager
    @Query(sort: \Transaction.timestamp, order: .reverse) private var allTransactions: [Transaction]

    @State private var searchText: String = ""
    @State private var selectedCategory: SpendingCategory? = nil
    @State private var showOnlyUnconfirmed: Bool = false

    /// Everything needed to put a deleted transaction back.
    private struct DeletedSnapshot: Equatable {
        let amount: Double
        let currency: String
        let merchant: String
        let category: SpendingCategory
        let timestamp: Date
        let note: String?
        let buildingId: String?
        let isManual: Bool
        let isConfirmed: Bool
        let confidenceScore: Double
        let originalAmount: Double?
        let originalCurrency: String?
        let exchangeRate: Double?
        /// Without this the restored row loses its link to a savings goal, and the next
        /// reconciliation quietly subtracts the deposit again.
        let savingsGoalId: UUID?
    }

    @State private var lastDeleted: DeletedSnapshot? = nil
    @State private var undoToken: UUID? = nil
    @State private var currentDate: Date = Date()
    @State private var editingTx: Transaction? = nil
    @State private var selectedMerchantForDetails: String? = nil
    @State private var openSwipeRowID: UUID? = nil

    @State private var isSearchExpanded: Bool = false
    @State private var showCalendarPicker: Bool = false
    @State private var calendarPickerDate: Date = Date()
    @State private var selectedSpecificDate: Date? = nil

    private var monthTransactions: [Transaction] {
        let cal = Calendar.current
        return allTransactions.filter {
            cal.isDate($0.timestamp, equalTo: currentDate, toGranularity: .month)
        }
    }

    private var displayTransactions: [Transaction] {
        if let specific = selectedSpecificDate {
            let cal = Calendar.current
            return allTransactions.filter {
                cal.isDate($0.timestamp, inSameDayAs: specific)
            }
        }
        return monthTransactions
    }

    private var unconfirmedCount: Int {
        displayTransactions.filter { !$0.isConfirmed }.count
    }

    private var filtered: [Transaction] {
        displayTransactions.filter { tx in
            if showOnlyUnconfirmed && tx.isConfirmed { return false }
            let catMatch = selectedCategory == nil || tx.category == selectedCategory
            let title = displayMerchantTitle(for: tx)
            let searchMatch = searchText.isEmpty
                || tx.merchant.localizedCaseInsensitiveContains(searchText)
                || title.localizedCaseInsensitiveContains(searchText)
                || tx.category.displayName.localizedCaseInsensitiveContains(searchText)
                || (tx.note ?? "").localizedCaseInsensitiveContains(searchText)
            return catMatch && searchMatch
        }
    }

    private var hasActiveFilters: Bool {
        !searchText.isEmpty || selectedCategory != nil || showOnlyUnconfirmed
    }

    private var totalFiltered: Double {
        filtered.filter { $0.category != .savings }.reduce(0) { $0 + $1.amount }
    }

    private var groupedByDay: [(date: Date, txs: [Transaction])] {
        let cal = Calendar.current
        var groups: [Date: [Transaction]] = [:]
        for tx in filtered {
            let day = cal.startOfDay(for: tx.timestamp)
            groups[day, default: []].append(tx)
        }
        return groups.sorted { $0.key > $1.key }.map { (date: $0.key, txs: $0.value) }
    }

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header Section (Matches Reference: Title + Month Pill on Right, Buttons on Left, Filter Bar) ──
                VStack(spacing: 12) {
                    // Top Navigation & Month Selector
                    HStack(alignment: .top) {
                        // Title & Month Capsule (Leading / Right in RTL)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(l10n.language == .hebrew ? "היסטוריה" : "History")
                                .font(.system(size: 28, weight: .bold, design: .default))
                                .foregroundColor(Color.deepNavy)

                            monthNavigationPill
                        }

                        Spacer()

                        // Circular Action Buttons (Trailing / Left in RTL)
                        HStack(spacing: 10) {
                            searchButton
                            calendarButton
                        }
                        .environment(\.layoutDirection, .leftToRight)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // Expandable Search Bar
                    if isSearchExpanded {
                        searchBar
                    }

                    // Filter Bar: Slider/Filter button on the left, horizontal category pills
                    HistoryFilterBar(
                        selectedCategory: $selectedCategory,
                        showOnlyUnconfirmed: $showOnlyUnconfirmed,
                        selectedSpecificDate: $selectedSpecificDate,
                        searchText: $searchText,
                        unconfirmedCount: unconfirmedCount,
                        dayLabel: { dayLabel($0) }
                    )
                }
                .background(Color.appBackground)

                // ── Transaction Ledger (Sitting directly on background, NO container cards) ──
                if filtered.isEmpty {
                    Spacer()
                    SpentEmptyState(
                        icon: hasActiveFilters ? .search : .receipt,
                        title: hasActiveFilters
                            ? (l10n.isHebrew ? "לא נמצאו עסקאות מתאימות" : "No matching transactions")
                            : (l10n.isHebrew ? "היומן שלך מתחיל כאן" : "Your spending story starts here"),
                        message: hasActiveFilters
                            ? (l10n.isHebrew ? "אפשר לנקות את הסינון ולראות את שאר העסקאות." : "Clear the filters to see your other transactions.")
                            : (l10n.isHebrew ? "אין עסקאות בתקופה הזו. הוצאות שתוסיף דרך כפתור + יופיעו כאן, מסודרות לפי יום." : "There are no transactions in this period. Add an expense with + to see it here, organized by day."),
                        actionTitle: hasActiveFilters ? (l10n.isHebrew ? "ניקוי הסינון" : "Clear filters") : nil,
                        action: { searchText = ""; selectedCategory = nil; showOnlyUnconfirmed = false }
                    )
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            ForEach(groupedByDay, id: \.date) { group in
                                daySection(group.date, txs: group.txs)
                            }
                            Spacer(minLength: 110)
                        }
                        .padding(.top, 8)
                    }
                }
            }

            // Undo Banner
            VStack {
                Spacer()
                undoBanner
            }
            .allowsHitTesting(lastDeleted != nil)
        }
        .sheet(item: $editingTx) { tx in
            EditTransactionSheet(transaction: tx)
                .presentationDetents([PresentationDetent.medium, PresentationDetent.large])
        }
        .sheet(item: Binding<IdentifiableMerchant?>(
            get: { selectedMerchantForDetails.map { IdentifiableMerchant(name: $0) } },
            set: { selectedMerchantForDetails = $0?.name }
        )) { item in
            MerchantDetailSheet(merchantName: item.name)
                .presentationDetents([.medium, .large])
                .environmentObject(l10n)
        }
        .sheet(isPresented: $showCalendarPicker) {
            HistoryCalendarSheet(
                calendarPickerDate: $calendarPickerDate,
                showCalendarPicker: $showCalendarPicker,
                onFilterDay: { pickedDate in
                    withAnimation(.spring(response: 0.35)) {
                        currentDate = pickedDate
                        selectedSpecificDate = pickedDate
                        showCalendarPicker = false
                    }
                },
                onShowEntireMonth: { pickedDate in
                    withAnimation(.spring(response: 0.35)) {
                        currentDate = pickedDate
                        selectedSpecificDate = nil
                        showCalendarPicker = false
                    }
                },
                onBackToToday: {
                    withAnimation(.spring(response: 0.35)) {
                        currentDate = Date()
                        selectedSpecificDate = nil
                        showCalendarPicker = false
                    }
                }
            )
            .environmentObject(l10n)
        }
    }

    private struct IdentifiableMerchant: Identifiable {
        var id: String { name }
        let name: String
    }

    // MARK: - Header Subviews & Navigation

    private var monthNavigationPill: some View {
        let isCurrentMonth = Calendar.current.isDate(currentDate, equalTo: Date(), toGranularity: .month)
        return HStack(spacing: 8) {
            Button(action: {
                Haptics.selection()
                shiftMonth(-1)
            }) {
                MoneyIcon(
                    l10n.isHebrew ? .chevronRight : .chevronLeft,
                    size: 11,
                    color: Color.deepNavy
                )
                .frame(width: 20, height: 20)
            }

            Button(action: {
                Haptics.selection()
                calendarPickerDate = currentDate
                showCalendarPicker = true
            }) {
                Text(shortMonth(currentDate))
                    .font(.system(size: 13.5, weight: .semibold, design: .default))
                    .foregroundColor(Color.deepNavy)
            }
            .buttonStyle(.plain)

            Button(action: {
                if !isCurrentMonth {
                    Haptics.selection()
                    shiftMonth(1)
                }
            }) {
                MoneyIcon(
                    l10n.isHebrew ? .chevronLeft : .chevronRight,
                    size: 11,
                    color: isCurrentMonth ? Color.borderSubtle : Color.deepNavy
                )
                .frame(width: 20, height: 20)
            }
            .disabled(isCurrentMonth)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        .environment(\.layoutDirection, .leftToRight)
    }

    private var searchButton: some View {
        Button(action: {
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isSearchExpanded.toggle()
                if !isSearchExpanded { searchText = "" }
            }
        }) {
            MoneyIcon(.search, size: 20)
                .frame(width: 38, height: 38)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var calendarButton: some View {
        Button(action: {
            Haptics.selection()
            calendarPickerDate = selectedSpecificDate ?? currentDate
            showCalendarPicker = true
        }) {
            MoneyIcon(.calendar, size: 20)
                .frame(width: 38, height: 38)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            MoneyIcon(.search, size: 16)
            TextField(l10n.language == .hebrew ? "חפש עסקה או קטגוריה..." : "Search transaction or category...", text: $searchText)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(Color.deepNavy)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    MoneyIcon(.xmarkCircle, size: 16)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        .padding(.horizontal, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
    }


    // MARK: - Day Section (Direct on Background, Editorial Ledger)

    private func daySection(_ date: Date, txs: [Transaction]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Day Header Row: Left Sum ("סה״כ ₪130.00"), Right Title ("היום")
            HStack(alignment: .firstTextBaseline) {
                Text(dayLabel(date))
                    .font(.system(size: 15.5, weight: .bold, design: .default))
                    .foregroundColor(Color.deepNavy)
                Spacer()
                HStack(spacing: 4) {
                    Text(l10n.language == .hebrew ? "סה״כ" : "Total")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(Color.textMuted)
                    Text(l10n.format(amount: txs.reduce(0) { $0 + $1.amount }, showDecimals: true))
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 4)

            // Transactions (No enclosing card!)
            VStack(spacing: 12) {
                ForEach(txs) { tx in
                    SwipeActionRow(
                        id: tx.id,
                        openSwipeRowID: $openSwipeRowID,
                        onEdit: {
                            editingTx = tx
                        },
                        onDelete: {
                            delete(tx)
                        }
                    ) {
                        txRow(tx)
                    }
                }
            }
        }
    }

    private func txRow(_ tx: Transaction) -> some View {
        let displayTitle = displayMerchantTitle(for: tx)

        return HStack(alignment: .top, spacing: 12) {
            // Circular Pastel Category Badge (42pt) showing subcategory icon
            CategoryBadge(transaction: tx, size: 42)

            // Merchant / Subcategory (Bold) + Category/Note (Muted Gray)
            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle)
                    .font(.system(size: 15.5, weight: .semibold, design: .default))
                    .foregroundColor(Color.deepNavy)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(tx.category.displayName)
                        .font(.system(size: 12.5, weight: .regular, design: .default))
                        .foregroundColor(Color(red: 148/255, green: 163/255, blue: 184/255))

                    let isRefund = tx.note?.contains("זיכוי") == true || tx.amount < 0
                    if isRefund {
                        Text(l10n.language == .hebrew ? "• ↩️ זיכוי" : "• ↩️ Refund")
                            .font(.system(size: 11, weight: .semibold, design: .default))
                            .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                    } else if !tx.isConfirmed {
                        Text(l10n.language == .hebrew ? "• סיווג לא ודאי" : "• unverified")
                            .font(.system(size: 11, weight: .semibold, design: .default))
                            .foregroundColor(Color(red: 245/255, green: 158/255, blue: 11/255))
                    }
                }
            }

            Spacer(minLength: 8)

            // Time + Amount (Left column in RTL, Right in LTR)
            HStack(spacing: 12) {
                Text(tx.timeString)
                    .font(.system(size: 12.5, weight: .regular, design: .default))
                    .foregroundColor(Color(red: 148/255, green: 163/255, blue: 184/255))

                let isRefund = tx.note?.contains("זיכוי") == true || tx.amount < 0
                if isRefund {
                    Text("+\(l10n.format(amount: abs(tx.amount), showDecimals: true))")
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                } else {
                    Text(l10n.format(amount: tx.amount, showDecimals: true))
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                }
            }
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                editingTx = tx
            } label: {
                Text(l10n.language == .hebrew ? "ערוך עסקה" : "Edit Transaction")
            }
            Button {
                selectedMerchantForDetails = displayTitle
            } label: {
                Text(l10n.language == .hebrew ? "פרטי בית עסק (\(displayTitle))" : "Merchant Details (\(displayTitle))")
            }
            if !tx.isConfirmed {
                Button {
                    DatabaseService.shared.rememberCorrection(merchant: tx.merchant, category: tx.category)
                    tx.isConfirmed = true
                    tx.confidenceScore = 1.0
                    try? modelContext.save()
                    Haptics.impact(.light)
                } label: {
                    Label {
                        Text(l10n.language == .hebrew ? "אשר את הסיווג" : "Confirm category")
                    } icon: {
                        MoneyIcon(.checkCircle, size: 18)
                    }
                }
            }
            Divider()
            Button(role: .destructive) {
                delete(tx)
            } label: {
                Text(l10n.language == .hebrew ? "מחק עסקה" : "Delete Transaction")
            }
        }
    }

    /// Returns the primary title to display for a transaction in the history feed.
    /// If no merchant was entered or if merchant equals category name, resolves to the subcategory name
    /// (e.g. "סופר ומכולת", "בתי קפה", "מסעדות") so the user doesn't see duplicate category names.
    private func displayMerchantTitle(for tx: Transaction) -> String {
        let rawMerchant = tx.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let cat = tx.category
        let isHebrew = l10n.language == .hebrew

        let isGeneric = rawMerchant.isEmpty
            || rawMerchant == cat.displayName
            || rawMerchant == cat.displayNameEn
            || rawMerchant == cat.shortName
            || rawMerchant == cat.rawValue
            || rawMerchant == "ללא שם"
            || rawMerchant.caseInsensitiveCompare("Unnamed") == .orderedSame

        if isGeneric {
            let subName = SubcategoryBreakdownService.shared.subcategoryName(for: tx, isHebrew: isHebrew)
            if !subName.isEmpty && subName != cat.displayName {
                return subName
            }
            if let note = tx.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty, !note.contains("זיכוי") {
                return note
            }
            return subName.isEmpty ? cat.displayName : subName
        }

        return rawMerchant
    }

    private var undoBanner: some View {
        Group {
            if let snap = lastDeleted {
                HStack(spacing: 12) {
                    TrashVectorIcon(color: MoneyCityTheme.destructive)
                    Text(l10n.language == .hebrew ? "נמחקה: \(snap.merchant)" : "Deleted: \(snap.merchant)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: undoDelete) {
                        Text(l10n.language == .hebrew ? "בטל" : "Undo")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(MoneyCityTheme.brandPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.deepNavy)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.18), radius: 12, y: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 80)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func shiftMonth(_ delta: Int) {
        let cal = Calendar.current
        if let next = cal.date(byAdding: .month, value: delta, to: currentDate) {
            // Never navigate into the future — clamp to the current month
            let clamped = next > Date() ? Date() : next
            withAnimation(.spring(response: 0.35)) {
                currentDate = clamped
            }
        }
    }

    private func shortMonth(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: l10n.language == .hebrew ? "he_IL" : "en_US")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date)
    }

    private func dayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return l10n.language == .hebrew ? "היום" : "Today"
        } else if cal.isDateInYesterday(date) {
            return l10n.language == .hebrew ? "אתמול" : "Yesterday"
        } else {
            let f = DateFormatter()
            f.locale = Locale(identifier: l10n.language == .hebrew ? "he_IL" : "en_US")
            f.setLocalizedDateFormatFromTemplate("EdMMM")
            return f.string(from: date)
        }
    }

    private func delete(_ tx: Transaction) {
        let snap = DeletedSnapshot(
            amount: tx.amount,
            currency: tx.currency,
            merchant: tx.merchant,
            category: tx.category,
            timestamp: tx.timestamp,
            note: tx.note,
            buildingId: tx.buildingId,
            isManual: tx.isManual,
            isConfirmed: tx.isConfirmed,
            confidenceScore: tx.confidenceScore,
            originalAmount: tx.originalAmount,
            originalCurrency: tx.originalCurrency,
            exchangeRate: tx.exchangeRate,
            savingsGoalId: tx.savingsGoalId
        )
        lastDeleted = snap
        let token = UUID()
        undoToken = token

        withAnimation {
            modelContext.delete(tx)
            try? modelContext.save()
            if snap.savingsGoalId != nil {
                SavingsGoalService.reconcileAll(context: modelContext)
            }
        }
        Haptics.impact(.medium)

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if undoToken == token {
                withAnimation { lastDeleted = nil }
            }
        }
    }

    private func undoDelete() {
        guard let snap = lastDeleted else { return }
        let restored = Transaction(
            amount: snap.amount,
            currency: snap.currency,
            merchant: snap.merchant,
            category: snap.category,
            timestamp: snap.timestamp,
            confidenceScore: snap.confidenceScore,
            isManual: snap.isManual,
            isConfirmed: snap.isConfirmed,
            note: snap.note,
            buildingId: snap.buildingId,
            originalAmount: snap.originalAmount,
            originalCurrency: snap.originalCurrency,
            exchangeRate: snap.exchangeRate
        )
        // Restore the goal link too, or reconciliation will deduct this deposit from the goal.
        restored.savingsGoalId = snap.savingsGoalId
        withAnimation {
            modelContext.insert(restored)
            try? modelContext.save()
            if restored.savingsGoalId != nil {
                SavingsGoalService.reconcileAll(context: modelContext)
            }
            lastDeleted = nil
        }
        Haptics.notify(.success)
    }


}
