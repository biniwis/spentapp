import SwiftUI

public struct CitySpendingCard: View {
    public let currentCity: MonthlyCity
    public let selectedDistrict: String?
    @Binding public var isDetailsExpanded: Bool
    public let displayTransactions: [ExpenseSnapshot]
    public let onSelectDistrict: (String?) -> Void
    @EnvironmentObject private var l10n: LocalizationManager

    public init(
        currentCity: MonthlyCity,
        selectedDistrict: String?,
        isDetailsExpanded: Binding<Bool>,
        displayTransactions: [ExpenseSnapshot],
        onSelectDistrict: @escaping (String?) -> Void
    ) {
        self.currentCity = currentCity
        self.selectedDistrict = selectedDistrict
        self._isDetailsExpanded = isDetailsExpanded
        self.displayTransactions = displayTransactions
        self.onSelectDistrict = onSelectDistrict
    }

    public var body: some View {
        let displayTotal = max(currentCity.totalSpent, 1.0)

        let (badgeBg, title, subtitle, amount): (Color, String, String, Double) = {
            switch selectedDistrict {
            case "food":
                let amt = DistrictDataHelper.districtTotal(for: "food", currentCity: currentCity)
                let pct = currentCity.totalSpent > 0 ? Int(round((amt / displayTotal) * 100)) : 0
                return (Color(red: 254/255, green: 242/255, blue: 232/255),
                        l10n.language == .hebrew ? "רובע האוכל" : "Food District",
                        l10n.language == .hebrew ? "\(pct)% מההוצאות" : "\(pct)% of spending",
                        amt)
            case "shopping":
                let amt = DistrictDataHelper.districtTotal(for: "shopping", currentCity: currentCity)
                let pct = currentCity.totalSpent > 0 ? Int(round((amt / displayTotal) * 100)) : 0
                return (Color(red: 253/255, green: 238/255, blue: 244/255),
                        l10n.language == .hebrew ? "שדרת הקניות" : "Shopping District",
                        l10n.language == .hebrew ? "\(pct)% מההוצאות" : "\(pct)% of spending",
                        amt)
            case "housing":
                let amt = DistrictDataHelper.districtTotal(for: "housing", currentCity: currentCity)
                let pct = currentCity.totalSpent > 0 ? Int(round((amt / displayTotal) * 100)) : 0
                return (Color(red: 238/255, green: 245/255, blue: 254/255),
                        l10n.language == .hebrew ? "מתחם המגורים" : "Housing District",
                        l10n.language == .hebrew ? "\(pct)% מההוצאות" : "\(pct)% of spending",
                        amt)
            case "transport":
                let amt = DistrictDataHelper.districtTotal(for: "transport", currentCity: currentCity)
                let pct = currentCity.totalSpent > 0 ? Int(round((amt / displayTotal) * 100)) : 0
                return (Color(red: 235/255, green: 248/255, blue: 255/255),
                        l10n.language == .hebrew ? "מרכז התחבורה" : "Transport Hub",
                        l10n.language == .hebrew ? "\(pct)% מההוצאות" : "\(pct)% of spending",
                        amt)
            case "civic":
                let amt = DistrictDataHelper.districtTotal(for: "civic", currentCity: currentCity)
                let pct = currentCity.totalSpent > 0 ? Int(round((amt / displayTotal) * 100)) : 0
                return (Color(red: 243/255, green: 244/255, blue: 246/255),
                        l10n.language == .hebrew ? "רובע השירותים והעירייה" : "Civic & Services Hub",
                        l10n.language == .hebrew ? "\(pct)% מההוצאות" : "\(pct)% of spending",
                        amt)
            case "savings":
                return (Color(red: 234/255, green: 248/255, blue: 240/255),
                        l10n.natureReserveName,
                        l10n.language == .hebrew ? "יעדי חיסכון והשקעות" : "Savings & Investments",
                        currentCity.totalSavings)
            default:
                return (Color(red: 243/255, green: 244/255, blue: 246/255),
                        l10n.language == .hebrew ? "כל העיר" : "All City",
                        l10n.language == .hebrew ? "פירוט ההוצאות לפי רובע" : "Spending breakdown by district",
                        currentCity.totalSpent)
            }
        }()

        return VStack(spacing: 8) {
            // Header Row: Floating District Row (Reference Screen 1)
            Button(action: {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    isDetailsExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    // 42pt circular pastel badge
                    ZStack {
                        Circle()
                            .fill(badgeBg)
                            .frame(width: 42, height: 42)

                        if selectedDistrict == "shopping" {
                            DistrictBoutiqueVectorIcon(color: Color(red: 236/255, green: 72/255, blue: 153/255))
                                .scaleEffect(0.85)
                        } else if selectedDistrict == "housing" {
                            DistrictHousingVectorIcon(color: Color(red: 59/255, green: 130/255, blue: 246/255))
                                .scaleEffect(0.85)
                        } else if selectedDistrict == "savings" {
                            DistrictParkVectorIcon(color: Color(red: 16/255, green: 185/255, blue: 129/255))
                                .scaleEffect(0.85)
                        } else if selectedDistrict == "food" {
                            DistrictBistroVectorIcon(color: Color(red: 249/255, green: 115/255, blue: 22/255))
                                .scaleEffect(0.85)
                        } else if selectedDistrict == "transport" {
                            MoneyIcon(.car, size: 20, color: Color(red: 14/255, green: 165/255, blue: 233/255))
                        } else if selectedDistrict == "civic" {
                            MoneyIcon(.citySkyline, size: 20, color: Color(red: 100/255, green: 116/255, blue: 139/255))
                        } else {
                            DistrictSkylineVectorIcon(color: Color(red: 17/255, green: 24/255, blue: 39/255))
                                .scaleEffect(0.85)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)

                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(Color.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Text(l10n.formatScoped(amount: amount))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(Color.deepNavy)

                        MoneyIcon(isDetailsExpanded ? .chevronDown : (l10n.language == .hebrew ? .chevronLeft : .chevronRight), size: 12)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                isDetailsExpanded
                    ? (l10n.language == .hebrew ? "\(title), סגור פירוט הוצאות, \(l10n.formatScoped(amount: amount))" : "\(title), hide spending breakdown, \(l10n.formatScoped(amount: amount))")
                    : (l10n.language == .hebrew ? "\(title), הצג פירוט הוצאות, \(l10n.formatScoped(amount: amount))" : "\(title), show spending breakdown, \(l10n.formatScoped(amount: amount))")
            )
            .accessibilityHint(
                isDetailsExpanded
                    ? (l10n.language == .hebrew ? "הקש לסגירת פירוט הרובעים" : "Tap to hide district breakdown")
                    : (l10n.language == .hebrew ? "הקש להצגת פירוט הרובעים" : "Tap to view district breakdown")
            )
            .accessibilityAddTraits(.isButton)

            // Contextual Month Milestone
            if displayTransactions.isEmpty {
                HStack(spacing: 6) {
                    MoneyIcon(.leaf, size: 14)
                    Text(l10n.language == .hebrew ? "חודש חדש בעיר" : "A new month in the city")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.top, 1)
            } else if displayTransactions.count == 1 {
                HStack(spacing: 6) {
                    MoneyIcon(.home, size: 14)
                    Text(l10n.language == .hebrew ? "הוצאה ראשונה שנרשמה החודש" : "First expense recorded this month")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.top, 1)
            }

            // District Details (Expanded only on tap!)
            if isDetailsExpanded {
                Divider().background(Color.borderSubtle)

                if currentCity.totalSpent <= 0 {
                    HStack(spacing: 8) {
                        DistrictSkylineVectorIcon(color: Color.textMuted)
                            .frame(width: 18, height: 18)
                            .scaleEffect(0.75)
                        Text(l10n.language == .hebrew ? "טרם נרשמו הוצאות החודש" : "No expenses recorded this month")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.textSecondary)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .transition(.opacity)
                } else {
                    let breakdownItems = DistrictDataHelper.expenseBreakdown(for: currentCity, language: l10n.language)
                    VStack(spacing: 4) {
                        ForEach(Array(breakdownItems.enumerated()), id: \.element.id) { index, item in
                            if index > 0 {
                                Divider().background(Color.borderSubtle)
                            }

                            districtRow(
                                bgColor: item.bgColor,
                                title: item.title,
                                amount: item.amount,
                                percentage: item.percentage,
                                icon: { MoneyIcon(item.iconType, size: 22) }
                            ) {
                                if let dist = item.districtId {
                                    onSelectDistrict(dist)
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.045), radius: 14, x: 0, y: 3)
        .padding(.horizontal, 16)
    }

    private func districtRow<V: View>(
        bgColor: Color,
        title: String,
        amount: Double,
        percentage: Int,
        @ViewBuilder icon: () -> V,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(bgColor)
                        .frame(width: 34, height: 34)

                    icon()
                }

                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                Spacer()

                Text(l10n.formatScoped(amount: amount))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                Text("\(percentage)%")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.textMuted)
                    .frame(width: 34, alignment: .trailing)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
