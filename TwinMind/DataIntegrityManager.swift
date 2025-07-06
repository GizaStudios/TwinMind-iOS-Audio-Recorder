import Foundation
import AVFoundation
import SwiftData

/// Scans sessions and audio files on launch to detect corruption/missing files and attempts basic repairs.
struct DataIntegrityManager {
    /// Call this early on app launch (before UI) to verify integrity.
    static func run(in context: ModelContext) {
        let fileManager = FileManager.default
        let sessions: [RecordingSession]
        do {
            sessions = try context.fetch(FetchDescriptor<RecordingSession>())
        } catch {
            print("[Integrity] Failed to fetch sessions: \(error)")
            return
        }
        var sessionsModified = false
        for session in sessions {
            var sessionNeedsSave = false
            // 1. Verify segment files
            for seg in session.segments {
                let path = seg.segmentFilePath
                if !fileManager.fileExists(atPath: path) {
                    print("[Integrity] Missing segment file – removing segment \(seg.id)")
                    // detach from model
                    if let idx = session.segments.firstIndex(where: { $0.id == seg.id }) {
                        session.segments.remove(at: idx)
                        context.delete(seg)
                        sessionNeedsSave = true
                    }
                    continue
                }
                // Attempt to open with AVAudioFile to detect corruption.
                if AVAudioFileIsCorrupted(path: path) {
                    print("[Integrity] Corrupted segment – deleting \(seg.id)")
                    try? fileManager.removeItem(atPath: path)
                    if let idx = session.segments.firstIndex(where: { $0.id == seg.id }) {
                        session.segments.remove(at: idx)
                        context.delete(seg)
                        sessionNeedsSave = true
                    }
                }
            }
            // 2. Verify master file exists & is valid
            if !fileManager.fileExists(atPath: session.audioFilePath) || AVAudioFileIsCorrupted(path: session.audioFilePath) {
                print("[Integrity] Master file missing/corrupted for session \(session.id) – attempting rebuild…")
                if rebuildMasterFile(for: session) {
                    sessionNeedsSave = true
                } else {
                    print("[Integrity] Could not rebuild master – deleting session\n")
                    // Clean up segment files too
                    for seg in session.segments {
                        try? fileManager.removeItem(atPath: seg.segmentFilePath)
                        context.delete(seg)
                    }
                    context.delete(session)
                    sessionsModified = true
                    continue
                }
            }
            if sessionNeedsSave {
                sessionsModified = true
            }
        }
        if sessionsModified { try? context.save() }
    }

    /// Rebuilds the session master CAF file by concatenating its (still-valid) segments.
    /// Returns true if successful.
    private static func rebuildMasterFile(for session: RecordingSession) -> Bool {
        let composition = AVMutableComposition()
        let fileManager = FileManager.default
        var currentTime = CMTime.zero
        let validSegments = session.segments.sorted { $0.startTime < $1.startTime }
            .filter { fileManager.fileExists(atPath: $0.segmentFilePath) }
        guard !validSegments.isEmpty else { return false }
        for seg in validSegments {
            let url = URL(fileURLWithPath: seg.segmentFilePath)
            let asset = AVURLAsset(url: url)
            if let track = asset.tracks(withMediaType: .audio).first {
                let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
                do {
                    let compTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                    try compTrack?.insertTimeRange(timeRange, of: track, at: currentTime)
                    currentTime = currentTime + timeRange.duration
                } catch {
                    print("[Integrity] Failed to insert segment asset: \(error)")
                }
            }
        }
        let outputURL = URL(fileURLWithPath: session.audioFilePath)
        // Remove existing corrupted file if present
        try? fileManager.removeItem(at: outputURL)
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            print("[Integrity] Could not create exporter")
            return false
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .caf
        let semaphore = DispatchSemaphore(value: 0)
        exporter.exportAsynchronously(completionHandler: { semaphore.signal() })
        semaphore.wait()
        return exporter.status == .completed
    }

    /// Attempts to open the given audio file path; returns true if corrupted/unreadable.
    private static func AVAudioFileIsCorrupted(path: String) -> Bool {
        do {
            _ = try AVAudioFile(forReading: URL(fileURLWithPath: path))
            return false
        } catch {
            return true
        }
    }
} 