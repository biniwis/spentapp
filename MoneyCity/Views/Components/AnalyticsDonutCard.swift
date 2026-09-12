import SwiftUI

public struct AnalyticsCategoryTotal: Identifiable {
    public var id: String { category.rawValue }
    public let category: SpendingCategory
    public let amount: Double
    public let fraction: Double

    public init(category: SpendingCategory, amount: Double, fraction: Double) {
        self.category = category
        self.amount = amount
        self.fraction = fraction
    }
}

public struct AnalyticsDonutCard: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let categoryTotals: [AnalyticsCategoryTotal]
    let totalSpent: Double
    let displayTransactions: [Transaction]
    @Binding var selectedSlice: SpendingCategory?
    let countsTowardStats: (Transaction) -> Bool

    public init(
        categoryTotals: [AnalyticsCategoryTotal],
        totalSpent: Double,
        displayTransactions: [Transaction],
        selectedSlice: Binding<SpendingCategory?>,
        countsTowardStats: @escaping (Transaction) -> Bool
    ) {
        self.categoryTotals = categoryTotals
        self.totalSpent = totalSpent
        self.displayTransactions = displayTransactions
        self._selectedSlice = selectedSlice
        self.countsTowardStats = countsTowardStats
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            donutCardHeader
            donutView
            donutLegendView
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.035), radius: 10, y: 3)
    }

    private var donutCardHeader: some View {
        HStack {
            HStack(spacing: 6) {
                MoneyIcon(.pieChart, size: 16, color: Color.deepNavy)
                Text(l10n.language == .hebrew ? "התפלגות הוצאות" : "Spending Breakdown")
                    .font(.system(size: 16, weight: .bold, design: .default))
                    .foregroundColor(Color.deepNavy)
            }

            Spacer()

            if selectedSlice != nil {
                Button(action: {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedSlice = nil
                    }
                }) {
                    Text(l10n.language == .hebrew ? "איפוס" : "Reset")
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(Color.textSecondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Color(uiColor: .systemGray6))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var donutSlices: [DonutSliceData] {
        guard !categoryTotals.isEmpty else { return [] }
        let totalAmt = max(categoryTotals.reduce(0.0) { $0 + $1.amount }, 1.0)
        let gap: Double = categoryTotals.count > 1 ? 2.5 : 0.0
        var currentAngle: Double = -90.0

        var slices: [DonutSliceData] = []
        for item in categoryTotals {
            let sweep = (item.amount / totalAmt) * 360.0
            let rawStart = currentAngle
            let rawEnd = currentAngle + sweep

            let sAngle = rawStart + (gap / 2.0)
            let eAngle = rawEnd - (gap / 2.0)
            let validEnd = max(sAngle, eAngle)

            let txCount = displayTransactions.filter { countsTowardStats($0) && $0.category.canonical == item.category.canonical }.count

            slices.append(DonutSliceData(
                id: item.category.rawValue,
                category: item.category,
                name: item.category.displayName,
                icon: nil,
                color: item.category.themeColor,
                amount: item.amount,
                fraction: item.fraction,
                count: txCount,
                startAngle: sAngle,
                endAngle: validEnd,
                rawStartAngle: rawStart,
                rawEndAngle: rawEnd
            ))
            currentAngle += sweep
        }
        return slices
    }

    private var donutView: some View {
        let diameter: CGFloat = 185

        return ZStack {
            Circle()
                .stroke(Color(uiColor: .systemGray6).opacity(0.85), lineWidth: 21)
                .frame(width: diameter, height: diameter)

            ForEach(donutSlices) { slice in
                let isSelected = selectedSlice == slice.category
                let isDimmed = selectedSlice != nil && !isSelected

                DonutArcShape(startAngle: slice.startAngle, endAngle: slice.endAngle)
                    .stroke(
                        slice.color,
                        style: StrokeStyle(lineWidth: isSelected ? 26 : 21, lineCap: .butt)
                    )
                    .frame(width: diameter, height: diameter)
                    .opacity(isDimmed ? 0.35 : 1.0)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
            }

            if donutSlices.count > 1 {
                ForEach(donutSlices) { slice in
                    DonutRadialSeparator(angle: slice.rawEndAngle)
                        .stroke(Color.white, lineWidth: 1.5)
                        .frame(width: diameter, height: diameter)
                }
            }

            donutCenterHub
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .onTapGesture(coordinateSpace: .local) { location in
            handleDonutTap(at: location, diameter: diameter)
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func handleDonutTap(at location: CGPoint, diameter: CGFloat) {
        let center = CGPoint(x: diameter / 2, y: diameter / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let dist = sqrt(dx * dx + dy * dy)

        if dist <= 52 || dist > (diameter / 2 + 18) {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedSlice = nil
            }
            return
        }

        let slices = donutSlices
        guard !slices.isEmpty else { return }

        let radius = max((diameter - 30) / 2, 10)
        var hitSlice: DonutSliceData? = nil
        for slice in slices {
            var path = Path()
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(slice.startAngle),
                endAngle: .degrees(slice.endAngle),
                clockwise: false
            )
            let strokePath = path.strokedPath(StrokeStyle(lineWidth: 36, lineCap: .butt))
            if strokePath.contains(location) {
                hitSlice = slice
                break
            }
        }

        if hitSlice == nil {
            var angleDeg = atan2(dy, dx) * 180.0 / .pi
            if angleDeg < -90.0 {
                angleDeg += 360.0
            }
            for (index, slice) in slices.enumerated() {
                let isLast = (index == slices.count - 1)
                let matches = isLast
                    ? (angleDeg >= slice.rawStartAngle && angleDeg <= slice.rawEndAngle + 0.5)
                    : (angleDeg >= slice.rawStartAngle && angleDeg < slice.rawEndAngle)
                if matches {
                    hitSlice = slice
                    break
                }
            }
        }

        if let hit = hitSlice {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if selectedSlice == hit.category {
                    selectedSlice = nil
                } else {
                    selectedSlice = hit.category
                }
            }
        }
    }

    private var donutCenterHub: some View {
        VStack(spacing: 2) {
            if let sel = selectedSlice, let match = categoryTotals.first(where: { $0.category == sel }) {
                CategoryBadge(category: sel, size: 22)

                Text(sel.displayName)
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .foregroundColor(Color.deepNavy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(l10n.format(amount: match.amount.rounded()))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(sel.themeColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("\(Int(round(match.fraction * 100)))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textMuted)

                let count = displayTransactions.filter { countsTowardStats($0) && $0.category.canonical == sel.canonical }.count
                Text("\(count) \(l10n.language == .hebrew ? "עסקאות" : "txs")")
                    .font(.system(size: 8, weight: .medium, design: .default))
                    .foregroundColor(Color.textSecondary)
            } else {
                Text(l10n.language == .hebrew ? "סה״כ החודש" : "Total Spent")
                    .font(.system(size: 10, weight: .medium, design: .default))
                    .foregroundColor(Color.textSecondary)

                Text(l10n.format(amount: totalSpent.rounded()))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                let count = displayTransactions.filter(countsTowardStats).count
                if count > 0 {
                    Text("\(count) \(l10n.language == .hebrew ? "עסקאות" : "txs")")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textMuted)
                }
            }
        }
        .frame(width: 104, height: 104)
        .background(
            Circle()
                .fill(Color(red: 250/255, green: 250/255, blue: 252/255))
        )
    }

    private var donutLegendView: some View {
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]

        return VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(categoryTotals, id: \.category) { item in
                    let isSelected = selectedSlice == item.category
                    let isDimmed = selectedSlice != nil && !isSelected

                    Button(action: {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            if selectedSlice == item.category {
                                selectedSlice = nil
                            } else {
                                selectedSlice = item.category
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.category.themeColor)
                                .frame(width: 8, height: 8)

                            Text(item.category.displayName)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .default))
                                .foregroundColor(Color.deepNavy)
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            Text("\(Int(round(item.fraction * 100)))%")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(isSelected ? item.category.themeColor : Color.textSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isSelected ? item.category.themeColor.opacity(0.12) : Color(uiColor: .systemGray6).opacity(0.65))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(isSelected ? item.category.themeColor.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                        .opacity(isDimmed ? 0.45 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let sel = selectedSlice {
                selectedCategorySubBreakdown(for: sel)
            }
        }
    }

    @ViewBuilder
    private func selectedCategorySubBreakdown(for category: SpendingCategory) -> some View {
        let activeTxs = displayTransactions.filter { countsTowardStats($0) && $0.category.canonical == category.canonical }
        let items = SubcategoryBreakdownService.shared.breakdown(
            for: category,
            transactions: activeTxs,
            isHebrew: l10n.language == .hebrew
        )

        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(l10n.language == .hebrew ? "פירוט עבור \(category.displayName):" : "Breakdown for \(category.displayName):")
                        .font(.system(size: 11, weight: .bold, design: .default))
                        .foregroundColor(Color.deepNavy)
                    Spacer()
                }
                .padding(.top, 4)

                VStack(spacing: 5) {
                    ForEach(items.prefix(4)) { sub in
                        HStack(spacing: 6) {
                            MoneyIcon(sub.icon, size: 12, color: sub.color)
                            Text(sub.name)
                                .font(.system(size: 11, weight: .medium, design: .default))
                                .foregroundColor(Color.deepNavy)
                                .lineLimit(1)
                            Spacer()
                            Text(l10n.format(amount: sub.amount.rounded()))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(Color.deepNavy)
                            Text("(\(Int(round(sub.fraction * 100)))%)")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(Color.textSecondary)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color(uiColor: .systemGray6).opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}
