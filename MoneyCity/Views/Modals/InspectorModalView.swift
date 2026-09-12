import SwiftUI

/// Floating spatial building inspector modal
public struct InspectorModalView: View {
    public let info: DistrictBuildingInfo
    public let onClose: () -> Void
    public let onShowFeed: () -> Void
    @EnvironmentObject private var l10n: LocalizationManager

    public init(
        info: DistrictBuildingInfo,
        onClose: @escaping () -> Void,
        onShowFeed: @escaping () -> Void
    ) {
        self.info = info
        self.onClose = onClose
        self.onShowFeed = onShowFeed
    }
    
    private var isSortingHub: Bool {
        info.id == "city_sorting_hub"
    }
    
    private var localizedBuildingTitle: String {
        let isHe = l10n.language == .hebrew
        switch info.id {
        case "food_bistro": return isHe ? "מסעדות" : "Restaurants"
        case "food_super": return isHe ? "סופר ומכולת" : "Supermarket & Groceries"
        case "food_coffee": return isHe ? "בתי קפה" : "Cafes"
        case "food_wolt": return isHe ? "משלוחי אוכל" : "Food Delivery"
        case "shop_boutique": return isHe ? "ביגוד ואופנה" : "Fashion & Boutique"
        case "shop_tech": return isHe ? "טכנולוגיה וחשמל" : "Electronics & Tech"
        case "shop_travel": return isHe ? "חופשות וטיסות" : "Travel & Vacations"
        case "shop_arcade": return isHe ? "בידור ופנאי" : "Entertainment"
        case "house_tower": return isHe ? "שכירות ודיור" : "Rent & Housing"
        case "house_util": return isHe ? "חשבונות הבית" : "Utilities & Bills"
        case "house_subs": return isHe ? "מנויים" : "Subscriptions"
        case "savings_sanctuary": return isHe ? "הפארק" : "The Park"
        case "trans_station": return isHe ? "תחבורה וחניה" : "Transit & Parking"
        case "health_pharmacy": return isHe ? "פארם ובריאות" : "Health & Pharmacy"
        case "finance_bank": return isHe ? "בנקאות ועמלות" : "Banking & Finance"
        case "museum_curiosities": return isHe ? "שונות" : "Miscellaneous"
        case "city_sorting_hub": return isHe ? "עסקאות שמחכות לסיווג" : "Transactions to Categorize"
        default:
            return info.name
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            
            if isSortingHub {
                HStack(spacing: 8) {
                    MoneyIcon(.shoppingBag, size: 14)
                    Text(l10n.language == .hebrew ? "עסקאות ללא קטגוריה מצטברות כאן. לחץ לסיווג מהיר לקטגוריה הנכונה." : "Uncategorized transactions gather here. Tap to triage and send funds to their buildings.")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 120/255, green: 53/255, blue: 15/255))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(Color(red: 254/255, green: 243/255, blue: 199/255).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            
            Divider().background(Color(red: 243/255, green: 244/255, blue: 246/255))
            trendRow
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 4)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            onShowFeed()
        }
    }
    
    private var headerRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isSortingHub ? Color(red: 254/255, green: 243/255, blue: 199/255) : Color(red: 241/255, green: 245/255, blue: 249/255))
                    .frame(width: 44, height: 44)
                if isSortingHub {
                    MoneyIcon(.mail, size: 24)
                } else {
                    buildingVectorIcon(info.id, size: 24)
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(localizedBuildingTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                if isSortingHub {
                    if info.amount > 0 {
                        Text("\(l10n.format(amount: info.amount)) \(l10n.language == .hebrew ? "לסיווג" : "to categorize") • \(info.visitCount) \(l10n.language == .hebrew ? "עסקאות" : "transactions")")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 234/255, green: 88/255, blue: 12/255))
                    } else {
                        HStack(spacing: 4) {
                            MoneyIcon(.checkCircle, size: 14)
                            Text(l10n.language == .hebrew ? "הכול מסווג ומסודר!" : "All sorted & clean!")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        }
                    }
                } else if info.amount > 0 {
                    Text("\(l10n.format(amount: info.amount)) \(l10n.language == .hebrew ? "החודש" : "this month") • \(info.visitCount) \(l10n.language == .hebrew ? "פעולות" : "items")")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.primaryBlue)
                } else {
                    Text(l10n.language == .hebrew ? "ללא הוצאות החודש • \(l10n.format(amount: 0))" : "No expenses this month • \(l10n.baseCurrency.symbol)0")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textMuted)
                }
            }
            
            Spacer()
            
            Button(action: onClose) {
                MoneyIcon(.xmarkCircle, size: 20)
                    .frame(width: 32, height: 32)
                    .background(Color.appBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .highPriorityGesture(TapGesture().onEnded { onClose() })
        }
    }
    
    private var trendRow: some View {
        HStack(spacing: 8) {
            Text(l10n.language == .hebrew ? "סטטוס:" : "Status:")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Color.textMuted)
            Text(isSortingHub ? (info.amount > 0 ? (l10n.language == .hebrew ? "ממתין לסיווג" : "Pending Categorization") : (l10n.language == .hebrew ? "הכול מסווג" : "All Categorized")) : (info.amount > 0 ? info.trendText : (l10n.language == .hebrew ? "לא נרשמו הוצאות כאן החודש" : "No expenses recorded here this month")))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(info.amount > 0 ? (isSortingHub ? Color(red: 234/255, green: 88/255, blue: 12/255) : Color.themeMint) : Color.textMuted)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: onShowFeed) {
                HStack(spacing: 5) {
                    Text(isSortingHub ? (l10n.language == .hebrew ? "סווג עסקאות" : "Categorize") : (l10n.language == .hebrew ? "עסקאות" : "History"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Text(verbatim: l10n.language == .hebrew ? "‹" : "›")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSortingHub ? Color(red: 234/255, green: 88/255, blue: 12/255) : Color.primaryBlue)
                .clipShape(Capsule())
                .shadow(color: (isSortingHub ? Color(red: 234/255, green: 88/255, blue: 12/255) : Color.primaryBlue).opacity(0.25), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .bouncyPress(scale: 0.94)
        }
    }
}
