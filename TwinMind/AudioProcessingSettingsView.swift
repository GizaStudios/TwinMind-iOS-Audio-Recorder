import SwiftUI

struct AudioProcessingSettingsView: View {
    @AppStorage("enableVoiceProcessing") private var voiceProcessingEnabled: Bool = true
    @AppStorage("enableNoiseReduction") private var noiseReductionEnabled: Bool = true
    @AppStorage("enableEchoCancellation") private var echoCancellationEnabled: Bool = true
    @AppStorage("enableAutomaticGainControl") private var automaticGainControlEnabled: Bool = true
    
    var body: some View {
        Form {
            Section(header: Text("Voice Processing"), footer: Text("Voice processing automatically includes noise suppression, echo cancellation, and automatic gain control for better audio quality.")) {
                Toggle("Enable Voice Processing", isOn: $voiceProcessingEnabled)
            }
            
            if voiceProcessingEnabled {
                Section(header: Text("Processing Features"), footer: Text("These features are automatically enabled with voice processing and provide enhanced audio quality.")) {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Noise Reduction")
                                .font(.headline)
                            Text("Reduces background noise and improves voice clarity")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .opacity(0.8)
                    
                    HStack {
                        Image(systemName: "speaker.wave.2")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Echo Cancellation")
                                .font(.headline)
                            Text("Removes echo and feedback from audio")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .opacity(0.8)
                    
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Automatic Gain Control")
                                .font(.headline)
                            Text("Automatically adjusts volume levels for consistency")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .opacity(0.8)
                }
                
                Section(header: Text("Voice Enhancement"), footer: Text("Additional EQ processing to enhance voice clarity and reduce unwanted frequencies.")) {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text("Voice Enhancement EQ")
                                .font(.headline)
                            Text("Applies frequency filtering optimized for voice recording")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .opacity(0.8)
                }
            }
            
            Section(header: Text("Information"), footer: Text("Voice processing requires iOS 13.0 or later and is automatically applied to all new recordings.")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Processing Status")
                            .font(.headline)
                    }
                    
                    Text("Voice processing is \(voiceProcessingEnabled ? "enabled" : "disabled")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if voiceProcessingEnabled {
                        Text("• Noise suppression active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• Echo cancellation active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• Automatic gain control active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• Voice enhancement EQ active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Audio Processing")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        AudioProcessingSettingsView()
    }
} 