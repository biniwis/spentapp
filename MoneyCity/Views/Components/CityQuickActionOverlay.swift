import SwiftUI

public enum CityQuickActionHelper {
    public static func dynamicTopBuildings(from allTransactions: [Transaction]) -> [CityBuilding] {
        var counts: [String: Int] = [:]
        for tx in allTransactions {
            let m = "\(tx.merchant) \(tx.note ?? "")".lowercased()
            let bId = tx.buildingId

            // Accurately resolve transaction to specific everyday subcategory
            let resolvedId: String
            if tx.category == .food || tx.category == .groceries || tx.category == .coffee {
                if bId == "food_super" || m.contains("סופר") || m.contains("super") || m.contains("שופרסל") || m.contains("רמי לוי") || m.contains("מכולת") || m.contains("יוחננוף") || m.contains("ויקטורי") || m.contains("אושר עד") || m.contains("קרפור") || m.contains("am:pm") {
                    resolvedId = "food_super"
                } else if bId == "food_coffee" || m.contains("קפה") || m.contains("cafe") || m.contains("coffee") || m.contains("ארומה") || m.contains("aroma") || m.contains("גולדה") || m.contains("מאפיה") || m.contains("מאפיית") || m.contains("bakery") || m.contains("לנדוור") || m.contains("ארקפה") {
                    resolvedId = "food_coffee"
                } else if bId == "food_wolt" || m.contains("wolt") || m.contains("וולט") || m.contains("10bis") || m.contains("תן ביס") || m.contains("tabit") || m.contains("משלוח") {
                    resolvedId = "food_wolt"
                } else {
                    resolvedId = "food_bistro"
                }
            } else if tx.category == .transport {
                resolvedId = "trans_station"
            } else if tx.category == .shopping {
                if bId == "shop_tech" || m.contains("חשמל") || m.contains("ksp") || m.contains("ivory") || m.contains("מחשב") || m.contains("באג") {
                    resolvedId = "shop_tech"
                } else {
                    resolvedId = "shop_boutique"
                }
            } else if tx.category == .health {
                resolvedId = "health_pharmacy"
            } else {
                resolvedId = bId
            }

            if resolvedId != "city_sorting_hub" && CityBuilding.find(id: resolvedId) != nil {
                counts[resolvedId, default: 0] += 1
            }
        }

        // Ordered priority fallbacks when counts are equal or zero:
        // 1. Supermarket, 2. Cafes, 3. Restaurants, 4. Food Delivery, 5. Transit, 6. Fashion
        let fallbackOrder = [
            "food_super",      // סופרמרקט
            "food_coffee",     // בתי קפה
            "food_bistro",     // מסעדות
            "food_wolt",       // משלוחי אוכל
            "trans_station",   // תחבורה ודלק
            "shop_boutique",   // ביגוד ואופנה
            "health_pharmacy", // פארם ובריאות
            "shop_tech"        // טכנולוגיה
        ]

        var candidates = Array(counts.keys)
        for fb in fallbackOrder {
            if !candidates.contains(fb) {
                candidates.append(fb)
            }
        }

        let sortedIds = candidates.sorted { id1, id2 in
            let c1 = counts[id1, default: 0]
            let c2 = counts[id2, default: 0]
            if c1 != c2 {
                return c1 > c2
            }
            let idx1 = fallbackOrder.firstIndex(of: id1) ?? 999
            let idx2 = fallbackOrder.firstIndex(of: id2) ?? 999
            if idx1 != idx2 {
                return idx1 < idx2
            }
            return id1 < id2
        }

        var result: [CityBuilding] = []
        for bId in sortedIds {
            if let b = CityBuilding.find(id: bId) {
                result.append(b)
                if result.count == 3 {
                    break
                }
            }
        }
        return result
    }
}

public struct QuickActionBuildingPickerBar: View {
    public let buildings: [CityBuilding]
    public let onSelect: (CityBuilding) -> Void
    @EnvironmentObject private var l10n: LocalizationManager

    public init(buildings: [CityBuilding], onSelect: @escaping (CityBuilding) -> Void) {
        self.buildings = buildings
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(buildings) { building in
                Button(action: {
                    Haptics.impact(.light)
                    onSelect(building)
                }) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(building.category.softBackgroundColor)
                            .frame(width: 28, height: 28)
                            .overlay(
                                MoneyIcon(building.iconType, size: 16)
                            )

                        Text(building.shortName(for: l10n.language))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 14)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.borderSubtle.opacity(0.8), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 3)
                }
                .bouncyPress(scale: 0.94)
            }
        }
        .padding(.bottom, 6)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.75, anchor: .bottom).combined(with: .opacity).combined(with: .move(edge: .bottom)),
            removal: .scale(scale: 0.85, anchor: .bottom).combined(with: .opacity)
        ))
    }
}

