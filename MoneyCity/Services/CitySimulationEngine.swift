import SwiftUI

/// Transforms raw financial transactions into an isometric 3D living diorama based on Behavioral World Generation ("Living Map").
public final class CitySimulationEngine: Sendable {
    public static let shared = CitySimulationEngine()
    
    private init() {}
    
    /// How much of a month's budget has been "earned" by the calendar so far: 0 on the
    /// first day, 1 for any month that has already ended.
    ///
    /// Completed days, not elapsed ones — nobody has saved anything on the morning of the
    /// first, and crediting a whole day before it has passed is how the fabricated figure
    /// crept in.
    static func budgetAccruedFraction(
        for monthDate: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> Double {
        // A month in the past is fully accrued; a month in the future has accrued nothing.
        if !calendar.isDate(monthDate, equalTo: now, toGranularity: .month) {
            return monthDate < now ? 1.0 : 0.0
        }
        guard let range = calendar.range(of: .day, in: .month, for: now), range.count > 0 else {
            return 1.0
        }
        let completedDays = calendar.component(.day, from: now) - 1
        return min(1.0, max(0.0, Double(completedDays) / Double(range.count)))
    }

    /// Spending the user does not decide on again each day.
    ///
    /// Rent lands in one lump on the 1st and subscriptions renew on their own. Judging a
    /// day-to-day pace against them means the garden is wrecked on the 3rd of every month
    /// and recovers by the 30th — which says nothing about how the person is doing, and is
    /// exactly the same shape whether they were careful or reckless in between.
    public static let committedCategories: Set<SpendingCategory> = [.housing, .subscriptions]

    /// Day-to-day money: the coffees, the deliveries, the impulse buys. This is what the
    /// garden is about.
    public static func isEverydaySpending(_ category: SpendingCategory) -> Bool {
        let c = category.canonical
        return c != .savings && !committedCategories.contains(c)
    }

    /// Everything the user has put aside since they started, across every month.
    ///
    /// The reserve is the one part of the city that is not scoped to a month. Every other
    /// district is rebuilt on the first, which is right for spending — last month's dinners
    /// are not this month's problem — but wrong for savings. A patch of protected land that
    /// vanishes every thirty days reads as a bug, not as a place, and it means a good year
    /// of habits shows exactly the same as a good week.
    ///
    /// So the months that have finished are banked and never revisited, and only the month
    /// in progress can still move. Within the current month the contribution can fall as the
    /// user spends, but it is floored at zero, so a bad month costs them this month's growth
    /// and nothing that came before it.
    public static func lifetimeSavings(
        allTransactions: [Transaction],
        monthlyBudget: Double,
        typicalMonthlySpend: Double,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Double {
        let baseline = monthlyBudget > 0 ? monthlyBudget : typicalMonthlySpend

        var byMonth: [Date: [Transaction]] = [:]
        for tx in allTransactions {
            guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: tx.timestamp))
            else { continue }
            byMonth[start, default: []].append(tx)
        }

        var total = 0.0
        for (monthStart, txs) in byMonth {
            let deposits = txs.filter { $0.category.canonical == .savings }.reduce(0.0) { $0 + $1.amount }
            let spent = txs.filter { $0.category.canonical != .savings }.reduce(0.0) { $0 + $1.amount }
            guard deposits > 0 || spent > 0 else { continue }

            var restraint = 0.0
            if baseline > 0 {
                let accrued = baseline * budgetAccruedFraction(for: monthStart, now: now, calendar: calendar)
                restraint = max(0.0, accrued - spent - deposits)
            }
            total += deposits + restraint
        }
        return total
    }

    /// Builds the MonthlyCity model with dynamic tile scaling, building breakdowns, and behavioral habit analysis.
    /// A park that is being looked after normally. Spending below your pace lifts it toward 1,
    /// overspending pulls it down. This is the state a brand-new city opens in.
    public static let healthyParkLevel: Double = 0.78

    /// What the savings park is actually measuring this month, so the app can say it plainly
    /// instead of showing a number with no explanation.
    public enum SavingsBasis: String, Sendable {
        case deposits        // only money the user actually moved into savings
        case underBudget     // a budget or income exists, and spending is below its accrued share
        case belowUsual      // no budget, but this month is running below the user's own average
        case noBaseline      // first month with nothing to compare against
    }

