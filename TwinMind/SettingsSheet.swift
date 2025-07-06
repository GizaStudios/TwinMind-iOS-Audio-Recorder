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
    @AppStorage("simulateOffline") private var simulateOffline: Bool = false
    @AppStorage("segmentLength") private var segmentLength: Double = 30.0

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
                
                Section(header: Text("Recording Settings")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Segment Length")
                            Spacer()
                            Text("\(Int(segmentLength)) seconds")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $segmentLength, in: 10...120, step: 5)
                            .accentColor(.blue)
                    }
                    Text("Audio will be split into segments of this length for transcription.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Options")) {
                    Toggle("Background Recording", isOn: $enableBackgroundRecording)
                    Toggle("Show Audio Levels", isOn: $showLevels)
                    Toggle("Simulate Offline Mode", isOn: $simulateOffline)
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