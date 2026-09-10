import SwiftUI

public struct DistrictDeepDiveCard: View {
    public let districtId: String
    public let onBack: () -> Void
    public let onSelectBuilding: (DistrictBuildingInfo) -> Void
    public let pills: [BuildingPillItem]
    public let total: Double
    @EnvironmentObject private var l10n: LocalizationManager

    public init(
        districtId: String,
        onBack: @escaping () -> Void,
        onSelectBuilding: @escaping (DistrictBuildingInfo) -> Void,
        pills: [BuildingPillItem],
        total: Double
    ) {
        self.districtId = districtId
        self.onBack = onBack
        self.onSelectBuilding = onSelectBuilding
        self.pills = pills
        self.total = total
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── Header: district name + total + back ──
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(districtTitle)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    Text(l10n.format(amount: total))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.primaryBlue)
                }

                Spacer()

                Button(action: onBack) {
                    HStack(spacing: 5) {
                        MoneyIcon(.citySkyline, size: 13)
                        Text(l10n.language == .hebrew ? "חזרה" : "Back")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(red: 17/255, green: 24/255, blue: 39/255))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .bouncyPress(scale: 0.94)
            }

            // ── Building rows: tap → open building card ──
            VStack(spacing: 0) {
                ForEach(pills) { pill in
                    Button(action: { onSelectBuilding(pill.info) }) {
                        HStack(spacing: 12) {
                            buildingVectorIcon(pill.id, size: 16)
                                .frame(width: 28, height: 28)
                                .background(Color(red: 248/255, green: 250/255, blue: 252/255))
                                .clipShape(Circle())

                            Text(pill.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.deepNavy)

                            Spacer()

                            if pill.amount > 0 {
                                Text(l10n.format(amount: pill.amount))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.textSecondary)
                            }

                            MoneyIcon(.chevronRight, size: 11)
                                .foregroundColor(Color.textMuted)
                        }
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)

                    if pill.id != pills.last?.id {
                        Divider().opacity(0.5)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 14, y: 4)
        .padding(.horizontal, 16)
    }

    private var districtTitle: String {
        let isHebrew = l10n.language == .hebrew
        switch districtId {
        case "food":     return isHebrew ? "רובע האוכל" : "Food District"
        case "shopping": return isHebrew ? "שדרת הקניות" : "Shopping District"
        case "housing":  return isHebrew ? "מתחם המגורים" : "Housing District"
        case "savings":  return isHebrew ? "שמורת הטבע" : "Savings Sanctuary"
        case "transport": return isHebrew ? "מרכז התחבורה" : "Transport Hub"
        default:         return isHebrew ? "רובע בעיר" : "City District"
        }
    }
}
