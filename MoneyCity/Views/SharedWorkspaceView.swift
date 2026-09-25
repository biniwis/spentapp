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

/// Uses SPENT's existing editor; only destination and payer are additional.
struct SharedExpenseEditor: View {
    let space: SharedSpace
    var expense: SharedExpense?
    var body: some View {
        QuickAddSheet(
            initialCategory: expense?.category,
            initialCategoryIsExplicit: expense != nil,
            initialCurrency: CurrencyType(rawValue: space.currencyCode),
            initialMerchant: expense?.merchant,
            initialBuildingId: expense?.buildingID,
            initialDate: expense?.date ?? Date(),
            titleOverride: expense == nil ? nil : (AppLanguage.current == .hebrew ? "עריכת הוצאה" : "Edit expense"),
            sharedSpaceID: space.id,
            sharedExpenseID: expense?.id,
            onSaveWithExplicitFlag: { _, _, _, _, _, _, _, _, _ in }
        )
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
        }.listStyle(.plain).scrollContentBackground(.hidden)
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
