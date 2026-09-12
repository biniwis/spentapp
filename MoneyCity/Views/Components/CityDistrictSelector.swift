import SwiftUI

public struct CityDistrictSelector: View {
    public let selectedDistrict: String?
    public let onSelectDistrict: (String?) -> Void
    @EnvironmentObject private var l10n: LocalizationManager

    public init(
        selectedDistrict: String?,
        onSelectDistrict: @escaping (String?) -> Void
    ) {
        self.selectedDistrict = selectedDistrict
        self.onSelectDistrict = onSelectDistrict
    }

    public var body: some View {
        HStack(spacing: 0) {
            topDistrictPill(
                id: nil,
                title: l10n.language == .hebrew ? "כל העיר" : "All City"
            ) { _ in
                MoneyIcon(.citySkyline, size: 24)
            }
            topDistrictPill(
                id: "food",
                title: l10n.language == .hebrew ? "אוכל" : "Food"
            ) { _ in
                MoneyIcon(.cutlery, size: 24)
            }
            topDistrictPill(
                id: "shopping",
                title: l10n.language == .hebrew ? "קניות" : "Shopping"
            ) { _ in
                MoneyIcon(.shoppingBag, size: 24)
            }
            topDistrictPill(
                id: "housing",
                title: l10n.language == .hebrew ? "מגורים" : "Housing"
            ) { _ in
                MoneyIcon(.home, size: 24)
            }
            topDistrictPill(
                id: "transport",
                title: l10n.language == .hebrew ? "תחבורה" : "Transport"
            ) { _ in
                MoneyIcon(.car, size: 24)
            }
            topDistrictPill(
                id: "savings",
                title: l10n.language == .hebrew ? "הפארק" : "The Park"
            ) { _ in
                MoneyIcon(.leaf, size: 24)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(MoneyCityTheme.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 3)
        .padding(.horizontal, 16)
    }

    private func topDistrictPill<V: View>(
        id: String?,
        title: String,
        @ViewBuilder icon: (Bool) -> V
    ) -> some View {
        let isSelected = (id == nil && selectedDistrict == nil) || (id != nil && selectedDistrict == id)
        return Button(action: {
            onSelectDistrict(id)
        }) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white : MoneyCityTheme.jetBlack.opacity(0.04))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? MoneyCityTheme.jetBlack : MoneyCityTheme.borderSubtle, lineWidth: isSelected ? 2.0 : 1.0)
                        )
                        .shadow(color: isSelected ? Color.black.opacity(0.10) : Color.clear, radius: 4, y: 2)
                        .scaleEffect(isSelected ? 1.05 : 1.0)

                    icon(isSelected)
                }

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? MoneyCityTheme.textPrimary : MoneyCityTheme.textSecondary)

                // Crisp Minimal Selection Indicator
                if isSelected {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(MoneyCityTheme.jetBlack)
                        .frame(width: 12, height: 2.5)
                } else {
                    Color.clear.frame(width: 12, height: 2.5)
                }
            }
            .contentShape(Rectangle())
        }
        .bouncyPress(scale: 0.90)
        .frame(maxWidth: .infinity)
    }
}
