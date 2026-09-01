import AppIntents
import SwiftUI
import WidgetKit

struct spent_fastControl: ControlWidget {
    static let kind: String = "com.moneycity.app.spent-fast.control"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: QuickAddLaunchIntent()) {
                Label("הוסף הוצאה", systemImage: "plus")
            }
        }
        .displayName("SPENT - הוספה מהירה")
        .description("פותח ישירות את מסך הוספת ההוצאה המהירה ב-SPENT.")
    }
}

public struct QuickAddLaunchIntent: AppIntent {
    public static var title: LocalizedStringResource = "הוספת הוצאה מהירה"
    public static var description = IntentDescription("פותח ישירות את חלון ההוספה המהירה באפליקציה.")
    public static var openAppWhenRun: Bool = true
    public static var isDiscoverable: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        return .result()
    }
}
