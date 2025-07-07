//
//  TwinMindWidgetExtensionLiveActivity.swift
//  TwinMindWidgetExtension
//
//  Created by Devin Morgan on 7/6/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TwinMindWidgetExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TwinMindWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TwinMindWidgetExtensionAttributes.self) { context in
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

extension TwinMindWidgetExtensionAttributes {
    fileprivate static var preview: TwinMindWidgetExtensionAttributes {
        TwinMindWidgetExtensionAttributes(name: "World")
    }
}

extension TwinMindWidgetExtensionAttributes.ContentState {
    fileprivate static var smiley: TwinMindWidgetExtensionAttributes.ContentState {
        TwinMindWidgetExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TwinMindWidgetExtensionAttributes.ContentState {
         TwinMindWidgetExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TwinMindWidgetExtensionAttributes.preview) {
   TwinMindWidgetExtensionLiveActivity()
} contentStates: {
    TwinMindWidgetExtensionAttributes.ContentState.smiley
    TwinMindWidgetExtensionAttributes.ContentState.starEyes
}
