import SwiftUI

public struct CityConfirmationBanner: View {
    public let banner: PendingExpenseConfirmation?
    @EnvironmentObject private var l10n: LocalizationManager

    public init(banner: PendingExpenseConfirmation?) {
        self.banner = banner
    }

    public var body: some View {
        if let banner = banner {
            let label: String = banner.merchant.isEmpty
                ? (l10n.isHebrew ? "הוצאה עודכנה" : "Expense recorded")
                : banner.merchant
            let amountStr: String = l10n.format(amount: banner.amount)

            HStack(spacing: 7) {
                MoneyIcon(.checkCircle, size: 13)
                    .foregroundColor(MoneyCityTheme.mint)

                Text("+\(amountStr) · \(label)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
            )
            .overlay(
                Capsule()
                    .stroke(Color.borderSubtle, lineWidth: 1)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, -4)
        }
    }
}
