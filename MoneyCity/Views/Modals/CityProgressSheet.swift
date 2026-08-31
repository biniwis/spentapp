import SwiftUI

/// Joyful modal allowing the user to choose an enrichment, resident, pet, or infrastructure repair unlocked by personal progress.
public struct CityProgressSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    public let report: WeeklyProgressReport
    public let unlockedEnrichments: [CityEnrichment]
    public let onSelectOption: (ProgressRewardOption) -> Void
    
    public init(
        report: WeeklyProgressReport,
        unlockedEnrichments: [CityEnrichment],
        onSelectOption: @escaping (ProgressRewardOption) -> Void
    ) {
        self.report = report
        self.unlockedEnrichments = unlockedEnrichments
        self.onSelectOption = onSelectOption
    }
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.themeYellowSoft)
                            .frame(width: 50, height: 50)
                        
                        DistrictSkylineVectorIcon(color: Color.themeYellow)
                            .scaleEffect(1.1)
                    }
                    .padding(.bottom, 2)
                    
                    Text("שדרוג ופיתוח העיר")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(Color.deepNavy)
                    
                    Text("חיסכון של ₪\(Int(report.savedAmount)) משבוע שעבר")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.themeMint)
                    
                    Text("בחר שדרוג או תיקון להוספה באי שלך:")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 100/255, green: 116/255, blue: 139/255))
                        .padding(.top, 2)
                }
                
                // Options Cards
                VStack(spacing: 10) {
                    ForEach(report.availableOptions) { opt in
                        Button(action: {
                            onSelectOption(opt)
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                // Icon Box
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(badgeBackground(for: opt))
                                        .frame(width: 48, height: 48)
                                    
                                    Text(opt.icon)
                                        .font(.system(size: 24, design: .rounded))
                                }
                                
                                // Text details
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(opt.actionType == "ADD" ? "תוספת חדשה" : "תיקון ושדרוג")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(badgeTextColor(for: opt))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(badgeBackground(for: opt))
                                            .clipShape(Capsule())
                                        
                                        Spacer()
                                    }
                                    
                                    Text(opt.title)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                                    
                                    Text(opt.subtitle)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(Color(red: 100/255, green: 116/255, blue: 139/255))
                                        .lineLimit(2)
                                }
                                
                                ZStack {
                                    Circle()
                                        .fill(Color.themeMintSoft)
                                        .frame(width: 28, height: 28)
                                    Text(verbatim: "+")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.themeMint)
                                }
                            }
                            .padding(12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(red: 226/255, green: 232/255, blue: 240/255), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                
                // Cumulative History Section
                if !unlockedEnrichments.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("השדרוגים שהרווחת בעיר (נשמרים לתמיד):")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 100/255, green: 116/255, blue: 139/255))
                            .padding(.horizontal, 24)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(unlockedEnrichments) { e in
                                    HStack(spacing: 6) {
                                        Text(e.icon)
                                            .font(.system(size: 14, design: .rounded))
                                        Text(e.name)
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color(red: 226/255, green: 232/255, blue: 240/255), lineWidth: 1))
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 24)
        }
        .presentationDetents([.fraction(0.75), .medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(red: 248/255, green: 250/255, blue: 252/255))
    }
    
    private func badgeBackground(for opt: ProgressRewardOption) -> Color {
        if opt.actionType == "ADD" {
            return Color(red: 236/255, green: 253/255, blue: 245/255)
        } else {
            return Color(red: 254/255, green: 243/255, blue: 199/255)
        }
    }
    
    private func badgeTextColor(for opt: ProgressRewardOption) -> Color {
        if opt.actionType == "ADD" {
            return Color(red: 16/255, green: 185/255, blue: 129/255)
        } else {
            return Color(red: 180/255, green: 83/255, blue: 9/255)
        }
    }
}
