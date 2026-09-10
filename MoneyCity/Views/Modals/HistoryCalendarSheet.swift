import SwiftUI

public struct HistoryCalendarSheet: View {
    @EnvironmentObject private var l10n: LocalizationManager
    @Binding var calendarPickerDate: Date
    @Binding var showCalendarPicker: Bool
    let onFilterDay: (Date) -> Void
    let onShowEntireMonth: (Date) -> Void
    let onBackToToday: () -> Void

    public init(
        calendarPickerDate: Binding<Date>,
        showCalendarPicker: Binding<Bool>,
        onFilterDay: @escaping (Date) -> Void,
        onShowEntireMonth: @escaping (Date) -> Void,
        onBackToToday: @escaping () -> Void
    ) {
        self._calendarPickerDate = calendarPickerDate
        self._showCalendarPicker = showCalendarPicker
        self.onFilterDay = onFilterDay
        self.onShowEntireMonth = onShowEntireMonth
        self.onBackToToday = onBackToToday
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text(l10n.language == .hebrew ? "לוח שנה ומעבר לתאריך" : "Calendar & Jump to Date")
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundColor(Color.deepNavy)
                Spacer()
                Button(action: { showCalendarPicker = false }) {
                    MoneyIcon(.xmarkCircle, size: 22)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Apple Graphical Calendar
            DatePicker(
                "",
                selection: $calendarPickerDate,
                in: ...Date(),
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .tint(Color.deepNavy)
            .padding(.horizontal, 16)

            // Action buttons
            VStack(spacing: 10) {
                Button(action: {
                    Haptics.selection()
                    onFilterDay(calendarPickerDate)
                }) {
                    HStack(spacing: 6) {
                        MoneyIcon(.sliders, size: 16)
                        Text(l10n.language == .hebrew ? "הצג עסקאות של יום זה בלבד" : "Filter to This Day Only")
                            .font(.system(size: 15, weight: .bold, design: .default))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.deepNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                HStack(spacing: 12) {
                    Button(action: {
                        Haptics.selection()
                        onShowEntireMonth(calendarPickerDate)
                    }) {
                        Text(l10n.language == .hebrew ? "הצג את כל החודש" : "Show Entire Month")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundColor(Color.deepNavy)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(Color(red: 243/255, green: 244/255, blue: 246/255))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        Haptics.selection()
                        onBackToToday()
                    }) {
                        Text(l10n.language == .hebrew ? "חזרה להיום" : "Back to Today")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundColor(Color.deepNavy)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(Color(red: 243/255, green: 244/255, blue: 246/255))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .presentationDetents([.medium, .large], selection: .constant(.large))
    }
}
