//
//  ContentView.swift
//  TwinMind
//
//  Created by Devin Morgan on 7/1/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationView {
            HomeView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [RecordingSession.self, AudioSegment.self, Transcription.self], inMemory: true)
}
