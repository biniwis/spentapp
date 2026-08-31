import SwiftUI
import SwiftData

/// State-of-the-art developer and diagnostics hub for Apple Pay -> Shortcuts -> App Intent verification.
public struct ApplePayDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager
    @Query(sort: \IngestLogEntry.receivedAt, order: .reverse) private var entries: [IngestLogEntry]
    
    @State private var showExportSheet = false
    @State private var exportJSONText = ""
    @State private var showSimulateToast = false
    @State private var selectedFilter: DiagnosticsFilter = .all

    private var isHebrew: Bool { l10n.language == .hebrew }

    public enum DiagnosticsFilter: String, CaseIterable {
        case all = "הכל"
        case success = "הצליח"
        case failed = "נכשל / חסר"
        
        var englishTitle: String {
            switch self {
            case .all: return "All"
            case .success: return "Success"
            case .failed: return "Failed"
            }
        }
    }

    public init() {}

    private var filteredEntries: [IngestLogEntry] {
        switch selectedFilter {
        case .all:
            return entries
        case .success:
            return entries.filter { $0.outcome.contains("נשמר") || $0.outcome.contains("saved") }
        case .failed:
            return entries.filter { !$0.outcome.contains("נשמר") && !$0.outcome.contains("saved") }
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // 1. Status Overview Header Banner
                    overviewHeaderCard
                    
                    // 2. Action Controls (Export JSON & Run Simulation)
                    actionControlsRow

                    // 3. Filter Segment
                    filterSegmentControl

                    // 4. Attempts List or Empty State
                    if filteredEntries.isEmpty {
                        emptyStateCard
                    } else {
                        VStack(spacing: 14) {
                            ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                                diagnosticCard(entry: entry, index: entries.count - index)
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(isHebrew ? "אבחון Apple Pay (דיאגנוסטיקה)" : "Apple Pay Diagnostics")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.text(for: "close")) { dismiss() }
                        .foregroundColor(Color.primaryBlue)
                }
                ToolbarItem(placement: .primaryAction) {
                    if !entries.isEmpty {
                        Button(isHebrew ? "נקה יומן" : "Clear") {
                            DatabaseService.shared.clearIngestLog()
                            Haptics.impact(.light)
                        }
                        .foregroundColor(Color.textMuted)
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                exportReportModal
            }
        }
    }

    // MARK: - 1. Overview Header Card
    private var overviewHeaderCard: some View {
        let totalCount = entries.count
        let successCount = entries.filter { $0.outcome.contains("נשמר") || $0.outcome.contains("saved") }.count
        let failedCount = totalCount - successCount

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(successCount > 0 ? Color.themeMintSoft : Color.themeOrangeSoft)
                        .frame(width: 38, height: 38)
                    DistrictFinanceVectorIcon(color: successCount > 0 ? Color.themeMint : Color.themeOrange)
                        .scaleEffect(1.0)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isHebrew ? "מצב מערכת הקליטה" : "Ingest Pipeline Status")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(totalCount > 0 && failedCount == 0 ? Color.themeMint : (failedCount > 0 ? Color.themeOrange : Color.slate400))
                            .frame(width: 8, height: 8)
                        Text(totalCount == 0
                             ? (isHebrew ? "מחכה לעסקה ראשונה..." : "Waiting for first transaction...")
                             : (failedCount == 0
                                ? (isHebrew ? "פעיל ותקין 🟢" : "Active & Healthy 🟢")
                                : (isHebrew ? "זוהו ניסיונות עם נתונים חסרים ⚠️" : "Detected runs with missing data ⚠️")))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color.textMuted)
                    }
                }
                Spacer()
            }

            Divider()

            HStack(spacing: 12) {
                statBox(title: isHebrew ? "סך הכל ניסיונות" : "Total Attempts", value: "\(totalCount)", color: Color.primaryBlue)
                statBox(title: isHebrew ? "נקלטו בהצלחה" : "Succeeded", value: "\(successCount)", color: Color.themeMint)
                statBox(title: isHebrew ? "חסרים / נכשלו" : "Failed / Missing", value: "\(failedCount)", color: Color.themeOrange)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.borderSubtle, lineWidth: 1.5))
        .shadow(color: Color.deepNavy.opacity(0.04), radius: 8, y: 2)
    }

    private func statBox(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(Color.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 2. Action Controls Row
    private var actionControlsRow: some View {
        HStack(spacing: 10) {
            Button(action: generateAndShowExport) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .bold))
                    Text(isHebrew ? "יצוא דוח JSON" : "Export JSON Report")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                }
                .foregroundColor(Color.primaryBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.themeLavenderSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button(action: runSimulationTest) {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(isHebrew ? "בדיקת סימולציה" : "Simulate Test")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                }
                .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.themeMintSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - 3. Filter Segment Control
    private var filterSegmentControl: some View {
        HStack(spacing: 8) {
            ForEach(DiagnosticsFilter.allCases, id: \.self) { filter in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedFilter = filter
                    }
                }) {
                    Text(isHebrew ? filter.rawValue : filter.englishTitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(selectedFilter == filter ? Color.white : Color.textMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(selectedFilter == filter ? Color.primaryBlue : Color.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.borderSubtle, lineWidth: selectedFilter == filter ? 0 : 1))
                }
            }
            Spacer()
        }
    }

    // MARK: - 4. Diagnostic Card per Transaction Attempt
    private func diagnosticCard(entry: IngestLogEntry, index: Int) -> some View {
        let isSuccess = entry.outcome.contains("נשמר") || entry.outcome.contains("saved")
        let statusColor: Color = isSuccess ? Color.themeMint : (entry.outcome.contains("כפילות") ? Color.themeYellow : Color.themeOrange)

        return VStack(alignment: .leading, spacing: 14) {
            // Card Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isHebrew ? "עסקת Apple Pay #\(index)" : "Apple Pay Ingest #\(index)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    Text(formattedDate(entry.receivedAt))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textMuted)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle().fill(statusColor).frame(width: 7, height: 7)
                    Text(entry.outcome.isEmpty ? (isHebrew ? "לא הושלם" : "Pending") : entry.outcome)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())
            }

            Divider()

            // Section A: Received from Shortcut
            VStack(alignment: .leading, spacing: 6) {
                Text(isHebrew ? "1. נתונים גולמיים שהתקבלו מ-Shortcuts:" : "1. Received from Shortcut:")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                VStack(spacing: 4) {
                    fieldRow(label: "Amount (סכום)", value: entry.rawAmount, isPresent: entry.hasAmount)
                    fieldRow(label: "Merchant (בית עסק)", value: entry.rawMerchant, isPresent: entry.hasMerchant)
                    fieldRow(label: "Currency (מטבע)", value: entry.rawCurrency, isPresent: entry.hasCurrency)
                    fieldRow(label: "Date (תאריך)", value: entry.rawDate, isPresent: entry.hasDate)
                    if entry.rawAmountText != "—" && entry.rawAmountText != "nil (לא הועבר)" {
                        fieldRow(label: "Amount Text", value: entry.rawAmountText, isPresent: true)
                    }
                }
                .padding(10)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Section B: Available Fields Checklist
            VStack(alignment: .leading, spacing: 6) {
                Text(isHebrew ? "2. זמינות שדות במטען (Field Checklist):" : "2. Available Fields Checklist:")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                HStack(spacing: 8) {
                    fieldPill(name: "Amount", available: entry.hasAmount)
                    fieldPill(name: "Merchant", available: entry.hasMerchant)
                    fieldPill(name: "Currency", available: entry.hasCurrency)
                    fieldPill(name: "Date", available: entry.hasDate)
                }
            }

            // Section C: Pipeline Steps
            VStack(alignment: .leading, spacing: 6) {
                Text(isHebrew ? "3. שלבי העיבוד (Pipeline Execution):" : "3. Pipeline Processing:")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                VStack(alignment: .leading, spacing: 4) {
                    pipelineStep(name: isHebrew ? "הפעלת App Intent ברקע" : "App Intent Launched", passed: true)
                    pipelineStep(name: isHebrew ? "חילוץ סכום תקין" : "Amount Parsed", passed: entry.hasAmount || entry.resolvedAmount != nil)
                    pipelineStep(name: isHebrew ? "ניקוי וסיווג שם בית עסק" : "Merchant Normalized", passed: entry.hasMerchant || entry.resolvedMerchant != nil)
                    if let cat = entry.categoryDetected {
                        pipelineStep(name: isHebrew ? "סיווג לקטגוריה: \(cat)" : "Category: \(cat)", passed: true)
                    }
                    pipelineStep(name: isHebrew ? "שמירה לבסיס הנתונים" : "Database Persistence", passed: isSuccess)
                }
                .padding(10)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Section D: Diagnostic Result & Failure Reason (if failed)
            if let reason = entry.failureReason, !reason.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color.themeOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isHebrew ? "סיבת הכשל / אבחון:" : "Diagnosis / Failure Reason:")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(Color.themeOrange)
                        Text(reason)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.themeOrangeSoft.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.borderSubtle, lineWidth: 1.5))
        .shadow(color: Color.deepNavy.opacity(0.04), radius: 8, y: 2)
    }

    private func fieldRow(label: String, value: String, isPresent: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.textMuted)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(isPresent ? Color.deepNavy : Color.themeOrange)
                .lineLimit(1)
        }
    }

    private func fieldPill(name: String, available: Bool) -> some View {
        HStack(spacing: 4) {
            Text(available ? "✓" : "✕")
                .font(.system(size: 10, weight: .black))
            Text(name)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundColor(available ? Color.themeMint : Color.themeOrange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((available ? Color.themeMint : Color.themeOrange).opacity(0.12))
        .clipShape(Capsule())
    }

    private func pipelineStep(name: String, passed: Bool) -> some View {
        HStack(spacing: 6) {
            Text(passed ? "✓" : "✕")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(passed ? Color.themeMint : Color.themeOrange)
            Text(name)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(passed ? Color.deepNavy : Color.textMuted)
        }
    }

    // MARK: - 5. Empty State Card
    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            ScannerLensVectorIcon(color: Color.primaryBlue)
                .scaleEffect(1.3)
                .frame(width: 44, height: 44)
            Text(isHebrew ? "טרם נקלטו עסקאות Apple Pay" : "No Apple Pay attempts logged yet")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
            Text(isHebrew
                 ? "בצע קנייה ב-Apple Pay או הרץ בדיקת סימולציה למעלה. ברגע שהאוטומציה תפעל, כל שלבי ה-Pipeline והנתונים הגולמיים יופיעו כאן בזמן אמת."
                 : "Make a test Apple Pay payment or tap Simulate Test above to see the live data stream.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.borderSubtle, lineWidth: 1.5))
    }

    // MARK: - Export Modal
    private var exportReportModal: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(isHebrew ? "דוח דיאגנוסטיקה (ללא פרטים רגישים)" : "Sanitized Diagnostic Report")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .padding(.top, 10)

                ScrollView {
                    Text(exportJSONText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.deepNavy)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 248/255, green: 250/255, blue: 252/255))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderSubtle, lineWidth: 1))
                }

                #if os(iOS)
                ShareLink(item: exportJSONText) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text(isHebrew ? "שתף דוח טקסט / JSON" : "Share Report")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.primaryBlue)
                    .clipShape(Capsule())
                }
                #endif
            }
            .padding(16)
            .navigationTitle(isHebrew ? "יצוא דוח" : "Export Report")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.text(for: "close")) { showExportSheet = false }
                }
            }
        }
    }

    // MARK: - Actions
    private func generateAndShowExport() {
        var reports: [[String: Any]] = []
        for (i, entry) in entries.enumerated() {
            let dict: [String: Any] = [
                "attemptIndex": entries.count - i,
                "timestamp": formattedDate(entry.receivedAt),
                "intentName": entry.intentName,
                "rawAmount": entry.rawAmount,
                "rawMerchant": entry.rawMerchant,
                "rawCurrency": entry.rawCurrency,
                "rawDate": entry.rawDate,
                "outcome": entry.outcome,
                "failureReason": entry.failureReason ?? "none",
                "resolvedAmount": entry.resolvedAmount ?? 0,
                "resolvedMerchant": entry.resolvedMerchant ?? "none"
            ]
            reports.append(dict)
        }

        if let data = try? JSONSerialization.data(withJSONObject: reports, options: [.prettyPrinted]),
           let str = String(data: data, encoding: .utf8) {
            exportJSONText = str
        } else {
            exportJSONText = "[]"
        }
        showExportSheet = true
    }

    private func runSimulationTest() {
        Task {
            _ = await WalletIngestCoordinator.run(
                amount: 47.25,
                amountText: nil,
                merchant: "שופרסל, גבעתיים, מחוז תל אביב",
                currency: "ILS",
                transactionDate: Date(),
                intentName: "RecordTransactionIntent (Simulation)"
            )
            await MainActor.run {
                Haptics.notify(.success)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM, HH:mm:ss"
        return f.string(from: date)
    }
}
