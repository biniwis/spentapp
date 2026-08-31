import SwiftUI
#if canImport(WidgetKit)
import WidgetKit

// MARK: - Widget Timeline Entry

public struct MoneyCityWidgetEntry: TimelineEntry {
    public let date: Date
    public let spentAmount: Double
    public let budgetAmount: Double
    public let savingsAmount: Double
    public let recentMerchant: String
    public let isHebrew: Bool
    
    public init(
        date: Date = Date(),
        spentAmount: Double = 3420.0,
        budgetAmount: Double = 8000.0,
        savingsAmount: Double = 1850.0,
        recentMerchant: String = "שופרסל",
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

// MARK: - Widget Timeline Provider

public struct MoneyCityWidgetProvider: TimelineProvider {
    public typealias Entry = MoneyCityWidgetEntry

    public func placeholder(in context: Context) -> MoneyCityWidgetEntry {
        MoneyCityWidgetEntry()
    }

    public func getSnapshot(in context: Context, completion: @escaping (MoneyCityWidgetEntry) -> Void) {
        completion(MoneyCityWidgetEntry())
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<MoneyCityWidgetEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.moneycity.app") ?? UserDefaults.standard
        let spent = defaults.double(forKey: "widget_monthly_spent") > 0 ? defaults.double(forKey: "widget_monthly_spent") : 3420.0
        let budget = defaults.double(forKey: "widget_monthly_budget") > 0 ? defaults.double(forKey: "widget_monthly_budget") : 8000.0
        let savings = defaults.double(forKey: "widget_monthly_savings") > 0 ? defaults.double(forKey: "widget_monthly_savings") : 1850.0
        let merchant = defaults.string(forKey: "widget_recent_merchant") ?? "שופרסל"
        let isHebrew = (defaults.string(forKey: "app_language") ?? "he") == "he"
        
        let entry = MoneyCityWidgetEntry(
            date: Date(),
            spentAmount: spent,
            budgetAmount: budget,
            savingsAmount: savings,
            recentMerchant: merchant,
            isHebrew: isHebrew
        )
        
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Lock Screen & Home Screen Widget Views

public struct MoneyCityWidgetEntryView: View {
    #if os(iOS)
    @Environment(\.widgetFamily) var family
    #endif
    public let entry: MoneyCityWidgetEntry
    
    public init(entry: MoneyCityWidgetEntry) {
        self.entry = entry
    }
    
    public var body: some View {
        #if os(iOS)
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
        #else
        homeScreenSmallView
        #endif
    }
    
    // MARK: - 1. Lock Screen Accessory Circular (1-Tap Quick Add)
    private var lockScreenCircularView: some View {
        ZStack {
            #if os(iOS)
            AccessoryWidgetBackground()
            #endif
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
                Text(entry.isHebrew ? "העיר שלך החודש" : "MoneyCity Month")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            
            Text("₪\(Int(entry.spentAmount)) / ₪\(Int(entry.budgetAmount))")
                .font(.system(size: 14, weight: .black, design: .rounded))
            
            Text(entry.isHebrew ? "לחץ להוספת הוצאה מהירה +" : "Tap for Quick Add +")
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
    
    // MARK: - 4. Home Screen Small Widget
    private var homeScreenSmallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 238/255, green: 242/255, blue: 255/255))
                        .frame(width: 28, height: 28)
                    DistrictSkylineVectorIcon(color: Color(red: 79/255, green: 70/255, blue: 229/255))
                        .scaleEffect(0.8)
                }
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 79/255, green: 70/255, blue: 229/255))
                    Text(entry.isHebrew ? "הוסף" : "Add")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 79/255, green: 70/255, blue: 229/255))
                }
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.isHebrew ? "הוצאות החודש" : "Monthly Spend")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 100/255, green: 116/255, blue: 139/255))
                
                Text("₪\(Int(entry.spentAmount))")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                
                let remaining = max(entry.budgetAmount - entry.spentAmount, 0)
                Text(entry.isHebrew ? "נותרו ₪\(Int(remaining)) בתקציב" : "₪\(Int(remaining)) left")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
            }
        }
        .padding(14)
        .background(Color.white)
    }
    
    // MARK: - 5. Home Screen Medium Widget
    private var homeScreenMediumView: some View {
        HStack(spacing: 16) {
            // Left Status Column
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    DistrictSkylineVectorIcon(color: Color(red: 79/255, green: 70/255, blue: 229/255))
                        .scaleEffect(0.9)
                        .frame(width: 20, height: 20)
                    Text(entry.isHebrew ? "העיר שלך החודש" : "MoneyCity")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                }
                
                Text("₪\(Int(entry.spentAmount))")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                
                let pct = entry.budgetAmount > 0 ? Int((entry.spentAmount / entry.budgetAmount) * 100) : 0
                Text(entry.isHebrew ? "\(pct)% מהתקציב · חיסכון ₪\(Int(entry.savingsAmount))" : "\(pct)% budget · Savings ₪\(Int(entry.savingsAmount))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
            }
            
            Spacer()
            
            // Right Quick Actions
            VStack(spacing: 8) {
                Link(destination: URL(string: "spentapp://quick-add")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .black))
                        Text(entry.isHebrew ? "הוספה מהירה" : "Quick Add")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(red: 79/255, green: 70/255, blue: 229/255))
                    .clipShape(Capsule())
                    .shadow(color: Color(red: 79/255, green: 70/255, blue: 229/255).opacity(0.3), radius: 4, y: 2)
                }
                
                Link(destination: URL(string: "spentapp://scan")!) {
                    HStack(spacing: 5) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 11, weight: .bold))
                        Text(entry.isHebrew ? "סריקת קבלה" : "Scan Receipt")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(red: 79/255, green: 70/255, blue: 229/255))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(red: 238/255, green: 242/255, blue: 255/255))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Color.white)
    }
}

// MARK: - Widget Declaration

public struct MoneyCityWidget: Widget {
    public let kind: String = "MoneyCityWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoneyCityWidgetProvider()) { entry in
            MoneyCityWidgetEntryView(entry: entry)
                #if os(iOS)
                .containerBackground(.white, for: .widget)
                #endif
        }
        .configurationDisplayName("SPENT - הוספה מהירה ומעקב")
        .description("הוסף עסקאות בנגיעה אחת ישירות ממסך הנעילה או ממסך הבית.")
        #if os(iOS)
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .systemSmall,
            .systemMedium
        ])
        #endif
    }
}
#endif
