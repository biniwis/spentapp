import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Everything to do with getting the user's data out, and back in.
///
/// Three separate promises, and they cover different disasters. The export file is theirs to
/// keep anywhere; the import puts one back; the snapshots are the app's own rollback for the
/// case that actually happens most — a new build whose migration does not go through.
public struct BackupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager

    @State private var exportURL: URL? = nil
    @State private var exportError: String? = nil
    @State private var showImporter = false
    @State private var importMode: DataPortabilityService.ImportMode = .merge
    @State private var importResult: String? = nil
    @State private var snapshots: [StoreSnapshotService.Snapshot] = []
    @State private var restoreTarget: StoreSnapshotService.Snapshot? = nil
    @State private var restoreArmed = false

    private let sheetBg = Color(red: 248/255, green: 250/255, blue: 252/255)

    public init() {}

    private var isHebrew: Bool { l10n.language == .hebrew }

    public var body: some View {
        NavigationStack {
            ZStack {
                sheetBg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        exportCard
                        importCard
                        snapshotCard
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle(isHebrew ? "גיבוי ושחזור" : "Backup & Restore")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.text(for: "close")) { dismiss() }
                        .foregroundColor(Color.primaryBlue)
                }
            }
            .onAppear {
                snapshots = StoreSnapshotService.available()
                prepareExport()
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert(
                isHebrew ? "לשחזר את הגיבוי הזה?" : "Restore this snapshot?",
                isPresented: $restoreArmed,
                presenting: restoreTarget
            ) { snapshot in
                Button(isHebrew ? "שחזר" : "Restore", role: .destructive) {
                    StoreSnapshotService.requestRestore(snapshot)
                    importResult = isHebrew
                        ? "השחזור יתבצע בפתיחה הבאה. סגור את האפליקציה לגמרי ופתח אותה שוב."
                        : "The restore happens on the next launch. Close the app fully and open it again."
                }
                Button(l10n.text(for: "cancel"), role: .cancel) {}
            } message: { snapshot in
                Text(isHebrew
                     ? "המצב הנוכחי יישמר כגיבוי נוסף לפני ההחלפה, כך שאפשר יהיה לחזור ממנו."
                     : "The current state is snapshotted first, so this can be undone.")
                    + Text("\n\(snapshot.displayDate)")
            }
        }
    }

    // MARK: - Export

    private var exportCard: some View {
        card(icon: "square.and.arrow.up.fill", tint: Color.primaryBlue,
             title: isHebrew ? "ייצוא לקובץ" : "Export to a file",
             body: isHebrew
                ? "כל ההוצאות, התקציבים, היעדים, הכללים וההוצאות הקבועות — בקובץ JSON אחד. שמור אותו ב־Files או בדרייב."
                : "Every expense, budget, goal, rule and fixed charge — one JSON file. Keep it in Files or a drive.") {
            if let exportURL {
                ShareLink(item: exportURL) {
                    actionLabel(isHebrew ? "שמור עותק" : "Save a copy", filled: true)
                }
            } else if let exportError {
                Text(exportError)
                    .font(.system(size: 12))
                    .foregroundColor(MoneyCityTheme.orange)
            } else {
                ProgressView().padding(.vertical, 6)
            }
        }
    }

    private func prepareExport() {
        do {
            let data = try DataPortabilityService.exportData(context: modelContext)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(DataPortabilityService.suggestedFileName())
            try data.write(to: url, options: .atomic)
            exportURL = url
            exportError = nil
        } catch {
            exportError = isHebrew ? "הייצוא נכשל: \(error.localizedDescription)"
                                   : "Export failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Import

    private var importCard: some View {
        card(icon: "square.and.arrow.down.fill", tint: MoneyCityTheme.mint,
             title: isHebrew ? "שחזור מקובץ" : "Restore from a file",
             body: isHebrew
                ? "טוען קובץ גיבוי שייצאת. \"מיזוג\" מוסיף רק רשומות שאין כאן; \"החלפה\" מוחק הכול ומחליף בקובץ."
                : "Loads a backup you exported. Merge adds only records this device has never seen; Replace clears everything first.") {
            VStack(spacing: 10) {
                Picker("", selection: $importMode) {
                    Text(isHebrew ? "מיזוג" : "Merge").tag(DataPortabilityService.ImportMode.merge)
                    Text(isHebrew ? "החלפה" : "Replace").tag(DataPortabilityService.ImportMode.replace)
                }
                .pickerStyle(.segmented)

                Button { showImporter = true } label: {
                    actionLabel(isHebrew ? "בחר קובץ" : "Choose a file", filled: false)
                }

                if importMode == .replace {
                    Text(isHebrew
                         ? "החלפה מוחקת את כל מה שיש כאן. תצלום אוטומטי נשמר בכל בנייה, אבל לא לפני ייבוא — ייצא עותק קודם."
                         : "Replace deletes everything here first. Export a copy before you do.")
                        .font(.system(size: 11))
                        .foregroundColor(MoneyCityTheme.orange)
                        .multilineTextAlignment(isHebrew ? .trailing : .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let importResult {
                    Text(importResult)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(MoneyCityTheme.textSecondary)
                        .multilineTextAlignment(isHebrew ? .trailing : .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            // A file coming from Files or iCloud Drive is outside the sandbox until asked for.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            let summary = try DataPortabilityService.importData(
                data, into: modelContext, mode: importMode
            )
            importResult = isHebrew
                ? "נטענו \(summary.added) רשומות, \(summary.skipped) כבר היו כאן."
                : "Imported \(summary.added) records, \(summary.skipped) were already here."
            snapshots = StoreSnapshotService.available()
            // The export file is written once, when the sheet opens. Without this, sharing a
            // backup after an import hands out the pre-import file — a backup missing exactly
            // the records the user just merged in.
            prepareExport()
        } catch {
            importResult = isHebrew ? "הייבוא נכשל: \(error.localizedDescription)"
                                    : "Import failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Snapshots

    private var snapshotCard: some View {
        card(icon: "clock.arrow.circlepath", tint: MoneyCityTheme.lavender,
             title: isHebrew ? "תצלומים אוטומטיים" : "Automatic snapshots",
             body: isHebrew
                ? "עותק של מסד הנתונים נשמר לפני כל בנייה חדשה — הרגע היחיד שבו מבנה הנתונים יכול להישבר. נשמרים שלושה אחרונים."
                : "A copy of the database is kept before every new build — the only moment its shape can break. The last three are kept.") {
            if snapshots.isEmpty {
                Text(isHebrew ? "אין עדיין תצלומים." : "No snapshots yet.")
                    .font(.system(size: 12))
                    .foregroundColor(MoneyCityTheme.textMuted)
            } else {
                VStack(spacing: 8) {
                    ForEach(snapshots) { snapshot in
                        snapshotRow(snapshot)
                    }
                }
            }
        }
    }

    private func snapshotRow(_ snapshot: StoreSnapshotService.Snapshot) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: isHebrew ? .trailing : .leading, spacing: 2) {
                Text(snapshot.displayDate)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(MoneyCityTheme.textPrimary)
                Text(snapshotSubtitle(snapshot))
                    .font(.system(size: 11))
                    .foregroundColor(MoneyCityTheme.textMuted)
            }
            Spacer(minLength: 0)
            Button {
                restoreTarget = snapshot
                restoreArmed = true
            } label: {
                Text(isHebrew ? "שחזר" : "Restore")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.primaryBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.primaryBlue.opacity(0.10)))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(sheetBg))
    }

    private func snapshotSubtitle(_ snapshot: StoreSnapshotService.Snapshot) -> String {
        var parts: [String] = []
        if let count = snapshot.transactionCount {
            parts.append(isHebrew ? "\(count) עסקאות" : "\(count) transactions")
        }
        parts.append("build \(snapshot.build)")
        let mb = Double(snapshot.byteSize) / 1_048_576.0
        parts.append(String(format: "%.1f MB", mb))
        return parts.joined(separator: " · ")
    }

    // MARK: - Chrome

    @ViewBuilder
    private func card<Content: View>(
        icon: String,
        tint: Color,
        title: String,
        body text: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: isHebrew ? .trailing : .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(tint)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(MoneyCityTheme.textPrimary)
                Spacer(minLength: 0)
            }
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(MoneyCityTheme.textSecondary)
                .multilineTextAlignment(isHebrew ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: isHebrew ? .trailing : .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.cardBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.borderSubtle, lineWidth: 1)
        )
    }

    private func actionLabel(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(filled ? .white : Color.primaryBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(filled ? Color.primaryBlue : Color.primaryBlue.opacity(0.10))
            )
    }
}
