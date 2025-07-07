import XCTest
import AVFoundation
@testable import TwinMind

final class AudioProcessingTests: XCTestCase {
    
    func testVoiceProcessingSettings() {
        // Test default settings
        XCTAssertTrue(AppSettings.shared.voiceProcessingEnabled)
        XCTAssertTrue(AppSettings.shared.noiseReductionEnabled)
        XCTAssertTrue(AppSettings.shared.echoCancellationEnabled)
        XCTAssertTrue(AppSettings.shared.automaticGainControlEnabled)
    }
    
    func testVoiceProcessingToggle() {
        let originalValue = AppSettings.shared.voiceProcessingEnabled
        
        // Toggle voice processing
        AppSettings.shared.voiceProcessingEnabled = false
        XCTAssertFalse(AppSettings.shared.voiceProcessingEnabled)
        
        // Restore original value
        AppSettings.shared.voiceProcessingEnabled = originalValue
        XCTAssertEqual(AppSettings.shared.voiceProcessingEnabled, originalValue)
    }
    
    func testAudioProcessingDescription() {
        let description = AudioProcessingManager.shared.getProcessingDescription()
        XCTAssertFalse(description.isEmpty)
        XCTAssertTrue(description.contains("Voice Enhancement EQ"))
    }
    
    func testAudioProcessingStats() {
        let stats = AudioProcessingManager.shared.getProcessingStats()
        
        XCTAssertNotNil(stats["voiceProcessingEnabled"])
        XCTAssertNotNil(stats["noiseReductionEnabled"])
        XCTAssertNotNil(stats["echoCancellationEnabled"])
        XCTAssertNotNil(stats["automaticGainControlEnabled"])
        XCTAssertNotNil(stats["isSupported"])
    }
    
    func testVoiceProcessingSupport() {
        let isSupported = AudioProcessingManager.shared.isVoiceProcessingSupported()
        
        // Voice processing should be supported on iOS 13.0+
        if #available(iOS 13.0, *) {
            XCTAssertTrue(isSupported)
        } else {
            XCTAssertFalse(isSupported)
        }
    }
    
    func testEQConfiguration() {
        // Test that EQ can be created and configured
        let eqUnit = AVAudioUnitEQ(numberOfBands: 3)
        XCTAssertNotNil(eqUnit)
        XCTAssertEqual(eqUnit.bands.count, 3)
        
        // Test band configuration
        let lowCutBand = eqUnit.bands[0]
        lowCutBand.filterType = .highPass
        lowCutBand.frequency = 80.0
        XCTAssertEqual(lowCutBand.filterType, .highPass)
        XCTAssertEqual(lowCutBand.frequency, 80.0)
    }
    
    func testAudioProcessingIntegration() {
        // Test that audio processing settings are properly integrated
        let settings = AppSettings.shared
        
        // Enable voice processing
        settings.voiceProcessingEnabled = true
        XCTAssertTrue(settings.voiceProcessingEnabled)
        
        // Disable voice processing
        settings.voiceProcessingEnabled = false
        XCTAssertFalse(settings.voiceProcessingEnabled)
    }
} 