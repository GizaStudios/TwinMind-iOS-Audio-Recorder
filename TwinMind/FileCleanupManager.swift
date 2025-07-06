import Foundation
import SwiftData

struct FileCleanupManager {
    static func performCleanup(modelContext: ModelContext) {
        let fileManager = FileManager.default
        let recordingsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings")

        // 1. Collect referenced file paths
        var referenced: Set<String> = []
        if let sessions = try? modelContext.fetch(FetchDescriptor<RecordingSession>()) {
            for s in sessions {
                referenced.insert(s.audioFilePath)
                for seg in s.segments {
                    referenced.insert(seg.segmentFilePath)
                }
            }
        }

        // 2. Delete orphaned CAF in Recordings dir older than 1 day
        if let files = try? fileManager.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: [.contentModificationDateKey], options: []) {
            let cutoff = Date().addingTimeInterval(-24*60*60)
            for url in files where url.pathExtension.lowercased() == "caf" {
                if !referenced.contains(url.path) {
                    if let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                       let mod = attrs.contentModificationDate, mod < cutoff {
                        try? fileManager.removeItem(at: url)
                    }
                }
            }
        }

        // 3. Delete temp M4A older than 1 day
        let tempDir = fileManager.temporaryDirectory
        if let temps = try? fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.contentModificationDateKey], options: []) {
            let cutoff = Date().addingTimeInterval(-24*60*60)
            for url in temps where url.pathExtension.lowercased() == "m4a" {
                if let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                   let mod = attrs.contentModificationDate, mod < cutoff {
                    try? fileManager.removeItem(at: url)
                }
            }
        }
    }
} 