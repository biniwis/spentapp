import SwiftUI
import SwiftData

/// Comprehensive Developer and Diagnostics Hub for Apple Pay -> Shortcuts -> App Intent verification & Simulation Sandbox.
public struct ApplePayDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var l10n: LocalizationManager
    @Query(sort: \IngestLogEntry.receivedAt, order: .reverse) private var entries: [IngestLogEntry]
    
    @State private var showExportSheet = false
    @State private var exportJSONText = ""
    @State private var selectedFilter: DiagnosticsFilter = .all
    @State private var isSimulatingBatch = false
    @State private var batchProgressText = ""
    
    // Custom Simulator Inputs
    @State private var simAmountText = "45.00"
    @State private var simMerchantText = "AM:PM"
    @State private var simCurrencyText = "ILS"
    @State private var isCustomSimExpanded = false
    
    private var isHebrew: Bool { l10n.language == .hebrew }

    public enum DiagnosticsFilter: String, CaseIterable {
        case all = "הכל"
        case real = "Apple Pay אמיתי"
        case simulated = "סימולציה"
        case failed = "נכשל / חסר"
        
        var englishTitle: String {
            switch self {
            case .all: return "All"
            case .real: return "Real Apple Pay"
            case .simulated: return "Simulated"
            case .failed: return "Failed / Missing"
            }
        }
    }

    public init() {}

    private var filteredEntries: [IngestLogEntry] {
        switch selectedFilter {
        case .all:
            return entries
        case .real:
            return entries.filter { !$0.intentName.contains("Simulation") && !$0.intentName.contains("סימולציה") }
        case .simulated:
            return entries.filter { $0.intentName.contains("Simulation") || $0.intentName.contains("סימולציה") }
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
                    
                    // 2. Scenario Sandbox & Debug Transaction Generator (P0 Feature)
                    simulationSandboxCard

                    // 3. Action Controls (Export JSON & Batch Generator)
                    actionControlsRow

                    // 4. Filter Segment
                    filterSegmentControl

                    // 5. Attempts List or Empty State
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
            .navigationTitle(isHebrew ? "אבחון וסימולציית Apple Pay" : "Apple Pay Diagnostics & Sandbox")
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
        let realCount = entries.filter { !$0.intentName.contains("Simulation") && !$0.intentName.contains("סימולציה") }.count
        let simCount = entries.filter { $0.intentName.contains("Simulation") || $0.intentName.contains("סימולציה") }.count
        let failedCount = entries.filter { !$0.outcome.contains("נשמר") && !$0.outcome.contains("saved") }.count

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.primaryBlue.opacity(0.12))
                        .frame(width: 38, height: 38)
                    DistrictFinanceVectorIcon(color: Color.primaryBlue)
                        .scaleEffect(1.0)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isHebrew ? "מצב מערכת הקליטה" : "Ingest Pipeline Status")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(realCount > 0 ? Color.themeMint : Color.themeTurquoise)
                            .frame(width: 8, height: 8)
                        Text(realCount > 0
                             ? (isHebrew ? "קליטה אמיתית מ-Apple Pay פעילה" : "Real Apple Pay Active")
                             : (isHebrew ? "מוכן לקליטה / בדיקת סימולציות" : "Ready for Real / Simulation"))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color.textMuted)
                    }
                }
                Spacer()
            }

            Divider()

            HStack(spacing: 8) {
                statBox(title: isHebrew ? "סך הכל ניסיונות" : "Total Attempts", value: "\(totalCount)", color: Color.deepNavy)
                statBox(title: isHebrew ? "Apple Pay אמיתי" : "Real Apple Pay", value: "\(realCount)", color: Color.themeMint)
                statBox(title: isHebrew ? "סימולציה" : "Simulated", value: "\(simCount)", color: Color.primaryBlue)
                statBox(title: isHebrew ? "נכשלו / חסרים" : "Failed / Missing", value: "\(failedCount)", color: failedCount > 0 ? Color.themeOrange : Color.slate400)
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
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(Color.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 2. Scenario Sandbox & Debug Generator
    private var simulationSandboxCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "flask.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.themeLavender)
                Text(isHebrew ? "סימולטור עסקאות (Debug Generator)" : "Scenario Simulation Sandbox")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                Spacer()
                Text(isHebrew ? "עובר באותו Pipeline בדיוק" : "Runs Exact Production Pipeline")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color.themeLavender)
            }

            Text(isHebrew ? "בדוק 99% מיכולות האפליקציה (קליטה, סיווג, עיר, והיסטוריה) בלחיצה אחת בלי להוציא שקל:" : "Test 99% of app behavior (ingest, categorization, 3D city, history) without spending real money:")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color.textSecondary)

            // Preset Scenario Chips
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    scenarioButton(icon: "cup.and.saucer.fill", title: "קפה ₪18", subtitle: "Aroma") {
                        simulate(amount: 18, merchant: "ארומה קפה", currency: "ILS")
                    }
                    scenarioButton(icon: "fork.knife", title: "מסעדה ₪145", subtitle: "Taqueria") {
                        simulate(amount: 145, merchant: "טאקריה תל אביב", currency: "ILS")
                    }
                    scenarioButton(icon: "cart.fill", title: "סופר ₪382.50", subtitle: "Shufersal") {
                        simulate(amount: 382.50, merchant: "שופרסל דיל", currency: "ILS")
                    }
                }
                
                HStack(spacing: 8) {
                    scenarioButton(icon: "house.fill", title: "דיור ₪3,200", subtitle: "Rent") {
                        simulate(amount: 3200, merchant: "שכירות ועד בית", currency: "ILS")
                    }
                    scenarioButton(icon: "arrow.uturn.backward", title: "זיכוי -₪145", subtitle: "Refund") {
                        simulate(amount: -145, merchant: "IKEA זיכוי", currency: "ILS")
                    }
                    scenarioButton(icon: "exclamationmark.triangle.fill", title: "ללא בית עסק", subtitle: "nil merchant") {
                        simulate(amount: 55, merchant: nil, currency: "ILS")
                    }
                }
                
                HStack(spacing: 8) {
                    scenarioButton(icon: "text.bubble.fill", title: "טקסט בלבד", subtitle: "Wolt ₪89.50") {
                        simulateTextOnly("וולט משלוחים ₪89.50")
                    }
                    scenarioButton(icon: "repeat", title: "כפילות זהה", subtitle: "Deduplication") {
                        simulateDuplicate()
                    }
                }
            }

            // Live Lock Screen Simulated Purchase Notification Generator
            Button {
                Haptics.impact(.medium)
                NotificationService.scheduleLockScreenFakePurchase(amount: 142.50, merchant: "שופרסל דיל", categoryName: "קניות וסופרמרקט", delaySeconds: 3.0)
                simulate(amount: 142.50, merchant: "שופרסל דיל", currency: "ILS")
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isHebrew ? "שלח התראת רכישה למסך הנעילה (עוד 3 שניות)" : "Send Live Lock Screen Notification (3s)")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundColor(Color.white)
                        Text(isHebrew ? "לחץ ונעל מיד את הטלפון כדי לראות את ההתראה נדלקת על המסך!" : "Tap and lock phone to see it light up the lock screen!")
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.85))
                    }
                    Spacer()
                    Image(systemName: isHebrew ? "chevron.left" : "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(red: 79/255, green: 70/255, blue: 229/255), Color(red: 99/255, green: 102/255, blue: 241/255)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color(red: 79/255, green: 70/255, blue: 229/255).opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)

            // Custom Simulator Expandable Form
            DisclosureGroup(
                isExpanded: $isCustomSimExpanded,
                content: {
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(isHebrew ? "סכום" : "Amount")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color.textMuted)
                                TextField("45.00", text: $simAmountText)
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .padding(8)
                                    .background(Color.appBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(isHebrew ? "בית עסק" : "Merchant")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color.textMuted)
                                TextField("AM:PM", text: $simMerchantText)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .padding(8)
                                    .background(Color.appBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }

                        Button(action: {
                            if let amt = Double(simAmountText) {
                                simulate(amount: amt, merchant: simMerchantText, currency: simCurrencyText)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text(isHebrew ? "שלח עסקת בדיקה מותאמת" : "Send Custom Simulated Transaction")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.primaryBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.top, 8)
                },
                label: {
                    Text(isHebrew ? "הזנת עסקה מותאמת ידנית..." : "Custom Transaction Inputs...")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color.primaryBlue)
                }
            )
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.borderSubtle, lineWidth: 1.5))
        .shadow(color: Color.deepNavy.opacity(0.04), radius: 8, y: 2)
    }

    private func scenarioButton(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.impact(.medium)
            action()
        }) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.primaryBlue)
                    Text(title)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                }
                Text(subtitle)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3. Action Controls Row
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

            Button(action: generateMonthOfSimulatedActivity) {
                HStack(spacing: 6) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(isHebrew ? "צור חודש עשיר (30 עסקאות)" : "Seed Month (30 txs)")
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

    // MARK: - 4. Filter Segment Control
    private var filterSegmentControl: some View {
        ScrollView(.horizontal, showsIndicators: false) {
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
            }
        }
    }

    // MARK: - 5. Diagnostic Card per Transaction Attempt
    private func diagnosticCard(entry: IngestLogEntry, index: Int) -> some View {
        let isSuccess = entry.outcome.contains("נשמר") || entry.outcome.contains("saved")
        let isSim = entry.intentName.contains("Simulation") || entry.intentName.contains("סימולציה")
        let statusColor: Color = isSuccess ? Color.themeMint : (entry.outcome.contains("כפילות") ? Color.themeYellow : Color.themeOrange)

        return VStack(alignment: .leading, spacing: 14) {
            // Card Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: isSim ? "flask.fill" : "creditcard.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isSim ? Color.themeLavender : Color.themeMint)
                        Text(isSim ? (isHebrew ? "סימולציה #\(index)" : "Simulated Ingest #\(index)") : (isHebrew ? "Apple Pay אמיתי #\(index)" : "Real Apple Pay #\(index)"))
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                    }
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

            // Section A: Received Input
            VStack(alignment: .leading, spacing: 6) {
                Text(isHebrew ? "1. נתוני קלט שהתקבלו:" : "1. Ingest Input Parameters:")
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

            // Section B: Pipeline Execution
            VStack(alignment: .leading, spacing: 6) {
                Text(isHebrew ? "2. שלבי העיבוד והסיווג (Pipeline Steps):" : "2. Pipeline Verification Steps:")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                VStack(alignment: .leading, spacing: 4) {
                    pipelineStep(name: isHebrew ? "קבלת פקודה (App Intent)" : "App Intent Received", passed: true)
                    pipelineStep(name: isHebrew ? "אימות ותקינות סכום (Amount Validation)" : "Amount Parsed", passed: entry.hasAmount || entry.resolvedAmount != nil)
                    pipelineStep(name: isHebrew ? "זיהוי וניקוי שם בית עסק (Merchant Normalization)" : "Merchant Normalized", passed: entry.hasMerchant || entry.resolvedMerchant != nil)
                    if let cat = entry.categoryDetected {
                        pipelineStep(name: isHebrew ? "סיווג קטגוריה אוטומטי: \(cat)" : "Category Classified: \(cat)", passed: true)
                    }
                    pipelineStep(name: isHebrew ? "שמירה לבסיס הנתונים ועדכון תלת-ממד" : "Persisted & City Updated", passed: isSuccess)
                }
                .padding(10)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Section C: Diagnostics failure if any
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

    private func pipelineStep(name: String, passed: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(passed ? Color.themeMint : Color.themeOrange)
            Text(name)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            DistrictFinanceVectorIcon(color: Color.textMuted)
                .scaleEffect(1.3)
                .padding(.top, 10)
            Text(isHebrew ? "אין רישומי דיאגנוסטיקה עדיין" : "No Ingest Logs Yet")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Color.deepNavy)
            Text(isHebrew ? "הפעל סימולציה מהכפתורים למעלה או בצע רכישה ב-Apple Pay כדי לראות את שלבי הקליטה." : "Run a simulation above or make an Apple Pay purchase to inspect pipeline logs.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.borderSubtle, lineWidth: 1))
    }

    private var exportReportModal: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(isHebrew ? "דוח JSON המכיל את כל שלבי הנתונים הגולמיים והסיווגים:" : "Full JSON Diagnostics Ingest Trace:")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: .constant(exportJSONText))
                    .font(.system(size: 11, design: .monospaced))
                    .padding(8)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderSubtle, lineWidth: 1))

                #if os(iOS)
                ShareLink(item: exportJSONText) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text(isHebrew ? "שתף דוח JSON" : "Share JSON Report")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
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

    // MARK: - Simulation Actions
    private func simulate(amount: Double?, merchant: String?, currency: String?) {
        Task {
            _ = await WalletIngestCoordinator.run(
                amount: amount,
                amountText: nil,
                merchant: merchant,
                currency: currency,
                transactionDate: Date(),
                intentName: "RecordTransactionIntent (Simulation)"
            )
            await MainActor.run {
                Haptics.notify(.success)
            }
        }
    }

    private func simulateTextOnly(_ text: String) {
        Task {
            _ = await WalletIngestCoordinator.run(
                amount: nil,
                amountText: text,
                merchant: text,
                currency: "ILS",
                transactionDate: Date(),
                intentName: "RecordTransactionIntent (Simulation Text-Only)"
            )
            await MainActor.run {
                Haptics.notify(.success)
            }
        }
    }

    private func simulateDuplicate() {
        let fixedDate = Date()
        Task {
            // First run
            _ = await WalletIngestCoordinator.run(
                amount: 88.0,
                amountText: nil,
                merchant: "Super Yuda Duplicate Test",
                currency: "ILS",
                transactionDate: fixedDate,
                intentName: "RecordTransactionIntent (Simulation Run 1)"
            )
            // Second run (Duplicate)
            _ = await WalletIngestCoordinator.run(
                amount: 88.0,
                amountText: nil,
                merchant: "Super Yuda Duplicate Test",
                currency: "ILS",
                transactionDate: fixedDate,
                intentName: "RecordTransactionIntent (Simulation Run 2 - Duplicate)"
            )
            await MainActor.run {
                Haptics.notify(.success)
            }
        }
    }

    private func generateMonthOfSimulatedActivity() {
        Task {
            let cal = Calendar(identifier: .gregorian)
            let now = Date()
            
            let dataset: [(amt: Double, m: String, dayOffset: Int)] = [
                (18.0, "ארומה קפה", 1),
                (3200.0, "שכר דירה חודשי", 1),
                (145.0, "טאקריה", 3),
                (42.0, "וולט פיצה", 5),
                (380.0, "שופרסל דיל", 7),
                (18.0, "ארומה קפה", 8),
                (120.0, "ZARA", 10),
                (65.0, "סופר-פארם", 12),
                (18.0, "ארומה קפה", 14),
                (250.0, "Gett מוניות", 15),
                (49.90, "Netflix", 16),
                (1850.0, "איקאה ריהוט", 18),
                (18.0, "ארומה קפה", 20),
                (95.0, "סינמה סיטי", 22),
                (410.0, "רמי לוי", 24),
                (18.0, "ארומה קפה", 26),
                (85.0, "דלק פז", 28)
            ]
            
            for item in dataset {
                let txDate = cal.date(byAdding: .day, value: -item.dayOffset, to: now) ?? now
                _ = await WalletIngestCoordinator.run(
                    amount: item.amt,
                    amountText: nil,
                    merchant: item.m,
                    currency: "ILS",
                    transactionDate: txDate,
                    intentName: "RecordTransactionIntent (Batch Seed)"
                )
            }
            
            await MainActor.run {
                Haptics.notify(.success)
            }
        }
    }

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

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM, HH:mm:ss"
        return f.string(from: date)
    }
}
