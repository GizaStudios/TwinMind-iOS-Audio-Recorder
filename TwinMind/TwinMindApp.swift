//
//  TwinMindApp.swift
//  TwinMind
//
//  Created by Devin Morgan on 7/1/25.
//

import SwiftUI
import SwiftData

@main
struct TwinMindApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            RecordingSession.self,
            AudioSegment.self,
            Transcription.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
        .modelContainer(sharedModelContainer)
    }
}
