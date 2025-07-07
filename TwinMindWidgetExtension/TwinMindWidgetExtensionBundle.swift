//
//  TwinMindWidgetExtensionBundle.swift
//  TwinMindWidgetExtension
//
//  Created by Devin Morgan on 7/6/25.
//

import WidgetKit
import SwiftUI

@main
struct TwinMindWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        TwinMindWidgetExtension()
        TwinMindWidgetExtensionControl()
        TwinMindWidgetExtensionLiveActivity()
    }
}
