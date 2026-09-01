//
//  spent_fastLiveActivity.swift
//  spent fast
//
//  Created by בנימין ויסמן on 19 Elul 5786 AM.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct spent_fastAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct spent_fastLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: spent_fastAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension spent_fastAttributes {
    fileprivate static var preview: spent_fastAttributes {
        spent_fastAttributes(name: "World")
    }
}

extension spent_fastAttributes.ContentState {
    fileprivate static var smiley: spent_fastAttributes.ContentState {
        spent_fastAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: spent_fastAttributes.ContentState {
         spent_fastAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: spent_fastAttributes.preview) {
   spent_fastLiveActivity()
} contentStates: {
    spent_fastAttributes.ContentState.smiley
    spent_fastAttributes.ContentState.starEyes
}