    public func generateCity(
        for monthDate: Date,
        transactions: [Transaction],
        estimatedMonthlyBudget: Double = 0,
        typicalMonthlySpend: Double = 0,
        typicalEverydaySpend: Double = 0,
        typicalCommittedSpend: Double = 0,
        lifetimeSavings: Double = 0,
        now: Date = Date()
    ) -> MonthlyCity {
        var totals: [SpendingCategory: Double] = [:]
        for cat in SpendingCategory.allCases {
            totals[cat] = 0.0
        }
        
        var buildingTotals: [String: Double] = [
            "food_bistro": 0.0,
            "food_super": 0.0,
            "food_coffee": 0.0,
            "food_wolt": 0.0,
            "shop_boutique": 0.0,
            "shop_tech": 0.0,
            "shop_travel": 0.0,
            "shop_arcade": 0.0,
            "trans_station": 0.0,
            "house_tower": 0.0,
            "house_util": 0.0,
            "house_subs": 0.0,
            "savings_sanctuary": 0.0
        ]
        
        var woltCount = 0
        var coffeeCount = 0
        var onlinePkgCount = 0
        var hasTravel = false
        var activeSubs = 0
        var groceryBags = 0
        
        for t in transactions {
            totals[t.category, default: 0.0] += t.amount
            let bId = t.buildingId
            buildingTotals[bId, default: 0.0] += t.amount
            
            let m = t.merchant.lowercased()
            if bId == "food_wolt" || m.contains("wolt") || m.contains("וולט") || m.contains("10bis") || m.contains("תן ביס") {
                woltCount += 1
            }
            if bId == "food_coffee" || t.category == .coffee || m.contains("aroma") || m.contains("קפה") || m.contains("cafe") || m.contains("ארומה") {
                coffeeCount += 1
            }
            if bId == "shop_tech" || m.contains("amazon") || m.contains("אמזון") || m.contains("asos") || m.contains("ksp") || m.contains("aliexpress") {
                onlinePkgCount += 1
            }
            if bId == "shop_travel" || m.contains("flight") || m.contains("טיסה") || m.contains("el al") || m.contains("אל על") || m.contains("airbnb") || m.contains("booking") || m.contains("hotel") {
                hasTravel = true
            }
            if bId == "house_subs" || t.category == .subscriptions || m.contains("netflix") || m.contains("spotify") || m.contains("apple") {
                activeSubs += 1
            }
            if bId == "food_super" || t.category == .groceries || m.contains("שופרסל") || m.contains("רמי לוי") || m.contains("סופר") {
                groceryBags += max(1, Int(t.amount / 120))
            }
        }
        
        let spendingTransactions = transactions.filter { $0.category != .savings }
        let totalSpent = spendingTransactions.reduce(0.0) { $0 + $1.amount }
        let directSavings = totals[.savings] ?? 0.0

        // Unspent budget only counts for the part of the month that has actually gone by,
        // and only once the month has something recorded in it.
        //
        // The old line credited the entire monthly budget the instant the month began, so
        // a brand-new user with no transactions opened the app to a fully grown savings
        // park and a five-figure "saved" number they had not earned — the one figure the
        // app is proudest of, fabricated on day one. Accruing it day by day turns the same
        // mechanic into something true: the park grows through the month as the user
        // underspends, and starts at nothing.
        //
        // Money moved into savings has already left the budget, so it is subtracted before
        // being added back — otherwise every deposit is counted twice.
        // The park used to grow only from unspent budget, which meant it stayed empty for anyone
        // who never entered an income: with no budget there is no baseline, so spending little
        // could not register as restraint. It now falls back to the user's own history, which
        // needs no setup and calibrates itself.
        let accruedFraction = CitySimulationEngine.budgetAccruedFraction(for: monthDate, now: now)
        let hasActivity = !spendingTransactions.isEmpty || directSavings > 0

        var restraint = 0.0
        var basis: SavingsBasis = directSavings > 0 ? .deposits : .noBaseline
        var baseline = 0.0

        if estimatedMonthlyBudget > 0 {
            baseline = estimatedMonthlyBudget
            let accrued = estimatedMonthlyBudget * accruedFraction
            restraint = hasActivity ? max(0.0, accrued - totalSpent - directSavings) : 0.0
            basis = .underBudget
        } else if typicalMonthlySpend > 0 {
            // No budget, but the user has months behind them. Running below your own usual pace
            // is restraint, and it is a fair thing to reward.
            baseline = typicalMonthlySpend
            let expectedByNow = typicalMonthlySpend * accruedFraction
            restraint = hasActivity ? max(0.0, expectedByNow - totalSpent - directSavings) : 0.0
            basis = .belowUsual
        }

        let totalSavings = restraint + directSavings

        // ── How the park LOOKS, which is a different question from how much was saved ────────
        //
        // The park used to accumulate from nothing: a new city opened onto bare ground and
        // stayed bare until the user configured a budget. That is backwards. A city being looked
        // after normally should look well kept, and the park should move in both directions from
        // there — spending below your pace makes it flourish, overspending lets it go.
        //
        // So health is not the saved amount. It is where this month's pace sits relative to
        // normal, and "normal" is a healthy, planted park.
        // ── The garden judges day-to-day money only ─────────────────────────────────────
        //
        // It used to compare everything spent against a budget accruing evenly by the day.
        // Rent breaks that comparison completely: it lands on the 1st, so by the 3rd the
        // month has "earned" two days of budget and been handed a whole month's rent. On a
        // 9,000 budget with 4,200 rent that reads as three times the pace by the 7th and the
        // garden is dead from then until the 20th — every month, however careful the person
        // was with the money they actually chose to spend.
        //
        // Both sides of the comparison are now day-to-day: what was spent on everyday things,
        // against the part of the plan that is not already committed to rent and subscriptions.
        let everydaySpent = spendingTransactions
            .filter { CitySimulationEngine.isEverydaySpending($0.category) }
            .reduce(0.0) { $0 + $1.amount }
        let committedSpent = max(0.0, totalSpent - everydaySpent)

        // What this user's fixed costs usually come to. Their own history first, because it
        // is steady and known from day one; this month's figure only until there is history,
        // since before the rent lands it reads as zero and would flatter the pace.
        let committedAllowance = typicalCommittedSpend > 0 ? typicalCommittedSpend : committedSpent

        var everydayBaseline = 0.0
        if estimatedMonthlyBudget > 0 {
            // A fifth of the budget is kept as a floor: if the fixed costs swallow almost all
            // of it, the remainder is still a real target rather than an unmeetable zero.
            everydayBaseline = max(estimatedMonthlyBudget * 0.20,
                                   estimatedMonthlyBudget - committedAllowance)
        } else if typicalEverydaySpend > 0 {
            everydayBaseline = typicalEverydaySpend
        } else if typicalMonthlySpend > 0 {
            everydayBaseline = max(0.0, typicalMonthlySpend - committedAllowance)
        }

        var parkHealth = CitySimulationEngine.healthyParkLevel
        let expectedByNow = everydayBaseline * accruedFraction
        if everydayBaseline > 0, expectedByNow > 0, hasActivity {
            let pace = everydaySpent / expectedByNow
            if pace <= 1.0 {
                // Under your pace. Fully lush once you are 40% below it.
                let good = min(1.0, (1.0 - pace) / 0.40)
                parkHealth = CitySimulationEngine.healthyParkLevel
                    + (1.0 - CitySimulationEngine.healthyParkLevel) * good
            } else {
                // Over it. Bottoms out at twice your pace, and never quite reaches nothing —
                // a dead park is a punishment, not information.
                let bad = min(1.0, (pace - 1.0) / 1.0)
                parkHealth = CitySimulationEngine.healthyParkLevel
                    - (CitySimulationEngine.healthyParkLevel - 0.12) * bad
            }
        }
        // The first days of a month cannot support a verdict. On the 2nd, one day of budget is
        // all that has accrued, so a single grocery run reads as triple the pace and the park
        // browns overnight — which is what made it feel disconnected from anything the user did.
        // Until roughly the first week is behind us the verdict is blended back towards normal,
        // so the park settles into its judgement instead of lurching into one.
        let verdictConfidence = min(1.0, accruedFraction / 0.20)
        parkHealth = CitySimulationEngine.healthyParkLevel
            + (parkHealth - CitySimulationEngine.healthyParkLevel) * verdictConfidence

        // Money actually moved into savings always helps, whatever the spending looked like.
        if directSavings > 0 {
            let depositTarget = everydayBaseline > 0 ? everydayBaseline * 0.15 : max(directSavings, 1.0)
            parkHealth = min(1.0, parkHealth + 0.22 * min(1.0, directSavings / depositTarget))
        }
        // A full park means roughly a fifth of a month kept back — generous but reachable —
        // rather than an arbitrary fixed figure.
        let savingsTarget = baseline > 0 ? baseline * 0.20 : 0.0

        // Everything put aside since the user started. This is a figure the reserve's card
        // reports; it deliberately does not touch how the garden looks, because the garden is
        // about this month and mixing the two is what made it unreadable.
        let reserve = max(lifetimeSavings, totalSavings)
        buildingTotals["savings_sanctuary"] = totalSavings
        
        let highestCategory = totals.filter { $0.key != .savings && $0.key != .other }
            .max(by: { $0.value < $1.value })?.key ?? .food
        
        let habits = BehavioralHabits(
            woltDeliveryCount: woltCount,
            coffeeCount: coffeeCount,
            onlinePackagesCount: onlinePkgCount,
            hasTravelOrFlight: hasTravel,
            activeSubscriptionsCount: activeSubs,
            totalGroceryBags: groceryBags
        )
        
        var tiles: [BuildingTile] = []
        
        // Savings Park
        // Measured against the same target the park uses, so the tile and the 3D scene agree.
        let savingsRatio = savingsTarget > 0 ? min(1.0, totalSavings / savingsTarget)
                                             : (totalSavings > 0 ? 0.5 : 0.0)
        tiles.append(BuildingTile(
            id: 0,
            category: .savings,
            title: "שמורת חיסכון",
            spendingAmount: totalSavings,
            level: Int(savingsRatio * 4) + 1,
            heightScale: 0.4,
            gridX: 0,
            gridY: 0,
            floatingTag: "SAVINGS PARK"
        ))
        
        // Food District Tile
        let foodSpend = (totals[.food] ?? 0) + (totals[.groceries] ?? 0) + (totals[.coffee] ?? 0)
        tiles.append(BuildingTile(
            id: 1,
            category: .food,
            title: "רובע האוכל",
            spendingAmount: foodSpend,
            level: min(5, Int(foodSpend / 300) + 1),
            heightScale: foodSpend > 800 ? 2.2 : 1.2,
            gridX: 1,
            gridY: 0,
            floatingTag: "FOOD DISTRICT"
        ))
        
        // Transport Tile
        let transportSpend = totals[.transport] ?? 0.0
        tiles.append(BuildingTile(
            id: 2,
            category: .transport,
            title: "תחבורה ורכב",
            spendingAmount: transportSpend,
            level: 2,
            heightScale: 0.2,
            gridX: 2,
            gridY: 0,
            hasRoad: true,
            hasTaxi: true,
            floatingTag: "MOBILITY"
        ))
        
        // Shopping Tile
        let shopSpend = (totals[.shopping] ?? 0) + (totals[.entertainment] ?? 0)
        tiles.append(BuildingTile(
            id: 3,
            category: .shopping,
            title: "מסחר ובוטיק",
            spendingAmount: shopSpend,
            level: min(5, Int(shopSpend / 400) + 1),
            heightScale: shopSpend > 600 ? 1.8 : 1.0,
            gridX: 3,
            gridY: 0,
            floatingTag: "SHOPPING"
        ))
        
        // Housing / Residence Tile
        let houseSpend = (totals[.housing] ?? 0) + (totals[.subscriptions] ?? 0)
        tiles.append(BuildingTile(
            id: 4,
            category: .housing,
            title: "מגדל מגורים",
            spendingAmount: houseSpend,
            level: 4,
            heightScale: 2.2,
            gridX: 0,
            gridY: 1,
            floatingTag: "RESIDENCE"
        ))
        
        let story = generateHeadlineStory(highestCat: highestCategory, totalSpent: totalSpent, totalSavings: totalSavings, habits: habits)
        
        return MonthlyCity(
            monthDate: monthDate,
            totalSpent: totalSpent,
            totalSavings: totalSavings,
            savingsTarget: savingsTarget,
            savingsBasis: basis,
            parkHealth: parkHealth,
            lifetimeSavings: reserve,
            everydaySpent: everydaySpent,
            everydayBaseline: everydayBaseline,
            categoryTotals: totals,
            buildingTotals: buildingTotals,
            tiles: tiles,
            headlineStory: story,
            habits: habits
        )
    }
    
    private func generateHeadlineStory(highestCat: SpendingCategory, totalSpent: Double, totalSavings: Double, habits: BehavioralHabits) -> String {
        if totalSpent == 0 {
            return "העיר פתוחה ורעננה — טרם נרשמו הוצאות החודש."
        }
        var highlights: [String] = []
        if habits.woltDeliveryCount >= 10 {
            highlights.append("\(habits.woltDeliveryCount) משלוחי Wolt ברחובות")
        }
        if habits.coffeeCount >= 8 {
            highlights.append("\(habits.coffeeCount) כוסות קפה בבתי הקפה")
        }
        if habits.onlinePackagesCount >= 3 {
            highlights.append("\(habits.onlinePackagesCount) חבילות בפתח המגדל")
        }
        
        let habitString = highlights.joined(separator: " • ")
        return habitString.isEmpty
            ? "הוצאה מרכזית ב\(highestCat.displayName) לצד ₪\(Int(totalSavings)) שנשמרו בפארק החיסכון."
            : "\(habitString) • ₪\(Int(totalSavings)) נשמרו בטבע"
    }
}
