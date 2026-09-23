#if !SWIFT_PACKAGE
import SwiftUI
import CloudKit
import Charts

private extension Color {
    init(sharedHex: String) {
        let value = UInt32(sharedHex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0x5653E8
        self.init(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
}

struct SharedScopePicker: View {
    @ObservedObject private var store = SharedWorkspaceStore.shared
    var body: some View {
        Menu {
            Button(store.text("העיר שלי", "My city")) { store.select(nil) }
            ForEach(store.spaces) { space in
                Button { store.select(space.id) } label: {
                    Label(space.name, systemImage: store.activeSpaceID == space.id ? "checkmark" : "person.2")
                }
            }
            Divider()
            Button(store.text("ניהול מרחבים", "Manage spaces")) { store.showSetup = true }
        } label: {
            HStack(spacing: 8) {
                if store.activeSpaceID != nil { Image(systemName: "person.2.fill") }
                Text(store.activeSpace?.name ?? store.text("העיר שלי", "My city")).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption)
            }
            .font(.subheadline.weight(.semibold)).foregroundStyle(MoneyCityTheme.textPrimary)
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .accessibilityLabel(store.text("בחירת מרחב", "Choose space"))
    }
}

struct SharedWorkspaceView: View {
    let space: SharedSpace
    @Binding var activeTab: String
    @ObservedObject private var store = SharedWorkspaceStore.shared
    @EnvironmentObject private var l10n: LocalizationManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var month = Date()
    @State private var adding = false
    @State private var editing: SharedExpense?
    @State private var inspecting: DistrictBuildingInfo?
    @State private var query = ""
    @State private var payerFilter = ""
    @State private var categoryFilter = ""
    @State private var deletion: SharedExpense?

    private var participants: [SharedMember] { store.members.filter { $0.spaceID == space.id } }
    private var monthExpenses: [SharedExpense] {
        guard let interval = space.calendar.dateInterval(of: .month, for: month) else { return [] }
        return store.expenses.filter { $0.spaceID == space.id && $0.currencyCode == space.currencyCode && interval.contains($0.date) }
    }
    private var filtered: [SharedExpense] {
        monthExpenses.filter {
            (query.isEmpty || $0.merchant.localizedCaseInsensitiveContains(query) || $0.note.localizedCaseInsensitiveContains(query)) &&
            (payerFilter.isEmpty || $0.paidBy == payerFilter) &&
            (categoryFilter.isEmpty || $0.category.canonical.rawValue == categoryFilter)
        }
    }
    private var total: Double { monthExpenses.reduce(0) { $0 + $1.amount } }
    private func money(_ amount: Double) -> String { l10n.format(amount: amount, currency: CurrencyType(rawValue: space.currencyCode)) }
    private var monthTitle: String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: l10n.language.rawValue)
        formatter.timeZone = space.calendar.timeZone; formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: month)
    }
    private var city: MonthlyCity {
        var city = CitySimulationEngine.shared.generateCity(for: month, expenses: monthExpenses.map(ExpenseSnapshot.init), calendar: space.calendar)
        city.parkHealth = CitySimulationEngine.healthyParkLevel
        city.venueStates = city.venueStates.map { venue in
            var result = venue
            let values = participants.map { member in
                (member, max(0, monthExpenses.filter { $0.buildingID == venue.id && $0.paidBy == member.id }.reduce(0) { $0 + $1.amount }))
            }
            let sum = values.reduce(0) { $0 + $1.1 }
            result.memberShares = values.compactMap { member, value in
                guard sum > 0, value > 0 else { return nil }
                return CityMemberShare(memberID: member.id, color: member.colorHex, share: value / sum)
            }
            return result
        }
        return city
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SharedScopePicker()
                Spacer()
                if store.demo { Text(store.text("הדגמה", "Demo")).font(.caption).foregroundStyle(MoneyCityTheme.accentWarm) }
                Button { store.perform { try await store.sync() } } label: {
                    Image(systemName: "arrow.triangle.2.circlepath").padding(12)
                }.disabled(store.busy || store.demo).accessibilityLabel(store.text("סנכרון", "Sync"))
            }
            if store.pendingCount > 0 {
                Text(store.text("\(store.pendingCount) שינויים ממתינים לסנכרון", "\(store.pendingCount) changes waiting to sync"))
                    .font(.caption).foregroundStyle(.secondary).padding(.bottom, 6)
            }
            if !store.canWrite(space.id) {
                Text(store.text("קריאה בלבד · יש להתחבר ולרענן כדי לבדוק הרשאות", "Read only · Connect and refresh to check access"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if activeTab != "profile" { monthControl }
            Group {
                switch activeTab {
                case "history": history
                case "analytics": analytics
                case "profile": SharedSpaceManagement(space: space)
                default: cityView
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                tab("city", "building.2", store.text("עיר", "City"))
                tab("history", "list.bullet", store.text("היסטוריה", "History"))
                Button { adding = true } label: {
                    Image(systemName: "plus").font(.title2.weight(.semibold)).foregroundStyle(.white)
                        .frame(width: 50, height: 50).background(MoneyCityTheme.brandPrimary, in: Circle())
                }.disabled(!store.canWrite(space.id)).accessibilityLabel(store.text("הוצאה משותפת חדשה", "New shared expense"))
                tab("analytics", "chart.bar", store.text("ניתוח", "Analytics"))
                tab("profile", "person.crop.circle", store.text("ניהול", "Manage"))
            }.padding(.horizontal, 12).padding(.vertical, 8).background(MoneyCityTheme.appBackground)
        }
        .background(MoneyCityTheme.appBackground)
        .sheet(isPresented: $adding) { SharedExpenseEditor(space: space) }
        .sheet(item: $editing) { SharedExpenseEditor(space: space, expense: $0) }
        .sheet(item: $inspecting) { building in
            NavigationStack {
                List {
                    Text(money(monthExpenses.filter { $0.buildingID == building.id }.reduce(0) { $0 + $1.amount }))
                        .font(.largeTitle.bold())
                    contributions(monthExpenses.filter { $0.buildingID == building.id })
                    ForEach(monthExpenses.filter { $0.buildingID == building.id }) { expenseRow($0) }
                }.navigationTitle(building.id.replacingOccurrences(of: "_", with: " "))
                    .toolbar { Button(store.text("סיום", "Done")) { inspecting = nil } }
            }
        }
        .confirmationDialog(store.text("למחוק את ההוצאה מהמרחב?", "Delete this shared expense?"), isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } })) {
            Button(store.text("מחיקה", "Delete"), role: .destructive) {
                if let expense = deletion { store.perform { try store.deleteExpense(expense) } }
                deletion = nil
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !store.demo { store.perform { try await store.refresh() } }
        }
    }
    private var monthControl: some View {
        HStack {
            Button { moveMonth(-1) } label: { Image(systemName: "chevron.backward").padding(12) }
                .accessibilityLabel(store.text("חודש קודם", "Previous month"))
            Spacer(); Text(monthTitle).font(.headline); Spacer()
            Button { moveMonth(1) } label: { Image(systemName: "chevron.forward").padding(12) }
                .disabled(space.calendar.isDate(month, equalTo: Date(), toGranularity: .month))
                .accessibilityLabel(store.text("חודש הבא", "Next month"))
        }.padding(.horizontal, 12)
    }
    private func moveMonth(_ amount: Int) {
        if let next = space.calendar.date(byAdding: .month, value: amount, to: month) { month = next }
    }
    private func tab(_ id: String, _ icon: String, _ title: String) -> some View {
        Button { activeTab = id } label: {
            VStack(spacing: 4) { Image(systemName: icon).font(.title3); Text(title).font(.caption2) }
                .frame(maxWidth: .infinity).foregroundStyle(activeTab == id ? MoneyCityTheme.brandSecondary : MoneyCityTheme.textSecondary)
        }.accessibilityAddTraits(activeTab == id ? .isSelected : [])
    }
    private var cityView: some View {
        let value = city
        return VStack(spacing: 6) {
            Text(money(total)).font(.system(size: 36, weight: .bold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
            Text(store.text("ההוצאות שלנו החודש", "Our expenses this month")).font(.subheadline).foregroundStyle(.secondary)
            HStack {
                ForEach(participants) { member in
                    VStack(spacing: 4) {
                        memberLabel(member)
                        Text(money(monthExpenses.filter { $0.paidBy == member.id }.reduce(0) { $0 + $1.amount })).font(.caption.bold())
                    }.frame(maxWidth: .infinity)
                }
            }.padding(.horizontal)
            DioramaReadyWrapper(mapStyle: CityMapStyle(rawValue: space.mapStyle) ?? .urban,
                totalSpent: value.totalSpent, totalSavings: 0, parkHealth: CitySimulationEngine.healthyParkLevel,
                categoryTotals: value.categoryTotals, buildingTotals: value.buildingTotals,
                districtStates: value.districtStates, venueStates: value.venueStates, habits: value.habits,
                enrichmentIds: [], newlyUnlockedEnrichmentId: nil, slotPlacements: [:], selectedDistrict: nil,
                language: l10n.language == .hebrew ? "he" : "en", isPaused: scenePhase != .active,
                onSelectDistrict: { _ in }, onBuildingSelected: { inspecting = $0 })
                .id(space.id.uuidString + space.mapStyle)
            if monthExpenses.isEmpty {
                Text(store.text("הוסיפו הוצאה ראשונה ובנו את העיר שלכם יחד", "Add your first expense to grow your city together"))
                    .font(.subheadline).foregroundStyle(.secondary).padding()
            }
        }
    }
    private var history: some View {
        VStack {
            TextField(store.text("חיפוש עסק או הערה", "Search merchant or note"), text: $query)
                .textFieldStyle(.roundedBorder).padding(.horizontal)
            HStack {
                Picker(store.text("משלם", "Payer"), selection: $payerFilter) {
                    Text(store.text("כולם", "Everyone")).tag("")
                    ForEach(participants) { Text($0.name).tag($0.id) }
                }
                Picker(store.text("קטגוריה", "Category"), selection: $categoryFilter) {
                    Text(store.text("כל הקטגוריות", "All categories")).tag("")
                    ForEach(SpendingCategory.primaryCategories.filter { $0 != .savings }) { Text($0.displayName).tag($0.rawValue) }
                }
            }
            List {
                if filtered.isEmpty { Text(store.text("אין הוצאות להצגה", "No expenses to show")).foregroundStyle(.secondary) }
                ForEach(filtered) { expenseRow($0) }
            }.listStyle(.plain)
        }
    }
    private func expenseRow(_ expense: SharedExpense) -> some View {
        Button { editing = expense } label: {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(expense.merchant).font(.body.weight(.semibold)).foregroundStyle(MoneyCityTheme.textPrimary)
                    if let member = participants.first(where: { $0.id == expense.paidBy }) { memberLabel(member) }
                    Text(expense.date, style: .date).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text(money(expense.amount)).font(.system(.body, design: .rounded).weight(.bold)).foregroundStyle(MoneyCityTheme.textPrimary)
            }.padding(.vertical, 6)
        }
        .disabled(!store.canWrite(space.id))
        .swipeActions {
            if store.canWrite(space.id) { Button(role: .destructive) { deletion = expense } label: { Label(store.text("מחיקה", "Delete"), systemImage: "trash") } }
        }
    }
    private func memberLabel(_ member: SharedMember) -> some View {
        HStack(spacing: 5) {
            Circle().fill(Color(sharedHex: member.colorHex)).frame(width: 9, height: 9)
            Text(member.name).font(.caption)
        }.accessibilityElement(children: .combine)
    }
    private func contributions(_ values: [SharedExpense]) -> some View {
        ForEach(participants) { member in
            HStack { memberLabel(member); Spacer(); Text(money(values.filter { $0.paidBy == member.id }.reduce(0) { $0 + $1.amount })) }
        }
    }
    private var analytics: some View {
        List {
            Section(store.text("סה״כ החודש", "Monthly total")) {
                Text(money(total)).font(.system(size: 34, weight: .bold, design: .rounded))
            }
            Section(store.text("מי שילם", "Who paid")) { contributions(monthExpenses) }
            Section(store.text("קטגוריות", "Categories")) {
                ForEach(SpendingCategory.primaryCategories.filter { $0 != .savings }) { category in
                    let values = monthExpenses.filter { $0.category.canonical == category }
                    if !values.isEmpty {
                        DisclosureGroup {
                            contributions(values)
                        } label: {
                            HStack { Text(category.displayName); Spacer(); Text(money(values.reduce(0) { $0 + $1.amount })) }
                        }
                    }
                }
            }
            Section(store.text("ששת החודשים האחרונים", "Last six months")) {
                Chart {
                    ForEach(0..<6, id: \.self) { offset in
                        if let date = space.calendar.date(byAdding: .month, value: -offset, to: month),
                           let interval = space.calendar.dateInterval(of: .month, for: date) {
                            let amount = store.expenses.filter { $0.spaceID == space.id && $0.currencyCode == space.currencyCode && interval.contains($0.date) }.reduce(0) { $0 + $1.amount }
                            BarMark(x: .value("Month", date, unit: .month), y: .value(space.currencyCode, amount))
                                .foregroundStyle(MoneyCityTheme.brandSecondary)
                        }
                    }
                }.frame(height: 180)
            }
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden)
    }
}

struct SharedExpenseEditor: View {
    let space: SharedSpace
    var expense: SharedExpense?
    @ObservedObject private var store = SharedWorkspaceStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var merchant = ""
    @State private var note = ""
    @State private var category: SpendingCategory = .food
    @State private var building = ""
    @State private var payer = ""
    @State private var date = Date()
    @State private var currency = "ILS"
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(store.text("יעד", "Destination")) {
                    Label(space.name, systemImage: "person.2.fill")
                    Text(store.text("ההוצאה תישמר במרחב הזה", "This expense will be saved to this space")).font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    TextField(store.text("סכום · מינוס לזיכוי", "Amount · negative for refund"), text: $amount)
                        .keyboardType(.numbersAndPunctuation)
                    Picker(store.text("מטבע", "Currency"), selection: $currency) {
                        ForEach(Array(Set([space.currencyCode, "ILS", "USD", "EUR", "GBP", "JPY"])).sorted(), id: \.self) { Text($0).tag($0) }
                    }
                    TextField(store.text("שם העסק", "Merchant"), text: $merchant)
                    Picker(store.text("שילם/ה", "Paid by"), selection: $payer) {
                        ForEach(store.members.filter { $0.spaceID == space.id }) { Text($0.name).tag($0.id) }
                    }
                    Picker(store.text("קטגוריה", "Category"), selection: $category) {
                        ForEach(SpendingCategory.primaryCategories.filter { $0 != .savings }) { Text($0.displayName).tag($0) }
                    }
                    DatePicker(store.text("תאריך", "Date"), selection: $date, in: ...Date(), displayedComponents: .date)
                        .environment(\.timeZone, space.calendar.timeZone)
                    TextField(store.text("הערה", "Note"), text: $note, axis: .vertical)
                }
                if currency != space.currencyCode {
                    Text(store.text("הסכום יומר ל־\(space.currencyCode) לפי השער הזמין בעת השמירה.", "Converted to \(space.currencyCode) at the rate available when saved."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let error { Text(error).foregroundStyle(MoneyCityTheme.destructive) }
            }
            .navigationTitle(store.text(expense == nil ? "הוצאה משותפת" : "עריכת הוצאה", expense == nil ? "Shared expense" : "Edit expense"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(store.text("ביטול", "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(store.text("שמירה", "Save"), action: save).disabled(!store.canWrite(space.id)) }
            }
            .onAppear {
                currency = space.currencyCode; payer = store.myMemberID(in: space.id)
                if let expense {
                    amount = NSDecimalNumber(value: expense.amount).stringValue; merchant = expense.merchant
                    note = expense.note; category = expense.category; building = expense.buildingID
                    payer = expense.paidBy; date = expense.date
                }
            }
        }.interactiveDismissDisabled(!amount.isEmpty || !merchant.isEmpty)
    }
    private func save() {
        do {
            let originalMinor = try SharedMoney.minor(amount, currency: currency)
            var baseMinor = originalMinor
            var rate: Double?
            if currency != space.currencyCode {
                guard let value = FXService.convert(amount: 1, from: currency, to: space.currencyCode) else {
                    throw SharedLedgerError.invalidAmount
                }
                rate = value
                let decimal = Decimal(originalMinor) / pow(Decimal(10), SharedMoney.digits(currency)) * Decimal(value)
                baseMinor = try SharedMoney.minor(NSDecimalNumber(decimal: decimal).stringValue, currency: space.currencyCode)
            }
            let resolvedBuilding = building.isEmpty || expense?.category != category
                ? CategorizationEngine.shared.mapToBuildingId(category: category, merchant: merchant) : building
            let updated = SharedExpense(id: expense?.id ?? UUID(), spaceID: space.id, amountMinor: baseMinor,
                currencyCode: space.currencyCode, merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category.canonical, buildingID: resolvedBuilding, date: date, note: note,
                paidBy: payer, createdBy: expense?.createdBy ?? payer, updatedBy: store.myMemberID(in: space.id),
                originalAmount: rate != nil ? amount : expense?.originalAmount,
                originalCurrency: rate != nil ? currency : expense?.originalCurrency,
                exchangeRate: rate.map { String($0) } ?? expense?.exchangeRate,
                exchangeRateDate: rate != nil ? Date() : expense?.exchangeRateDate)
            try store.saveExpense(updated)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct SharedSpacesSetupView: View {
    @ObservedObject private var store = SharedWorkspaceStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var memberName = ""
    @State private var url = ""
    @State private var currency = LocalizationManager.shared.baseCurrency.rawValue
    @State private var style = CityMapStyle.urban
    var body: some View {
        NavigationStack {
            Form {
                if store.busy { ProgressView() }
                Section(store.text("המרחבים שלך", "Your spaces")) {
                    ForEach(store.spaces) { space in
                        Button(space.name) { store.select(space.id); dismiss() }
                    }
                    Button(store.text("רענון מ־iCloud", "Refresh from iCloud")) { store.perform { try await store.refresh() } }
                }
                Section(store.text("השם שלך במרחב", "Your name in the space")) { TextField(store.text("שם", "Name"), text: $memberName) }
                Section(store.text("יצירת מרחב", "Create a space")) {
                    TextField(store.text("למשל: הבית שלנו", "For example: Our home"), text: $name)
                    Picker(store.text("מטבע קבוע למרחב", "Space currency"), selection: $currency) {
                        ForEach(Array(Set([currency, "ILS", "USD", "EUR", "GBP", "JPY"])).sorted(), id: \.self) { Text($0).tag($0) }
                    }
                    Picker(store.text("סגנון עיר", "City style"), selection: $style) {
                        ForEach(CityMapStyle.allCases) { Text($0.title(isHebrew: AppLanguage.current == .hebrew)).tag($0) }
                    }
                    Button(store.text("יצירה", "Create")) {
                        store.perform {
                            try await store.create(name: name, memberName: memberName, currency: currency, mapStyle: style.rawValue)
                            dismiss()
                        }
                    }.disabled(name.isEmpty || memberName.isEmpty)
                }
                Section(store.text("הצטרפות להזמנה", "Join an invitation")) {
                    if store.invitation != nil { Text(store.text("התקבלה הזמנה למרחב", "A space invitation is ready")) }
                    TextField(store.text("קישור להזמנה", "Invitation link"), text: $url).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button(store.text("הצטרפות", "Join")) {
                        store.perform {
                            let metadata: CKShare.Metadata
                            if let pending = store.invitation { metadata = pending } else { metadata = try await store.metadata(for: url) }
                            try await store.accept(metadata, memberName: memberName)
                            dismiss()
                        }
                    }.disabled(memberName.isEmpty || (url.isEmpty && store.invitation == nil))
                }
                #if DEBUG
                if store.database == nil {
                    Section("DEBUG") {
                        Button(store.text("פתיחת מרחב הדגמה מקומי", "Open local demo space")) {
                            store.perform { try await store.startDemo(); dismiss() }
                        }
                    }
                }
                #endif
            }
            .disabled(store.busy)
            .navigationTitle(store.text("מרחב משותף", "Shared space"))
            .toolbar { Button(store.text("סיום", "Done")) { dismiss() } }
        }
    }
}

struct SharedSpaceManagement: View {
    let space: SharedSpace
    @ObservedObject private var store = SharedWorkspaceStore.shared
    @State private var share: SharingItem?
    private struct SharingItem: Identifiable { let id = UUID(); let share: CKShare }
    var body: some View {
        List {
            Section(space.name) {
                Text(space.currencyCode)
                Text(space.timeZoneID).font(.footnote).foregroundStyle(.secondary)
                ForEach(store.members.filter { $0.spaceID == space.id }) { member in
                    HStack { Circle().fill(Color(sharedHex: member.colorHex)).frame(width: 12, height: 12); Text(member.name) }
                }
            }
            Section {
                Button(store.text("הזמנה וניהול גישה", "Invite and manage access")) {
                    store.perform {
                        try store.ensureNoPendingChanges(in: space.id)
                        share = SharingItem(share: try await store.sharingRecord(in: space.id))
                    }
                }.disabled(store.demo)
                Button(store.text("מרחבים נוספים", "More spaces")) { store.showSetup = true }
                Button(store.text("חזרה לעיר שלי", "Back to my city")) { store.select(nil) }
            }
            if store.conflictCount > 0 {
                Section {
                    Text(store.text("\(store.conflictCount) עריכות התנגשו עם שינוי במרחב. גרסת השרת מוצגת; העותק המקומי נשמר לשחזור.",
                                    "\(store.conflictCount) edits conflicted with shared changes. The server version is shown; local copies are preserved for recovery."))
                }
            }
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden)
        .sheet(item: $share, onDismiss: { store.perform { try await store.refresh() } }) { item in
            SharedSharingController(share: item.share, container: store.cloud)
        }
    }
}

struct SharedSharingController: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator; controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        return controller
    }
    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func itemTitle(for csc: UICloudSharingController) -> String? { "SPENT" }
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            Task { @MainActor in SharedWorkspaceStore.shared.errorMessage = error.localizedDescription }
        }
    }
}

final class SharedSpaceSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata { receive(metadata) }
    }
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) { receive(cloudKitShareMetadata) }
    private func receive(_ metadata: CKShare.Metadata) {
        guard metadata.containerIdentifier == "iCloud.com.moneycity.app" else { return }
        #if DEBUG
        if metadata.share.recordID.zoneID.zoneName.hasPrefix(SharedCloudLab.zonePrefix) {
            SharedCloudLab.shared.invitation = metadata; SharedCloudLab.shared.presentRequested = true
            return
        }
        #endif
        guard metadata.share.recordID.zoneID.zoneName.hasPrefix(SharedWorkspaceStore.zonePrefix) else { return }
        SharedWorkspaceStore.shared.invitation = metadata; SharedWorkspaceStore.shared.showSetup = true
    }
}
#endif
