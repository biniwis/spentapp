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

    private var monthTransactions: [Transaction] {
        let cal = Calendar.current
        return allTransactions.filter {
            cal.isDate($0.timestamp, equalTo: currentDate, toGranularity: .month)
        }
    }

    private var displayTransactions: [Transaction] {
        monthTransactions
    }

    private var unconfirmedCount: Int {
        displayTransactions.filter { !$0.isConfirmed }.count
    }

    private var filtered: [Transaction] {
        displayTransactions.filter { tx in
            if showOnlyUnconfirmed && tx.isConfirmed { return false }
            let catMatch = selectedCategory == nil || tx.category == selectedCategory
            let searchMatch = searchText.isEmpty
                || tx.merchant.localizedCaseInsensitiveContains(searchText)
                || tx.category.displayName.localizedCaseInsensitiveContains(searchText)
                || (tx.note ?? "").localizedCaseInsensitiveContains(searchText)
            return catMatch && searchMatch
        }
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
                // ── Header Section ──
                VStack(spacing: 12) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(l10n.language == .hebrew ? "היסטוריה" : "History")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            Text(l10n.language == .hebrew ? "\(filtered.count) עסקאות • \(l10n.format(amount: totalFiltered))" : "\(filtered.count) transactions • \(l10n.format(amount: totalFiltered))")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(Color.textMuted)
                        }
                        Spacer()

                        // Month Navigator Capsule
                        HStack(spacing: 0) {
                            Button(action: { shiftMonth(-1) }) {
                                Text(verbatim: l10n.language == .hebrew ? "›" : "‹")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.deepNavy)
                                    .frame(width: 32, height: 32)
                            }
                            Text(shortMonth(currentDate))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                                .frame(minWidth: 70)
                            Button(action: { shiftMonth(1) }) {
                                Text(verbatim: l10n.language == .hebrew ? "‹" : "›")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(
                                        Calendar.current.isDate(currentDate, equalTo: Date(), toGranularity: .month)
                                        ? Color.borderSubtle : Color.deepNavy
                                    )
                                    .frame(width: 32, height: 32)
                            }
                            .disabled(Calendar.current.isDate(currentDate, equalTo: Date(), toGranularity: .month))
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.cardBackground)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.borderSubtle, lineWidth: 1.2))
                        .shadow(color: Color.deepNavy.opacity(0.04), radius: 6, y: 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Search Bar Pill
                    HStack(spacing: 10) {
                        SearchLensVectorIcon(color: Color.textMuted)
                        TextField(l10n.language == .hebrew ? "חפש עסקה..." : "Search transaction...", text: $searchText)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.textMuted)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .cityCard(.plain, radius: MoneyCityTheme.radiusCard)
                    .padding(.horizontal, 16)

                    // Category Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if unconfirmedCount > 0 {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        showOnlyUnconfirmed.toggle()
                                        if showOnlyUnconfirmed { selectedCategory = nil }
                                    }
                                }) {
                                    HStack(spacing: 5) {
                                        Circle()
                                            .fill(showOnlyUnconfirmed ? .white : Color.themeYellow)
                                            .frame(width: 7, height: 7)
                                        Text(l10n.language == .hebrew ? "לאישור (\(unconfirmedCount))" : "Review (\(unconfirmedCount))")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                    }
                                    .foregroundColor(showOnlyUnconfirmed ? .white : Color.themeYellow)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(showOnlyUnconfirmed ? Color.themeYellow : Color.cardBackground)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.themeYellow.opacity(0.4), lineWidth: 1.2))
                                }
                                .buttonStyle(.plain)
                                .bouncyPress(scale: 0.92)
                            }

                            allFilterChip
                            ForEach(SpendingCategory.primaryCategories, id: \.self) { cat in
                                categoryFilterChip(cat)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    }
                }
                .background(Color.appBackground)

                // ── Transaction List ──
                if filtered.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        DistrictSkylineVectorIcon(color: Color.borderSubtle)
                            .frame(width: 44, height: 44)
                            .scaleEffect(1.6)
                        Text(l10n.language == .hebrew ? "אין עסקאות להצגה" : "No Transactions Found")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                        Text(l10n.language == .hebrew ? "נסה קטגוריה אחרת או מילת חיפוש שונה" : "Try another category or search keyword")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(Color.textMuted)
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 14, pinnedViews: []) {
                            ForEach(groupedByDay, id: \.date) { group in
                                daySection(group.date, txs: group.txs)
                            }
                            Spacer(minLength: 110)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    }
                }
            }

            // Undo Banner
            VStack {
                Spacer()
                undoBanner
            }
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
    }

    private struct IdentifiableMerchant: Identifiable {
        var id: String { name }
        let name: String
    }

    // MARK: - Filter Chips

    private var allFilterChip: some View {
        let isSelected = selectedCategory == nil && !showOnlyUnconfirmed
        return Button(action: {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedCategory = nil
                showOnlyUnconfirmed = false
            }
        }) {
            HStack(spacing: 5) {
                DistrictSkylineVectorIcon(color: isSelected ? .white : Color.primaryBlue)
                    .frame(width: 14, height: 14)
                    .scaleEffect(0.65)
                Text(l10n.language == .hebrew ? "הכל" : "All")
                    .font(.system(size: 12, weight: isSelected ? .bold : .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : Color.deepNavy)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(isSelected ? Color.primaryBlue : Color.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.clear : Color.borderSubtle, lineWidth: 1.2))
            .shadow(color: isSelected ? Color.primaryBlue.opacity(0.3) : Color.deepNavy.opacity(0.02), radius: 4, y: 2)
            .contentShape(Capsule())
        }
        .bouncyPress(scale: 0.92)
    }

    private func categoryFilterChip(_ cat: SpendingCategory) -> some View {
        let isSelected = selectedCategory == cat
        return Button(action: {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedCategory = isSelected ? nil : cat
                showOnlyUnconfirmed = false
            }
        }) {
            HStack(spacing: 6) {
                CategoryVectorIcon(category: cat, color: isSelected ? .white : cat.themeColor, size: 14)
                Text(cat.displayName)
                    .font(.system(size: 12, weight: isSelected ? .bold : .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : Color.deepNavy)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(isSelected ? Color.primaryBlue : Color.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.clear : Color.borderSubtle, lineWidth: 1.2))
            .shadow(color: isSelected ? Color.primaryBlue.opacity(0.3) : Color.deepNavy.opacity(0.02), radius: 4, y: 2)
            .contentShape(Capsule())
        }
        .bouncyPress(scale: 0.92)
    }

    // MARK: - Day Section

    private func daySection(_ date: Date, txs: [Transaction]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Day Header Row
            HStack {
                Text(dayLabel(date))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textSecondary)
                Spacer()
                Text(l10n.format(amount: txs.reduce(0) { $0 + $1.amount }))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
            }
            .padding(.horizontal, 4)

            // Transactions Card
            VStack(spacing: 0) {
                ForEach(Array(txs.enumerated()), id: \.element.id) { idx, tx in
                    txRow(tx)
                    if idx < txs.count - 1 {
                        Divider().background(Color.borderSubtle).padding(.leading, 64)
                    }
                }
            }
            .cityCard(.plain, radius: MoneyCityTheme.radiusCard)
        }
    }

    private func txRow(_ tx: Transaction) -> some View {
        HStack(spacing: 12) {
            // Chunky Circular / Rounded Icon with Soft Pastel Background & Vector Art
            CategoryBadge(category: tx.category, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(tx.merchant)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(tx.timeString)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textMuted)
                    Text("•")
                        .foregroundColor(Color.borderSubtle)
                        .font(.system(size: 9, design: .rounded))
                    Text(tx.category.displayName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(tx.category.themeColor)

                    let isRefund = tx.note?.contains("זיכוי") == true || tx.amount < 0
                    if isRefund {
                        Text(l10n.language == .hebrew ? "• ↩️ זיכוי" : "• ↩️ Refund")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Color.themeMint)
                    } else if !tx.isConfirmed {
                        Text(l10n.language == .hebrew ? "• סיווג לא ודאי" : "• unverified")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Color.themeYellow)
                    }
                }
            }

            Spacer()

            let isRefund = tx.note?.contains("זיכוי") == true || tx.amount < 0
            if isRefund {
                Text("-\(l10n.format(amount: abs(tx.amount)))")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(Color.themeMint)
            } else {
                Text(l10n.format(amount: tx.amount))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            editingTx = tx
        }
        .contextMenu {
            Button {
                editingTx = tx
            } label: {
                Text(l10n.language == .hebrew ? "ערוך עסקה" : "Edit Transaction")
            }
            Button {
                selectedMerchantForDetails = tx.merchant
            } label: {
                Text(l10n.language == .hebrew ? "פרטי בית עסק (\(tx.merchant))" : "Merchant Details (\(tx.merchant))")
            }
            if !tx.isConfirmed {
                Button {
                    DatabaseService.shared.rememberCorrection(merchant: tx.merchant, category: tx.category)
                    tx.isConfirmed = true
                    tx.confidenceScore = 1.0
                    try? modelContext.save()
                    Haptics.impact(.light)
                } label: {
                    Label(l10n.language == .hebrew ? "אשר את הסיווג" : "Confirm category", systemImage: "checkmark")
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

    private var undoBanner: some View {
        Group {
            if let snap = lastDeleted {
                HStack(spacing: 12) {
                    TrashVectorIcon(color: Color.themePink)
                    Text(l10n.language == .hebrew ? "נמחקה: \(snap.merchant)" : "Deleted: \(snap.merchant)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: undoDelete) {
                        Text(l10n.language == .hebrew ? "בטל" : "Undo")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color.themeMint)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .cityCard(.night, radius: MoneyCityTheme.radiusCard)
                .padding(.horizontal, 16)
                .padding(.bottom, 80)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func shiftMonth(_ delta: Int) {
        let cal = Calendar.current
        if let next = cal.date(byAdding: .month, value: delta, to: currentDate) {
            withAnimation(.spring(response: 0.35)) {
                currentDate = next
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
            f.dateFormat = "E, d MMM"
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
            lastDeleted = nil
        }
        Haptics.notify(.success)
    }
}
