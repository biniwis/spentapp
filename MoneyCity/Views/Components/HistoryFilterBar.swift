import SwiftUI

public struct HistoryFilterBar: View {
    @EnvironmentObject private var l10n: LocalizationManager
    @Binding var selectedCategory: SpendingCategory?
    @Binding var showOnlyUnconfirmed: Bool
    @Binding var selectedSpecificDate: Date?
    @Binding var searchText: String
    let unconfirmedCount: Int
    let dayLabel: (Date) -> String

    public init(
        selectedCategory: Binding<SpendingCategory?>,
        showOnlyUnconfirmed: Binding<Bool>,
        selectedSpecificDate: Binding<Date?>,
        searchText: Binding<String>,
        unconfirmedCount: Int,
        dayLabel: @escaping (Date) -> String
    ) {
        self._selectedCategory = selectedCategory
        self._showOnlyUnconfirmed = showOnlyUnconfirmed
        self._selectedSpecificDate = selectedSpecificDate
        self._searchText = searchText
        self.unconfirmedCount = unconfirmedCount
        self.dayLabel = dayLabel
    }

    public var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if selectedSpecificDate != nil {
                        specificDateFilterChip
                    }

                    if unconfirmedCount > 0 {
                        reviewFilterChip
                    }

                    allFilterChip
                    ForEach(SpendingCategory.primaryCategories, id: \.self) { cat in
                        categoryFilterChip(cat)
                    }
                }
                .padding(.horizontal, 2)
            }

            filterMenuButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    private var specificDateFilterChip: some View {
        Button(action: {
            Haptics.selection()
            withAnimation(.spring(response: 0.3)) {
                selectedSpecificDate = nil
            }
        }) {
            HStack(spacing: 6) {
                MoneyIcon(.calendar, size: 14)
                Text(dayLabel(selectedSpecificDate ?? Date()))
                    .font(.system(size: 13, weight: .bold, design: .default))
                MoneyIcon(.xmarkCircle, size: 14)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(MoneyCityTheme.jetBlack)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var filterMenuButton: some View {
        Menu {
            if unconfirmedCount > 0 {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showOnlyUnconfirmed.toggle()
                        if showOnlyUnconfirmed { selectedCategory = nil }
                    }
                } label: {
                    Label {
                        Text(showOnlyUnconfirmed
                            ? (l10n.language == .hebrew ? "הצג את כל העסקאות" : "Show All Transactions")
                            : (l10n.language == .hebrew ? "עסקאות לאישור בלבד (\(unconfirmedCount))" : "Review Only (\(unconfirmedCount))"))
                    } icon: {
                        MoneyIcon(showOnlyUnconfirmed ? .checkCircle : .warningCircle, size: 18)
                    }
                }
            }

            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedCategory = nil
                    showOnlyUnconfirmed = false
                    selectedSpecificDate = nil
                    searchText = ""
                }
            } label: {
                Label {
                    Text(l10n.language == .hebrew ? "איפוס סינונים" : "Reset Filters")
                } icon: {
                    MoneyIcon(.refresh, size: 18)
                }
            }
        } label: {
            MoneyIcon(.sliders, size: 18)
                .frame(width: 36, height: 36)
                .background(showOnlyUnconfirmed ? MoneyCityTheme.jetBlack : MoneyCityTheme.jetBlack.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var reviewFilterChip: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                showOnlyUnconfirmed.toggle()
                if showOnlyUnconfirmed { selectedCategory = nil }
            }
        }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(showOnlyUnconfirmed ? .white : MoneyCityTheme.accentWarm)
                    .frame(width: 7, height: 7)
                Text(l10n.language == .hebrew ? "לאישור (\(unconfirmedCount))" : "Review (\(unconfirmedCount))")
                    .font(.system(size: 13.5, weight: .semibold, design: .default))
            }
            .foregroundColor(showOnlyUnconfirmed ? .white : MoneyCityTheme.textPrimary)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(showOnlyUnconfirmed ? MoneyCityTheme.jetBlack : MoneyCityTheme.jetBlack.opacity(0.04))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var allFilterChip: some View {
        let isSelected = selectedCategory == nil && !showOnlyUnconfirmed && selectedSpecificDate == nil
        return Button(action: {
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedCategory = nil
                showOnlyUnconfirmed = false
                selectedSpecificDate = nil
            }
        }) {
            Text(l10n.language == .hebrew ? "הכל" : "All")
                .font(.system(size: 13.5, weight: isSelected ? .bold : .semibold, design: .default))
                .foregroundColor(isSelected ? .white : MoneyCityTheme.textSecondary)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(isSelected ? MoneyCityTheme.jetBlack : MoneyCityTheme.jetBlack.opacity(0.04))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func categoryFilterChip(_ cat: SpendingCategory) -> some View {
        let isSelected = selectedCategory == cat && !showOnlyUnconfirmed
        return Button(action: {
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedCategory = isSelected ? nil : cat
                showOnlyUnconfirmed = false
            }
        }) {
            Text(cat.shortName(for: l10n.language))
                .font(.system(size: 13.5, weight: isSelected ? .bold : .semibold, design: .default))
                .foregroundColor(isSelected ? .white : MoneyCityTheme.textSecondary)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(isSelected ? MoneyCityTheme.jetBlack : MoneyCityTheme.jetBlack.opacity(0.04))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
