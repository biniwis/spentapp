import SwiftUI

public struct ResolvePendingAmountSheet: View {
    public let pending: PendingWalletIngest
    public let onCommit: (Double) -> Void
    public let onDismiss: () -> Void

    @EnvironmentObject private var l10n: LocalizationManager
    @State private var amountText: String = ""
    @State private var hasError = false
    @FocusState private var isAmountFocused: Bool

    public init(
        pending: PendingWalletIngest,
        onCommit: @escaping (Double) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.pending = pending
        self.onCommit = onCommit
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    MoneyIcon(.creditCard, size: 40)
                        .padding(.top, 8)

                    Text(l10n.language == .hebrew ? "הזנת סכום לתשלום" : "Enter Payment Amount")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))

                    Text(pending.merchant)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(pending.currency)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 100/255, green: 116/255, blue: 139/255))

                    TextField("0", text: $amountText)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .keyboardType(.decimalPad)
                        .focused($isAmountFocused)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 160)
                }
                .padding(.vertical, 8)
                .background(Color(red: 248/255, green: 250/255, blue: 252/255))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if hasError {
                    Text(l10n.language == .hebrew ? "אנא הזן סכום תקין" : "Please enter a valid amount")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.red)
                }

                Button(action: {
                    if let parsed = AmountParser.parse(amountText) {
                        let amount = NSDecimalNumber(decimal: parsed).doubleValue
                        onCommit(amount)
                    } else {
                        hasError = true
                        Haptics.notify(.warning)
                    }
                }) {
                    Text(l10n.language == .hebrew ? "שמור בעיר" : "Save to City")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(
                                colors: [Color.spentGreen, Color(red: 22/255, green: 163/255, blue: 74/255)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.language == .hebrew ? "ביטול" : "Cancel", action: onDismiss)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isAmountFocused = true
                }
            }
        }
    }
}
