//
//  AppSettings.swift
//  TwinMind
//
//  Created by Devin Morgan on 7/3/25.
//

import Foundation
import SwiftUI

/// Supported audio-recording quality presets.
enum RecordingQuality: String, CaseIterable, Identifiable, Codable {
    case low, medium, high
    var id: String { rawValue }

    /// Sample-rate in Hz to configure on the audio session.
    var sampleRate: Int {
        switch self {
        case .low: return 22_050
        case .medium: return 44_100
        case .high: return 48_000
        }
    }

    /// Linear-PCM bit-depth.
    var bitDepth: Int {
        switch self {
        case .low: return 16
        case .medium: return 16
        case .high: return 24
        }
    }

    /// Container/codec for on-disk raw recordings. Currently constant.
    var fileExtension: String { "caf" }
}

/// Centralised wrapper around UserDefaults-stored preferences used by the audio system.
struct AppSettings {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let quality = "selectedQuality"
        static let backgroundRecording = "enableBackgroundRecording"
        static let showLevels = "showLevels"
        static let activeSession = "activeRecordingSessionID"
        static let simulateOffline = "simulateOffline"
        static let segmentLength = "segmentLength"
    }

    var quality: RecordingQuality {
        get { RecordingQuality(rawValue: defaults.string(forKey: Keys.quality) ?? RecordingQuality.medium.rawValue) ?? .medium }
        set { defaults.set(newValue.rawValue, forKey: Keys.quality) }
    }

    var backgroundRecordingEnabled: Bool {
        get { defaults.object(forKey: Keys.backgroundRecording) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.backgroundRecording) }
    }

    var showLevels: Bool {
        get { defaults.object(forKey: Keys.showLevels) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.showLevels) }
    }

    /// UUID string of a `RecordingSession` that was recording when the app terminated (for recovery).
    var activeRecordingSessionID: String? {
        get { defaults.string(forKey: Keys.activeSession) }
        nonmutating set {
            if let id = newValue {
                defaults.set(id, forKey: Keys.activeSession)
            } else {
                defaults.removeObject(forKey: Keys.activeSession)
            }
        }
    }

    var simulateOfflineMode: Bool {
        get { defaults.object(forKey: Keys.simulateOffline) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Keys.simulateOffline) }
    }

    /// Segment length in seconds for audio recording (default: 30 seconds)
    var segmentLength: TimeInterval {
        get { defaults.object(forKey: Keys.segmentLength) as? TimeInterval ?? 30.0 }
        set { defaults.set(newValue, forKey: Keys.segmentLength) }
    }
} 