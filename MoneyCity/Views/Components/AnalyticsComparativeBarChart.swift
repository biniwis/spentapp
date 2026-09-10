import SwiftUI

public struct AnalyticsChartMonth: Identifiable {
    public var id: Int { offset }
    public let monthDate: Date
    public let label: String
    public let amount: Double
    public let isCurrent: Bool
    public let offset: Int

    public init(monthDate: Date, label: String, amount: Double, isCurrent: Bool, offset: Int) {
        self.monthDate = monthDate
        self.label = label
        self.amount = amount
        self.isCurrent = isCurrent
        self.offset = offset
    }
}

public struct AnalyticsComparativeBarChart: View {
    @EnvironmentObject private var l10n: LocalizationManager
    let months: [AnalyticsChartMonth]
    let averageSpending: Double
    let selectedMonthOffset: Int
    @Binding var selectedBarOffset: Int?
    @Binding var isScrubbingChart: Bool
    let animateChart: Bool
    let onSelectOffset: (Int) -> Void

    private let storyVibrantPurple = Color.spentGreen
    private let storySoftLilac = Color.spentGreenSoft

    public init(
        months: [AnalyticsChartMonth],
        averageSpending: Double,
        selectedMonthOffset: Int,
        selectedBarOffset: Binding<Int?>,
        isScrubbingChart: Binding<Bool>,
        animateChart: Bool,
        onSelectOffset: @escaping (Int) -> Void
    ) {
        self.months = months
        self.averageSpending = averageSpending
        self.selectedMonthOffset = selectedMonthOffset
        self._selectedBarOffset = selectedBarOffset
        self._isScrubbingChart = isScrubbingChart
        self.animateChart = animateChart
        self.onSelectOffset = onSelectOffset
    }

    public var body: some View {
        let maxAmt = max(months.map(\.amount).max() ?? 1, 100)
        let chartHeight: CGFloat = 72
        let avgAmt = averageSpending
        let highlightedOffset = selectedBarOffset ?? selectedMonthOffset

        return VStack(spacing: 10) {
            // Section Header: Title + Clean Average Capsule Badge
            HStack(alignment: .center) {
                Text(l10n.language == .hebrew ? "השוואה חצי שנתית" : "6-Month Overview")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.deepNavy)

                Spacer()

                if avgAmt > 10 {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(storyVibrantPurple)
                            .frame(width: 5, height: 5)
                        Text(l10n.language == .hebrew ? "ממוצע: \(l10n.format(amount: avgAmt.rounded()))" : "Avg: \(l10n.format(amount: avgAmt.rounded()))")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.deepNavy)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(Capsule())
                }
            }

            // 6 Evenly Spaced Month Columns with Discrete Touch Scrubbing
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(months) { item in
                        let frac = maxAmt > 0 ? CGFloat(item.amount / maxAmt) : 0
                        let barHeight: CGFloat = animateChart
                            ? (item.amount > 0 ? max(frac * chartHeight, 10) : 4)
                            : 4
                        let isHighlighted = (item.offset == highlightedOffset)
                        let columnOpacity: Double = isHighlighted ? 1.0 : ((isScrubbingChart || selectedBarOffset != nil) ? 0.55 : 1.0)

                        Button(action: {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                                selectedBarOffset = item.offset
                                onSelectOffset(item.offset)
                            }
                        }) {
                            VStack(spacing: 6) {
                                // Amount Badge above the bar
                                ZStack {
                                    if isHighlighted && item.amount > 0 {
                                        Text(l10n.format(amount: item.amount.rounded()))
                                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                            .foregroundColor(storyVibrantPurple)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(storySoftLilac.opacity(0.85))
                                            .clipShape(Capsule())
                                            .fixedSize()
                                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                                    } else {
                                        Color.clear.frame(height: 18)
                                    }
                                }
                                .frame(height: 18)

                                // Bar track + Filled pillar
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color(uiColor: .systemGray6).opacity(0.9))
                                        .frame(width: 28, height: chartHeight)

                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(isHighlighted ? storyVibrantPurple : (item.amount > 0 ? storySoftLilac : Color.clear))
                                        .frame(width: 28, height: barHeight)
                                        .scaleEffect(isHighlighted ? 1.04 : 1.0, anchor: .bottom)
                                }

                                Text(item.label)
                                    .font(.system(size: 11, weight: isHighlighted ? .bold : .medium, design: .default))
                                    .foregroundColor(isHighlighted ? Color.deepNavy : Color.textSecondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .opacity(columnOpacity)
                            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: columnOpacity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 6)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) * 0.7 else { return }
                            isScrubbingChart = true
                            let totalWidth = geo.size.width
                            guard totalWidth > 0, !months.isEmpty else { return }
                            let count = months.count
                            let fraction = max(0, min(1, value.location.x / totalWidth))
                            let isHe = l10n.language == .hebrew
                            let index = isHe
                                ? min(max(Int((1.0 - fraction) * Double(count)), 0), count - 1)
                                : min(max(Int(fraction * Double(count)), 0), count - 1)

                            let candidateOffset = months[index].offset
                            if candidateOffset != selectedBarOffset {
                                Haptics.selection()
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                                    selectedBarOffset = candidateOffset
                                    onSelectOffset(candidateOffset)
                                }
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.2)) {
                                isScrubbingChart = false
                            }
                        }
                )
            }
            .frame(height: 118)
        }
        .padding(.vertical, 4)
    }
}
