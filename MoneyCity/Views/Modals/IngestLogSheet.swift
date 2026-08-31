import SwiftUI
import SwiftData

/// What the Shortcuts automation actually handed the app, invocation by invocation.
///
/// Exists because "ההפעלה האוטומטית נכשלה" tells you nothing. This turns a failed tap into
/// a readable record of which fields arrived and which were empty.
public struct IngestLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var l10n: LocalizationManager

    @Query(sort: \IngestLogEntry.receivedAt, order: .reverse) private var entries: [IngestLogEntry]

    private let sheetBg = Color(red: 248/255, green: 250/255, blue: 252/255)

    public init() {}

    private var isHebrew: Bool { l10n.language == .hebrew }

    public var body: some View {
        NavigationStack {
            ZStack {
                sheetBg.ignoresSafeArea()

                if entries.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            explainer
                            ForEach(entries) { entry in
                                row(entry)
                            }
                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
            }
            .navigationTitle(isHebrew ? "יומן קליטה" : "Ingest Log")
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
                        Button(isHebrew ? "נקה" : "Clear") {
                            DatabaseService.shared.clearIngestLog()
                            Haptics.impact(.light)
                        }
                        .foregroundColor(Color.slate400)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("📡").font(.system(size: 44, design: .rounded))
            Text(isHebrew ? "עוד לא הופעל האינטנט" : "The intent has not run yet")
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(isHebrew
                 ? "אחרי תשלום בהצמדה, או אחרי הרצה ידנית של הקיצור, תופיע כאן שורה עם מה שהתקבל בפועל."
                 : "After a tap-to-pay, or a manual run of the shortcut, a row appears here with exactly what arrived.")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(Color.slate400)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
    }

    private var explainer: some View {
        Text(isHebrew
             ? "כל שורה היא הפעלה אחת של האוטומציה. אם שדה מופיע כ־nil או כמחרוזת ריקה — Wallet לא העביר אותו, וזו הבעיה למעלה מהאפליקציה."
             : "Each row is one automation run. A field shown as nil or an empty string means Wallet never sent it — the problem is upstream of the app.")
            .font(.system(size: 12, design: .rounded))
            .foregroundColor(Color.slate400)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 2)
    }

    private func row(_ entry: IngestLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.outcome.isEmpty ? (isHebrew ? "לא הושלם" : "incomplete") : entry.outcome)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(outcomeColor(entry.outcome))
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(outcomeColor(entry.outcome).opacity(0.12))
                    .clipShape(Capsule())
                Spacer()
                Text(timestamp(entry.receivedAt))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.slate400)
            }

            VStack(alignment: .leading, spacing: 3) {
                field("amount", entry.rawAmount)
                field("amountText", entry.rawAmountText)
                field("merchant", entry.rawMerchant)
                field("currency", entry.rawCurrency)
                field("date", entry.rawDate)
            }

            if entry.resolvedAmount != nil || entry.resolvedMerchant != nil {
                Divider()
                HStack(spacing: 6) {
                    Text(isHebrew ? "שוחזר:" : "Recovered:")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color.slate400)
                    Text("\(entry.resolvedMerchant ?? "—") · \(entry.resolvedAmount.map { String(format: "%.2f", $0) } ?? "—")")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color.themeMint)
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.slate200, lineWidth: 1))
    }

    private func field(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color.slate400)
                .frame(width: 82, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(value.hasPrefix("nil") || value.hasPrefix("\"\"")
                                 ? Color.red
                                 : Color(red: 15/255, green: 23/255, blue: 42/255))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func outcomeColor(_ outcome: String) -> Color {
        if outcome.contains("נשמר") && !outcome.contains("לא זוהה") { return Color.themeMint }
        if outcome.contains("כפילות") { return Color.themeYellow }
        return Color.red
    }

    private func timestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d/M HH:mm:ss"
        return f.string(from: date)
    }
}
