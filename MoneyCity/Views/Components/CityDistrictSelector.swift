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
                title: l10n.language == .hebrew ? "כל העיר" : "All City",
                unselectedBg: Color(red: 243/255, green: 244/255, blue: 246/255)
            ) { _ in
                MoneyIcon(.citySkyline, size: 24)
            }
            topDistrictPill(
                id: "food",
                title: l10n.language == .hebrew ? "אוכל" : "Food",
                unselectedBg: Color(red: 254/255, green: 242/255, blue: 232/255)
            ) { _ in
                MoneyIcon(.cutlery, size: 24)
            }
            topDistrictPill(
                id: "shopping",
                title: l10n.language == .hebrew ? "קניות" : "Shopping",
                unselectedBg: Color(red: 253/255, green: 238/255, blue: 244/255)
            ) { _ in
                MoneyIcon(.shoppingBag, size: 24)
            }
            topDistrictPill(
                id: "housing",
                title: l10n.language == .hebrew ? "מגורים" : "Housing",
                unselectedBg: Color(red: 238/255, green: 245/255, blue: 254/255)
            ) { _ in
                MoneyIcon(.home, size: 24)
            }
            topDistrictPill(
                id: "transport",
                title: l10n.language == .hebrew ? "תחבורה" : "Transport",
                unselectedBg: Color(red: 236/255, green: 253/255, blue: 245/255)
            ) { _ in
                MoneyIcon(.car, size: 24)
            }
            topDistrictPill(
                id: "savings",
                title: l10n.language == .hebrew ? "הפארק" : "The Park",
                unselectedBg: Color(red: 234/255, green: 248/255, blue: 240/255)
            ) { _ in
                MoneyIcon(.leaf, size: 24)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 3)
        .padding(.horizontal, 16)
    }

    private func topDistrictPill<V: View>(
        id: String?,
        title: String,
        unselectedBg: Color = Color(red: 246/255, green: 247/255, blue: 250/255),
        @ViewBuilder icon: (Bool) -> V
    ) -> some View {
        let isSelected = (id == nil && selectedDistrict == nil) || (id != nil && selectedDistrict == id)
        return Button(action: {
            onSelectDistrict(id)
        }) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white : unselectedBg)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color(red: 24/255, green: 24/255, blue: 27/255) : Color.clear, lineWidth: 2.2)
                        )
                        .shadow(color: isSelected ? Color.black.opacity(0.12) : Color.clear, radius: 4, y: 2)
                        .scaleEffect(isSelected ? 1.06 : 1.0)

                    icon(isSelected)
                }

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? Color(red: 17/255, green: 24/255, blue: 39/255) : Color(red: 100/255, green: 116/255, blue: 139/255))

                // Crisp Minimal Selection Indicator
                if isSelected {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(red: 17/255, green: 24/255, blue: 39/255))
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
