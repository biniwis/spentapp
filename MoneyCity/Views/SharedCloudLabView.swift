#if DEBUG && !SWIFT_PACKAGE
import CloudKit
import SwiftUI

/// Internal feasibility UI, deliberately separate from the production Shared experience.
struct SharedCloudLabView: View {
    @ObservedObject private var lab = SharedCloudLab.shared
    @Environment(\.dismiss) private var dismiss
    @State private var invitationURL = ""
    @State private var sharing: SharePresentation?
    private struct SharePresentation: Identifiable {
        let id = UUID()
        let share: CKShare
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Phase 1 · Development only") {
                    Text("Test records only. Personal expenses and backups are not used. Use two iCloud accounts on signed Debug builds.")
                    Text(lab.status).font(.footnote).textSelection(.enabled)
                    if lab.busy { ProgressView() }
                    Button("Connect / refresh") { lab.run { try await lab.refresh() } }
                    Button("Create test space") { lab.run { try await lab.createSpace() } }
                }
                Section("Join") {
                    if lab.invitation != nil { Text("Invitation received — accept below.") }
                    TextField("CloudKit invitation URL", text: $invitationURL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Accept invitation") { lab.run { try await lab.acceptInvitation(url: invitationURL) } }
                        .disabled(lab.invitation == nil && invitationURL.isEmpty)
                }
                Section("Test spaces") {
                    ForEach(lab.spaces) { space in
                        Button {
                            lab.select(space.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(space.scope == .private ? "Owner" : "Participant")
                                    Text(space.zone.zoneID.zoneName).font(.caption).lineLimit(1)
                                }
                                Spacer()
                                if space.id == lab.selectedID { Image(systemName: "checkmark") }
                            }
                        }
                    }
                    if lab.selected != nil {
                        Button("Invite / manage access") {
                            lab.run { sharing = SharePresentation(share: try await lab.sharingRecord()) }
                        }
                        Button("Add sample ₪1 (local)") { lab.run { try lab.saveSample() } }
                        Button("Sync now · \(lab.pendingCount) pending") { lab.run { try await lab.sync() } }
                    }
                }
                Section("Sample expenses") {
                    ForEach(lab.rows, id: \.recordID) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("₪\(Double(row["amountMinor"] as? Int64 ?? 0) / 100, specifier: "%.2f")")
                            Text(row.recordID.recordName).font(.caption2).textSelection(.enabled)
                            HStack {
                                Button("Add ₪1") { lab.run { try lab.saveSample(existing: row) } }
                                Spacer()
                                Button("Delete sample", role: .destructive) {
                                    lab.run { try lab.saveSample(existing: row, deleted: true) }
                                }
                            }.buttonStyle(.borderless)
                        }
                    }
                }
            }
            .disabled(lab.busy)
            .navigationTitle("Shared Cloud Lab")
            .toolbar { Button("Done") { dismiss() } }
            .sheet(item: $sharing, onDismiss: { lab.run { try await lab.refresh() } }) { presentation in
                SharedLabSharingController(share: presentation.share, container: lab.container)
            }
        }
    }
}

private struct SharedLabSharingController: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        return controller
    }
    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}
    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func itemTitle(for csc: UICloudSharingController) -> String? { "SPENT Shared Lab" }
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            Task { @MainActor in SharedCloudLab.shared.status = error.localizedDescription }
        }
    }
}

final class SharedLabSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata { receive(metadata) }
    }
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        receive(cloudKitShareMetadata)
    }
    private func receive(_ metadata: CKShare.Metadata) {
        guard metadata.containerIdentifier == "iCloud.com.moneycity.app",
              metadata.share.recordID.zoneID.zoneName.hasPrefix(SharedCloudLab.zonePrefix) else { return }
        SharedCloudLab.shared.invitation = metadata
        SharedCloudLab.shared.presentRequested = true
    }
}
#endif