public struct BigQuickAmountOverlay: View {
    public let building: CityBuilding
    @Binding public var amountText: String
    public let onClose: () -> Void
    public let onSubmit: () -> Void
    @EnvironmentObject private var l10n: LocalizationManager

    public init(
        building: CityBuilding,
        amountText: Binding<String>,
        onClose: @escaping () -> Void,
        onSubmit: @escaping () -> Void
    ) {
        self.building = building
        self._amountText = amountText
        self.onClose = onClose
        self.onSubmit = onSubmit
    }

    private let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]

    private var canSubmit: Bool {
        (Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    private var displayAmount: String {
        if amountText.isEmpty {
            return "0"
        }
        let parts = amountText.split(separator: ".", omittingEmptySubsequences: false)
        let intPart = String(parts[0])
        let formattedInt: String
        if let val = Double(intPart) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            formatter.maximumFractionDigits = 0
            formattedInt = formatter.string(from: NSNumber(value: val)) ?? intPart
        } else {
            formattedInt = intPart
        }
        if parts.count > 1 {
            return "\(formattedInt).\(parts[1])"
        } else if amountText.hasSuffix(".") {
            return "\(formattedInt)."
        } else {
            return formattedInt
        }
    }

    private func handleKeypad(_ key: String) {
        if key == "⌫" {
            Haptics.impact(.light)
            if !amountText.isEmpty {
                amountText.removeLast()
            }
        } else if key == "." {
            Haptics.selection()
            if !amountText.contains(".") {
                if amountText.isEmpty {
                    amountText = "0."
                } else {
                    amountText += "."
                }
            }
        } else {
            Haptics.impact(.light)
            if amountText == "0" {
                amountText = key
            } else {
                if let dot = amountText.firstIndex(of: ".") {
                    let decs = amountText.distance(from: dot, to: amountText.endIndex)
                    if decs <= 2 {
                        amountText += key
                    }
                } else if amountText.count < 7 {
                    amountText += key
                }
            }
        }
    }

    public var body: some View {
        ZStack {
            // Soft dark backdrop over the 3D diorama
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            // Clean Centered Quick Entry Card
            VStack(spacing: 16) {
                // 1. Header: Subcategory Icon + Title + Close Button
                HStack(spacing: 10) {
                    Circle()
                        .fill(building.category.softBackgroundColor)
                        .frame(width: 40, height: 40)
                        .overlay(
                            MoneyIcon(building.iconType, size: 22)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(building.displayName(for: l10n.language))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)

                        Text(building.category.displayName)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(building.category.themeColor)
                    }

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.textMuted)
                            .frame(width: 30, height: 30)
                            .background(Color(red: 245/255, green: 246/255, blue: 248/255))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                // 2. Large Amount Hero Display: ₪ [Amount]
                HStack(alignment: .center, spacing: 6) {
                    Text(l10n.baseCurrency.symbol)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)

                    Text(displayAmount)
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                // 3. Thumb-friendly Keypad (Flat style, no nested strokes)
                VStack(spacing: 8) {
                    ForEach(keys, id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(row, id: \.self) { key in
                                Button(action: {
                                    handleKeypad(key)
                                }) {
                                    ZStack {
                                        if key == "⌫" {
                                            MoneyIcon(.backspace, size: 20, color: Color.deepNavy)
                                        } else if key == "." {
                                            Text("•")
                                                .font(.system(size: 22, weight: .black, design: .rounded))
                                                .foregroundColor(Color.deepNavy)
                                        } else {
                                            Text(key)
                                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                                .foregroundColor(Color.deepNavy)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 46)
                                    .background(Color(red: 246/255, green: 247/255, blue: 249/255))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .bouncyPress(scale: 0.94)
                            }
                        }
                    }
                }

                // 4. Big Clean Confirm Button
                Button(action: onSubmit) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                        Text(l10n.language == .hebrew ? "שמור הוצאה" : "Save Expense")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(canSubmit ? MoneyCityTheme.jetBlack : Color.textMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canSubmit ? Color.spentGreen : Color.black.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .bouncyPress(scale: 0.94)
                .disabled(!canSubmit)
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.borderSubtle.opacity(0.6), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
