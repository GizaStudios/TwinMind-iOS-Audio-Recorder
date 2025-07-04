//
//  SettingsSheet.swift
//  TwinMind
//
//  Created by Devin Morgan on 7/2/25.
//

import SwiftUI

struct SettingsSheet: View {
    // Persisted user preferences
    @AppStorage("selectedQuality") private var selectedQualityRaw: String = RecordingQuality.medium.rawValue
    @AppStorage("enableBackgroundRecording") private var enableBackgroundRecording: Bool = true
    @AppStorage("showLevels") private var showLevels: Bool = true

    @Binding var isPresented: Bool

    private var selectedQuality: RecordingQuality {
        get { RecordingQuality(rawValue: selectedQualityRaw) ?? .medium }
        set { selectedQualityRaw = newValue.rawValue }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Recording Quality")) {
                    Picker("Quality", selection: $selectedQualityRaw) {
                        ForEach(RecordingQuality.allCases) { quality in
                            Text(quality.rawValue.capitalized).tag(quality.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    Text("Sample rate: \(selectedQuality.sampleRate) Hz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Options")) {
                    Toggle("Background Recording", isOn: $enableBackgroundRecording)
                    Toggle("Show Audio Levels", isOn: $showLevels)
                }
                
                Section(footer: Text("These preferences are stored locally; backend configuration will follow.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }
}

#Preview {
    SettingsSheet(isPresented: .constant(true))
} 