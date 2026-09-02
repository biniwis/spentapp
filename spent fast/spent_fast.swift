//
//  spent_fast.swift
//  spent fast
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Entry

public struct SpentWidgetEntry: TimelineEntry {
    public let date: Date
    public let spentAmount: Double
    public let budgetAmount: Double
    public let savingsAmount: Double
    public let recentMerchant: String
    public let isHebrew: Bool
    
    public init(
        date: Date = Date(),
        spentAmount: Double = 0.0,
        budgetAmount: Double = 0.0,
        savingsAmount: Double = 0.0,
        recentMerchant: String = "",
        isHebrew: Bool = true
    ) {
        self.date = date
        self.spentAmount = spentAmount
        self.budgetAmount = budgetAmount
        self.savingsAmount = savingsAmount
        self.recentMerchant = recentMerchant
        self.isHebrew = isHebrew
    }
}

// MARK: - Timeline Provider

public struct SpentWidgetProvider: TimelineProvider {
    public typealias Entry = SpentWidgetEntry

    public func placeholder(in context: Context) -> SpentWidgetEntry {
        SpentWidgetEntry(
            spentAmount: 0,
            budgetAmount: 0,
            savingsAmount: 0,
            recentMerchant: "",
            isHebrew: true
        )
    }

    public func getSnapshot(in context: Context, completion: @escaping (SpentWidgetEntry) -> Void) {
        completion(fetchCurrentEntry())
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<SpentWidgetEntry>) -> Void) {
        let entry = fetchCurrentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func fetchCurrentEntry() -> SpentWidgetEntry {
        let defaults = UserDefaults(suiteName: "group.com.moneycity.app") ?? UserDefaults.standard
        let spent = defaults.double(forKey: "widget_monthly_spent")
        let budget = defaults.double(forKey: "widget_monthly_budget")
        let savings = defaults.double(forKey: "widget_monthly_savings")
        let merchant = defaults.string(forKey: "widget_recent_merchant") ?? ""
        let isHebrew = (defaults.string(forKey: "app_language") ?? "he") == "he"
        
        return SpentWidgetEntry(
            date: Date(),
            spentAmount: spent,
            budgetAmount: budget,
            savingsAmount: savings,
            recentMerchant: merchant,
            isHebrew: isHebrew
        )
    }
}

// MARK: - Widget Views

public struct spent_fastEntryView: View {
    @Environment(\.widgetFamily) var family
    public let entry: SpentWidgetProvider.Entry
    
    public init(entry: SpentWidgetProvider.Entry) {
        self.entry = entry
    }
    
    public var body: some View {
        switch family {
        case .accessoryCircular:
            lockScreenCircularView
                .widgetURL(URL(string: "spentapp://quick-add"))
        case .accessoryRectangular:
            lockScreenRectangularView
                .widgetURL(URL(string: "spentapp://quick-add"))
        case .accessoryInline:
            lockScreenInlineView
                .widgetURL(URL(string: "spentapp://quick-add"))
        case .systemSmall:
            homeScreenSmallView
                .widgetURL(URL(string: "spentapp://quick-add"))
        case .systemMedium:
            homeScreenMediumView
        default:
            homeScreenSmallView
                .widgetURL(URL(string: "spentapp://quick-add"))
        }
    }
    
    // MARK: - 1. Lock Screen Accessory Circular (1-Tap Quick Add)
    private var lockScreenCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                Text(entry.isHebrew ? "הוספה" : "Add")
                    .font(.system(size: 8, weight: .black, design: .rounded))
            }
        }
    }
    
    // MARK: - 2. Lock Screen Accessory Rectangular
    private var lockScreenRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 10))
                Text(entry.isHebrew ? "העיר שלך החודש" : "SPENT Month")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            
            Text("₪\(Int(entry.spentAmount)) / ₪\(Int(entry.budgetAmount))")
                .font(.system(size: 14, weight: .black, design: .rounded))
            
            Text(entry.isHebrew ? "הוספה מהירה +" : "Tap for Quick Add +")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 3. Lock Screen Accessory Inline
    private var lockScreenInlineView: some View {
        HStack(spacing: 3) {
            Image(systemName: "creditcard.fill")
            Text("₪\(Int(entry.spentAmount)) \(entry.isHebrew ? "החודש • + הוסף" : "spent • + Add")")
        }
    }
    
    // MARK: - 4. Home Screen Small Widget (Prominent Big Action Button)
    private var homeScreenSmallView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 5) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 79/255, green: 70/255, blue: 229/255))
                Text(entry.isHebrew ? "הוצאות החודש" : "SPENT Month")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 100/255, green: 116/255, blue: 139/255))
                Spacer()
            }
            
            // Amount
            Text("₪\(Int(entry.spentAmount))")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                .padding(.top, 2)
            
            let remaining = max(entry.budgetAmount - entry.spentAmount, 0)
            Text(entry.isHebrew ? "נותרו ₪\(Int(remaining)) בתקציב" : "₪\(Int(remaining)) left")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                .padding(.top, 1)
            
            Spacer(minLength: 6)
            
            // BIG Prominent Action Button
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 17, weight: .bold))
                Text(entry.isHebrew ? "הוסף הוצאה +" : "Add Expense +")
                    .font(.system(size: 13, weight: .black, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [Color(red: 79/255, green: 70/255, blue: 229/255), Color(red: 99/255, green: 102/255, blue: 241/255)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .shadow(color: Color(red: 79/255, green: 70/255, blue: 229/255).opacity(0.35), radius: 4, y: 2)
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.white)
    }
    
    // MARK: - 5. Home Screen Medium Widget (Interactive Links)
    private var homeScreenMediumView: some View {
        HStack(spacing: 14) {
            // Left Status Column
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 79/255, green: 70/255, blue: 229/255))
                    Text(entry.isHebrew ? "העיר שלך החודש" : "SPENT City")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                }
                
                Text("₪\(Int(entry.spentAmount))")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                
                let pct = entry.budgetAmount > 0 ? Int((entry.spentAmount / entry.budgetAmount) * 100) : 0
                Text(entry.isHebrew ? "\(pct)% מהתקציב · חיסכון ₪\(Int(entry.savingsAmount))" : "\(pct)% budget · Savings ₪\(Int(entry.savingsAmount))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                
                Spacer()
            }
            
            Spacer()
            
            // Right Quick Action Buttons
            VStack(spacing: 8) {
                Link(destination: URL(string: "spentapp://quick-add")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(entry.isHebrew ? "הוסף הוצאה" : "Add Expense")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 79/255, green: 70/255, blue: 229/255), Color(red: 99/255, green: 102/255, blue: 241/255)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: Color(red: 79/255, green: 70/255, blue: 229/255).opacity(0.35), radius: 5, y: 2)
                }
                
                Link(destination: URL(string: "spentapp://scan")!) {
                    HStack(spacing: 5) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 13, weight: .bold))
                        Text(entry.isHebrew ? "סריקת קבלה" : "Scan Receipt")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(red: 79/255, green: 70/255, blue: 229/255))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color(red: 238/255, green: 242/255, blue: 255/255))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .frame(width: 135)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

// MARK: - Widget Definition

public struct spent_fast: Widget {
    public let kind: String = "spent_fast"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpentWidgetProvider()) { entry in
            spent_fastEntryView(entry: entry)
                .containerBackground(.white, for: .widget)
        }
        .configurationDisplayName("SPENT - הוספה מהירה ומעקב")
        .description("הוסף עסקאות ישירות מהמסך בנגיעה אחת.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
