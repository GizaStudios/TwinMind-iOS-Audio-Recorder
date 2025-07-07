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
    @AppStorage("enableVoiceProcessing") private var voiceProcessingEnabled: Bool = true
    @AppStorage("enableNoiseReduction") private var noiseReductionEnabled: Bool = true
    @AppStorage("enableEchoCancellation") private var echoCancellationEnabled: Bool = true
    @AppStorage("enableAutomaticGainControl") private var automaticGainControlEnabled: Bool = true

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
                
                Section(header: Text("Audio Processing")) {
                    Toggle("Voice Processing", isOn: $voiceProcessingEnabled)
                    if voiceProcessingEnabled {
                        Text("Includes noise reduction, echo cancellation, and automatic gain control")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Options")) {
                    Toggle("Background Recording", isOn: $enableBackgroundRecording)
                    Toggle("Show Audio Levels", isOn: $showLevels)
                    Toggle("Simulate Offline Mode", isOn: $simulateOffline)
                    
                    // Developer option to reset intro screen
                    Button(action: {
                        UserDefaults.standard.removeObject(forKey: "hasSeenIntro")
                    }) {
                        HStack {
                            Image(systemName: "heart")
                                .foregroundColor(.pink)
                            Text("Reset Intro Screen")
                                .foregroundColor(.primary)
                        }
                    }
                    Text("Tap to show the intro screen again on next app launch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(footer: Text("These preferences are stored locally; backend configuration will follow.")) {
                    EmptyView()
                }
                
                Section(header: Text("Contact")) {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.blue)
                        Text("morgandevin1029@gmail.com")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let url = URL(string: "mailto:morgandevin1029@gmail.com") {
                            UIApplication.shared.open(url)
                        }
                    }
                    Text("Tap to send an email")
                        .font(.caption)
                        .foregroundColor(.secondary)
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