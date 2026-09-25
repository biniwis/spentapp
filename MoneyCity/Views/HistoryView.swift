import SwiftUI
import SwiftData

public struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager
    @Query(sort: \Transaction.timestamp, order: .reverse) private var personalTransactions: [Transaction]
    @Query(sort: \ScheduledExpense.scheduledFor, order: .forward) private var allScheduledExpenses: [ScheduledExpense]

    #if !SWIFT_PACKAGE
    @ObservedObject private var scope = AppScopeContext.shared
    @State private var editingShared: SharedExpense?
    #endif

    private var allTransactions: [ExpenseSnapshot] {
        #if !SWIFT_PACKAGE
        return scope.allExpenses(personalTransactions: personalTransactions)
        #else
        return personalTransactions.map(ExpenseSnapshot.init)
        #endif
    }
    private var scopeCalendar: Calendar {
        #if !SWIFT_PACKAGE
        return scope.calendar
        #else
        return .current
        #endif
    }
    private var isShared: Bool {
        #if !SWIFT_PACKAGE
        return scope.activeScope.isShared
        #else
        return false
        #endif
    }

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
    @State private var showConversionError: Bool = false

    @State private var isSearchExpanded: Bool = false
    @State private var isUpcomingExpanded: Bool = false
    @State private var showCalendarPicker: Bool = false
    @State private var calendarPickerDate: Date = Date()
    @State private var selectedSpecificDate: Date? = nil
    @FocusState private var isSearchFocused: Bool

    private var monthTransactions: [ExpenseSnapshot] {
        let cal = scopeCalendar
        return allTransactions.filter {
            cal.isDate($0.timestamp, equalTo: currentDate, toGranularity: .month)
        }
    }

    private var displayTransactions: [ExpenseSnapshot] {
        if let specific = selectedSpecificDate {
            let cal = scopeCalendar
            return allTransactions.filter {
                cal.isDate($0.timestamp, inSameDayAs: specific)
            }
        }
        return monthTransactions
    }

    private var unconfirmedCount: Int {
        displayTransactions.filter { !$0.isConfirmed }.count
    }

    private var filtered: [ExpenseSnapshot] {
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

    private var isCurrentMonth: Bool {
        scopeCalendar.isDate(currentDate, equalTo: Date(), toGranularity: .month)
    }

    private var upcomingExpenses: [ScheduledExpense] {
        allScheduledExpenses.filter { $0.materializedAt == nil }
    }

    private var showUpcomingSection: Bool {
        !isShared && isCurrentMonth && selectedSpecificDate == nil && !upcomingExpenses.isEmpty && !hasActiveFilters
    }

    private var groupedByDay: [(date: Date, txs: [ExpenseSnapshot])] {
        let cal = scopeCalendar
        var groups: [Date: [ExpenseSnapshot]] = [:]
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
                if filtered.isEmpty && !showUpcomingSection {
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
                            upcomingSection
                            ForEach(groupedByDay, id: \.date) { group in
                                daySection(group.date, txs: group.txs)
                            }
                            Spacer(minLength: 110)
                        }
                        .padding(.top, 8)
                    }
                    .scrollDismissesKeyboard(.interactively)
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
            if isShared {
                TransactionFeedSheet(title: item.name, expenses: allTransactions.filter { displayMerchantTitle(for: $0) == item.name })
                    .environmentObject(l10n)
            } else {
                MerchantDetailSheet(merchantName: item.name)
                    .presentationDetents([.medium, .large])
                    .environmentObject(l10n)
            }
        }
        #if !SWIFT_PACKAGE
        .sheet(item: $editingShared) { expense in
            if let space = scope.currentSpace {
                SharedExpenseEditor(space: space, expense: expense).environmentObject(l10n)
            }
        }
        #endif
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
                .frame(minWidth: 36, minHeight: 36)
                .contentShape(Rectangle())
            }

            Button(action: {
                Haptics.selection()
                calendarPickerDate = currentDate
                showCalendarPicker = true
            }) {
                Text(shortMonth(currentDate))
                    .font(.system(size: 13.5, weight: .semibold, design: .default))
                    .foregroundColor(Color.deepNavy)
                    .frame(minHeight: 36)
                    .contentShape(Rectangle())
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
                .frame(minWidth: 36, minHeight: 36)
                .contentShape(Rectangle())
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
                if !isSearchExpanded {
                    searchText = ""
                    isSearchFocused = false
                } else {
                    isSearchFocused = true
                }
            }
        }) {
            MoneyIcon(.search, size: 20)
                .frame(width: 38, height: 38)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
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
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            MoneyIcon(.search, size: 16)
            TextField(l10n.language == .hebrew ? "חפש עסקה או קטגוריה..." : "Search transaction or category...", text: $searchText)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(Color.deepNavy)
                .focused($isSearchFocused)
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

    // MARK: - Upcoming Section (One-time Scheduled Expenses)

    @ViewBuilder
    private var upcomingSection: some View {
        if showUpcomingSection {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        isUpcomingExpanded.toggle()
                    }
                    Haptics.impact(.light)
                } label: {
                    HStack(alignment: .center, spacing: 8) {
                        Text(l10n.language == .hebrew ? "הוצאות מתוכננות" : "Upcoming")
                            .font(.system(size: 15.5, weight: .bold, design: .default))
                            .foregroundColor(Color.deepNavy)
                        
                        Text("\(upcomingExpenses.count)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color.accentOrange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentOrange.opacity(0.12))
                            .clipShape(Capsule())

                        Spacer()

                        Image(systemName: isUpcomingExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.deepNavy.opacity(0.45))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)

                if isUpcomingExpanded {
                    VStack(spacing: 12) {
                        ForEach(upcomingExpenses) { expense in
                            SwipeActionRow(
                                id: expense.id,
                                openSwipeRowID: $openSwipeRowID,
                                onEdit: nil,
                                onDelete: {
                                    deleteScheduledExpense(expense)
                                }
                            ) {
                                scheduledRow(expense)
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func deleteScheduledExpense(_ expense: ScheduledExpense) {
        withAnimation {
            modelContext.delete(expense)
        }
        _ = DatabaseService.safeSave(modelContext)
        Haptics.notify(.success)
    }

    private func scheduledRow(_ expense: ScheduledExpense) -> some View {
        HStack(alignment: .top, spacing: 12) {
            CategoryBadge(category: expense.category, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.merchant.isEmpty ? expense.category.displayName : expense.merchant)
                    .font(.system(size: 15.5, weight: .semibold, design: .default))
                    .foregroundColor(Color.deepNavy)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(expense.category.displayName)
                        .font(.system(size: 12.5, weight: .regular, design: .default))
                        .foregroundColor(Color(red: 148/255, green: 163/255, blue: 184/255))

                    Text("• \(formattedScheduledDate(expense.scheduledFor))")
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundColor(Color.accentOrange)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(l10n.formatScoped(amount: expense.amount, showDecimals: true))
                    .font(.system(size: 16.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                Text(l10n.language == .hebrew ? "מתוכנן" : "Scheduled")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func formattedScheduledDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: l10n.language == .hebrew ? "he_IL" : "en_US")
        formatter.dateFormat = l10n.language == .hebrew ? "d בMMMM" : "MMM d"
        return formatter.string(from: date)
    }

    // MARK: - Day Section (Direct on Background, Editorial Ledger)

    private func daySection(_ date: Date, txs: [ExpenseSnapshot]) -> some View {
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
                    Text(l10n.formatScoped(amount: txs.reduce(0) { $0 + $1.amount }, showDecimals: true))
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
                            edit(tx)
                        },
                        onDelete: {
                            delete(tx)
                        }
                    ) {
                        txRow(tx)
                    }
                }
            }
            .alert(
                l10n.language == .hebrew ? "לא ניתן להמיר עכשיו" : "Can't convert yet",
                isPresented: $showConversionError
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(l10n.language == .hebrew
                     ? "שער ההמרה של המטבע הזה עדיין לא זמין. העסקה לא שונתה."
                     : "There's no exchange rate for this currency yet. The transaction was not changed.")
            }
        }
    }

    private func txRow(_ tx: ExpenseSnapshot) -> some View {
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

                    #if !SWIFT_PACKAGE
                    if let payer = scope.participants.first(where: { $0.id == tx.paidBy }) {
                        HStack(spacing: 4) {
                            SharedMemberMark(colorHex: payer.colorHex, size: 18)
                            Text(payer.name)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(MoneyCityTheme.textSecondary)
                                .lineLimit(1)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel((l10n.isHebrew ? "שילם/ה: " : "Paid by: ") + payer.name)
                    }
                    #endif
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
            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 12) {
                    Text(tx.timeString)
                        .font(.system(size: 12.5, weight: .regular, design: .default))
                        .foregroundColor(Color(red: 148/255, green: 163/255, blue: 184/255))

                    let isRefund = tx.note?.contains("זיכוי") == true || tx.amount < 0
                    if tx.isUnresolvedForeign {
                        Text("\(tx.currency) \(String(format: "%.2f", abs(tx.amount)))")
                            .font(.system(size: 15.5, weight: .bold, design: .rounded))
                            .foregroundColor(Color.orange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    } else if isRefund {
                        Text("+\(l10n.formatScoped(amount: abs(tx.amount), showDecimals: true))")
                            .font(.system(size: 15.5, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    } else {
                        Text(l10n.formatScoped(amount: tx.amount, showDecimals: true))
                            .font(.system(size: 15.5, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                if let orig = tx.displayOriginalText {
                    Text("\(orig) \(l10n.language == .hebrew ? "במקור" : "originally")")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 148/255, green: 163/255, blue: 184/255))
                }
            }
            .layoutPriority(1)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                edit(tx)
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
                    guard !isShared, let original = personalTransactions.first(where: { $0.id == tx.id }) else { return }
                    DatabaseService.shared.rememberCorrection(merchant: tx.merchant, category: tx.category)
                    original.isConfirmed = true
                    original.confidenceScore = 1.0
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
            if tx.isUnresolvedForeign {
                Button {
                    if let original = personalTransactions.first(where: { $0.id == tx.id }), !isShared { convertNow(original) }
                } label: {
                    Label {
                        Text(l10n.language == .hebrew ? "המר עכשיו" : "Convert now")
                    } icon: {
                        MoneyIcon(.exchange, size: 18)
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
    private func displayMerchantTitle(for tx: ExpenseSnapshot) -> String {
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
        let cal = scopeCalendar
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
        f.calendar = scopeCalendar
        f.timeZone = scopeCalendar.timeZone
        f.locale = Locale(identifier: l10n.language == .hebrew ? "he_IL" : "en_US")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date)
    }

    private func dayLabel(_ date: Date) -> String {
        let cal = scopeCalendar
        if cal.isDateInToday(date) {
            return l10n.language == .hebrew ? "היום" : "Today"
        } else if cal.isDateInYesterday(date) {
            return l10n.language == .hebrew ? "אתמול" : "Yesterday"
        } else {
            let f = DateFormatter()
        f.calendar = scopeCalendar
        f.timeZone = scopeCalendar.timeZone
            f.locale = Locale(identifier: l10n.language == .hebrew ? "he_IL" : "en_US")
            f.setLocalizedDateFormatFromTemplate("EdMMM")
            return f.string(from: date)
        }
    }

    /// Converts an unresolved foreign transaction on demand. A successful conversion is
    /// persisted immediately; a missing rate leaves the row untouched and tells the user.
    private func convertNow(_ tx: Transaction) {
        switch CurrencyResolutionService.resolveStoredForeignTransactionIfPossible(tx, context: modelContext) {
        case .resolved:
            Haptics.notify(.success)
        case .rateUnavailable, .saveFailed:
            showConversionError = true
            Haptics.notify(.warning)
        case .notForeign:
            break
        }
    }

    private func edit(_ tx: ExpenseSnapshot) {
        #if !SWIFT_PACKAGE
        if let spaceID = scope.activeScope.spaceID {
            editingShared = SharedWorkspaceStore.shared.expenses.first { $0.id == tx.id && $0.spaceID == spaceID }
            return
        }
        #endif
        editingTx = personalTransactions.first { $0.id == tx.id }
    }

    private func delete(_ tx: ExpenseSnapshot) {
        #if !SWIFT_PACKAGE
        if let spaceID = scope.activeScope.spaceID {
            let store = SharedWorkspaceStore.shared
            guard let expense = store.expenses.first(where: { $0.id == tx.id && $0.spaceID == spaceID }) else { return }
            do { try store.deleteExpense(expense) }
            catch { store.errorMessage = error.localizedDescription }
            return
        }
        #endif
        guard let original = personalTransactions.first(where: { $0.id == tx.id }) else { return }
        delete(original)
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
