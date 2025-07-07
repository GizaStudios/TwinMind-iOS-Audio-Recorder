import Foundation
import AVFoundation
import SwiftUI

/// Manages audio processing features including voice processing, noise reduction, and audio enhancement
class AudioProcessingManager {
    static let shared = AudioProcessingManager()
    
    private init() {}
    
    /// Configure voice processing on the audio engine input node
    /// - Parameter engine: The AVAudioEngine to configure
    /// - Returns: True if voice processing was successfully enabled
    func configureVoiceProcessing(on engine: AVAudioEngine) -> Bool {
        guard AppSettings.shared.voiceProcessingEnabled else {
            print("[AudioProcessing] Voice processing disabled in settings")
            return false
        }
        
        do {
            // Enable voice processing on the input node
            try engine.inputNode.setVoiceProcessingEnabled(true)
            print("[AudioProcessing] Voice processing enabled successfully")
            
            // Configure additional voice processing options if available
            configureVoiceProcessingOptions(on: engine.inputNode)
            
            return true
        } catch {
            print("[AudioProcessing] Failed to enable voice processing: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Configure specific voice processing options
    /// - Parameter inputNode: The AVAudioInputNode to configure
    private func configureVoiceProcessingOptions(on inputNode: AVAudioInputNode) {
        // Note: iOS voice processing automatically includes:
        // - Noise suppression
        // - Echo cancellation
        // - Automatic gain control
        // - Voice activity detection
        
        // We can monitor the voice processing status
        if inputNode.isVoiceProcessingEnabled {
            print("[AudioProcessing] Voice processing is active")
            
            // Log which features are available (these are automatically enabled)
            let features = getAvailableVoiceProcessingFeatures()
            print("[AudioProcessing] Available features: \(features)")
        }
    }
    
    /// Get available voice processing features
    /// - Returns: Array of available feature names
    private func getAvailableVoiceProcessingFeatures() -> [String] {
        var features: [String] = []
        
        // Voice processing typically includes these features automatically
        features.append("Noise Suppression")
        features.append("Echo Cancellation") 
        features.append("Automatic Gain Control")
        features.append("Voice Activity Detection")
        
        return features
    }
    
    /// Apply additional audio processing effects using AVAudioUnit
    /// - Parameter engine: The AVAudioEngine to add effects to
    /// - Returns: True if effects were successfully added
    func applyAudioEffects(to engine: AVAudioEngine) -> Bool {
        guard AppSettings.shared.voiceProcessingEnabled else {
            return false
        }
        
        do {
            // Add EQ for voice enhancement
            let eqUnit = AVAudioUnitEQ(numberOfBands: 3)
            configureVoiceEQ(eqUnit)
            engine.attach(eqUnit)
            
            // Connect input to EQ, then EQ to output
            engine.connect(engine.inputNode, to: eqUnit, format: engine.inputNode.outputFormat(forBus: 0))
            engine.connect(eqUnit, to: engine.mainMixerNode, format: engine.inputNode.outputFormat(forBus: 0))
            
            print("[AudioProcessing] Voice EQ applied successfully")
            
            return true
        } catch {
            print("[AudioProcessing] Failed to apply audio effects: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Configure EQ for voice enhancement
    /// - Parameter eqUnit: The AVAudioUnitEQ to configure
    private func configureVoiceEQ(_ eqUnit: AVAudioUnitEQ) {
        // Band 1: Low cut filter to reduce rumble and wind noise
        let lowCutBand = eqUnit.bands[0]
        lowCutBand.filterType = .highPass
        lowCutBand.frequency = 80.0  // Cut below 80 Hz
        lowCutBand.bypass = false
        
        // Band 2: Presence boost for voice clarity
        let presenceBand = eqUnit.bands[1]
        presenceBand.filterType = .parametric
        presenceBand.frequency = 2500.0  // Boost around 2.5 kHz
        presenceBand.bandwidth = 1.0
        presenceBand.gain = 3.0  // 3dB boost
        presenceBand.bypass = false
        
        // Band 3: High cut filter to reduce hiss and sibilance
        let highCutBand = eqUnit.bands[2]
        highCutBand.filterType = .lowPass
        highCutBand.frequency = 8000.0  // Cut above 8 kHz
        highCutBand.bypass = false
    }
    
    /// Get a description of current audio processing settings
    /// - Returns: Human-readable description of active processing
    func getProcessingDescription() -> String {
        guard AppSettings.shared.voiceProcessingEnabled else {
            return "Audio processing disabled"
        }
        
        var features: [String] = []
        
        if AppSettings.shared.noiseReductionEnabled {
            features.append("Noise Reduction")
        }
        
        if AppSettings.shared.echoCancellationEnabled {
            features.append("Echo Cancellation")
        }
        
        if AppSettings.shared.automaticGainControlEnabled {
            features.append("Automatic Gain Control")
        }
        
        features.append("Voice Enhancement EQ")
        
        return features.isEmpty ? "Basic voice processing" : features.joined(separator: ", ")
    }
    
    /// Check if voice processing is supported on this device
    /// - Returns: True if voice processing is available
    func isVoiceProcessingSupported() -> Bool {
        // Voice processing is available on iOS 13.0 and later
        if #available(iOS 13.0, *) {
            return true
        }
        return false
    }
    
    /// Get audio processing statistics for monitoring
    /// - Returns: Dictionary with processing statistics
    func getProcessingStats() -> [String: Any] {
        var stats: [String: Any] = [:]
        
        stats["voiceProcessingEnabled"] = AppSettings.shared.voiceProcessingEnabled
        stats["noiseReductionEnabled"] = AppSettings.shared.noiseReductionEnabled
        stats["echoCancellationEnabled"] = AppSettings.shared.echoCancellationEnabled
        stats["automaticGainControlEnabled"] = AppSettings.shared.automaticGainControlEnabled
        stats["isSupported"] = isVoiceProcessingSupported()
        
        return stats
    }
} 