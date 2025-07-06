#if canImport(UIKit)
import UIKit
#endif
import Foundation
import AVFoundation
import SwiftUI
import SwiftData

/// Manages export and sharing functionality for recording sessions
@MainActor
class ExportManager: ObservableObject {
    
    // MARK: - Export Audio
    
    /// Exports the session's audio file in M4A format
    /// - Parameters:
    ///   - session: The recording session to export
    ///   - completion: Completion handler with the exported file URL or error
    static func exportAudio(for session: RecordingSession, completion: @escaping (Result<URL, ExportError>) -> Void) {
        Task {
            do {
                // Resolve the source audio path (handles moved containers or extension changes)
                guard let sourceURL = resolveAudioURL(originalPath: session.audioFilePath) else {
                    await MainActor.run {
                        completion(.failure(.sourceFileNotFound))
                    }
                    return
                }
                
                // Create export directory if needed
                let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let exportsDir = documentsDir.appendingPathComponent("Exports")
                try FileManager.default.createDirectory(at: exportsDir, withIntermediateDirectories: true)
                
                // Generate export filename
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let dateString = dateFormatter.string(from: session.createdAt)
                let sanitizedTitle = session.title.replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression)
                let exportFileName = "\(sanitizedTitle)_\(dateString).m4a"
                let exportURL = exportsDir.appendingPathComponent(exportFileName)
                
                // Remove existing file if it exists
                if FileManager.default.fileExists(atPath: exportURL.path) {
                    try FileManager.default.removeItem(at: exportURL)
                }
                
                let sourceExt = sourceURL.pathExtension.lowercased()
                let convertedURL: URL
                if sourceExt == "m4a" {
                    // Already in desired format – just copy
                    try FileManager.default.copyItem(at: sourceURL, to: exportURL)
                    convertedURL = exportURL
                } else {
                    // Convert (CAF → M4A)
                    convertedURL = try AudioConverter.convertCAFToM4A(sourceURL: sourceURL, destinationURL: exportURL)
                }
                
                await MainActor.run {
                    completion(.success(convertedURL))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(.conversionFailed(error.localizedDescription)))
                }
            }
        }
    }
    
    // MARK: - Export Transcript
    
    /// Exports the session's transcript as a text file
    /// - Parameters:
    ///   - session: The recording session to export
    ///   - completion: Completion handler with the exported file URL or error
    static func exportTranscript(for session: RecordingSession, completion: @escaping (Result<URL, ExportError>) -> Void) {
        Task {
            do {
                // Generate transcript content
                let transcriptContent = generateTranscriptText(for: session)
                
                guard !transcriptContent.isEmpty else {
                    await MainActor.run {
                        completion(.failure(.noTranscriptAvailable))
                    }
                    return
                }
                
                // Create export directory if needed
                let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let exportsDir = documentsDir.appendingPathComponent("Exports")
                try FileManager.default.createDirectory(at: exportsDir, withIntermediateDirectories: true)
                
                // Generate export filename
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let dateString = dateFormatter.string(from: session.createdAt)
                let sanitizedTitle = session.title.replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression)
                let exportFileName = "\(sanitizedTitle)_transcript_\(dateString).txt"
                let exportURL = exportsDir.appendingPathComponent(exportFileName)
                
                // Write transcript to file
                try transcriptContent.write(to: exportURL, atomically: true, encoding: .utf8)
                
                await MainActor.run {
                    completion(.success(exportURL))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(.fileWriteFailed(error.localizedDescription)))
                }
            }
        }
    }
    
    // MARK: - Share Functionality
    
    /// Shares the recording session (audio + transcript)
    /// - Parameters:
    ///   - session: The recording session to share
    ///   - sourceView: The source view for iPad popover presentation
    ///   - completion: Completion handler called when sharing completes
    static func shareSession(_ session: RecordingSession, from sourceView: UIView?, completion: @escaping (Bool) -> Void) {
        Task {
            var itemsToShare: [Any] = []
            var hasErrors = false
            
            // Export audio
            await withCheckedContinuation { continuation in
                exportAudio(for: session) { result in
                    switch result {
                    case .success(let audioURL):
                        itemsToShare.append(audioURL)
                    case .failure:
                        hasErrors = true
                    }
                    continuation.resume()
                }
            }
            
            // Export transcript if available
            if session.segments.contains(where: { $0.transcription != nil }) {
                await withCheckedContinuation { continuation in
                    exportTranscript(for: session) { result in
                        switch result {
                        case .success(let transcriptURL):
                            itemsToShare.append(transcriptURL)
                        case .failure:
                            hasErrors = true
                        }
                        continuation.resume()
                    }
                }
            }
            
            // Add session summary as text
            let summaryText = generateSessionSummary(for: session)
            itemsToShare.append(summaryText)
            
            await MainActor.run {
                if itemsToShare.isEmpty {
                    completion(false)
                    return
                }
                
                let activityViewController = UIActivityViewController(
                    activityItems: itemsToShare,
                    applicationActivities: nil
                )
                
                // Configure for iPad
                if let popover = activityViewController.popoverPresentationController {
                    if let sourceView = sourceView {
                        popover.sourceView = sourceView
                        popover.sourceRect = sourceView.bounds
                    } else {
                        // Fallback for when sourceView is nil
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first {
                            popover.sourceView = window.rootViewController?.view
                            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                        }
                    }
                }
                
                activityViewController.completionWithItemsHandler = { _, completed, _, _ in
                    completion(completed)
                }
                
                // Present the share sheet
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    
                    var presentingController = rootViewController
                    while let presented = presentingController.presentedViewController {
                        presentingController = presented
                    }
                    
                    presentingController.present(activityViewController, animated: true)
                }
            }
        }
    }
    
    /// Shares an individual audio segment
    /// - Parameters:
    ///   - segment: The audio segment to share
    ///   - completion: Completion handler called when sharing completes
    static func shareSegment(_ segment: AudioSegment, completion: @escaping (Bool) -> Void) {
        Task {
            var itemsToShare: [Any] = []
            
            // Add segment audio file
            let segmentURL = URL(fileURLWithPath: segment.segmentFilePath)
            if FileManager.default.fileExists(atPath: segmentURL.path) {
                itemsToShare.append(segmentURL)
            }
            
            // Add transcription text if available
            if let transcription = segment.transcription {
                let transcriptionText = """
                Transcription [\(formatTime(segment.startTime)) - \(formatTime(segment.endTime))]:
                \(transcription.text)
                
                Confidence: \(Int(transcription.confidence * 100))%
                Source: \(transcription.source.rawValue)
                """
                itemsToShare.append(transcriptionText)
            }
            
            await MainActor.run {
                guard !itemsToShare.isEmpty else {
                    completion(false)
                    return
                }
                
                let activityViewController = UIActivityViewController(
                    activityItems: itemsToShare,
                    applicationActivities: nil
                )
                
                // Configure for iPad
                if let popover = activityViewController.popoverPresentationController {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        popover.sourceView = window.rootViewController?.view
                        popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                    }
                }
                
                activityViewController.completionWithItemsHandler = { _, completed, _, _ in
                    completion(completed)
                }
                
                // Present the share sheet
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    
                    var presentingController = rootViewController
                    while let presented = presentingController.presentedViewController {
                        presentingController = presented
                    }
                    
                    presentingController.present(activityViewController, animated: true)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private static func generateTranscriptText(for session: RecordingSession) -> String {
        var content = ""
        
        // Header
        content += "Transcript - \(session.title)\n"
        content += "Recorded: \(session.createdAt.formatted(date: .complete, time: .complete))\n"
        content += "Duration: \(formatDuration(session.duration))\n"
        content += "Segments: \(session.segments.count)\n"
        content += "\n" + String(repeating: "-", count: 50) + "\n\n"
        
        // Sort segments by start time
        let sortedSegments = session.segments.sorted { $0.startTime < $1.startTime }
        
        for (index, segment) in sortedSegments.enumerated() {
            let startTime = formatTime(segment.startTime)
            let endTime = formatTime(segment.endTime)
            
            content += "Segment \(index + 1) [\(startTime) - \(endTime)]:\n"
            
            if let transcription = segment.transcription {
                content += transcription.text
                content += "\n"
                
                // Add confidence and source info
                let confidence = Int(transcription.confidence * 100)
                content += "(Confidence: \(confidence)%, Source: \(transcription.source.rawValue))\n"
            } else {
                content += "[No transcription available]\n"
            }
            
            content += "\n"
        }
        
        return content
    }
    
    private static func generateSessionSummary(for session: RecordingSession) -> String {
        let transcribedCount = session.segments.filter { $0.transcription != nil }.count
        let totalCount = session.segments.count
        let progressPercent = Int(session.progress * 100)
        
        return """
        📝 Recording Session: \(session.title)
        🗓️ Date: \(session.createdAt.formatted(date: .abbreviated, time: .shortened))
        ⏱️ Duration: \(formatDuration(session.duration))
        📊 Progress: \(progressPercent)% (\(transcribedCount)/\(totalCount) segments transcribed)
        """
    }
    
    private static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else {
            return String(format: "%dm %ds", minutes, seconds)
        }
    }
    
    private static func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Cleanup
    
    /// Cleans up temporary export files older than 24 hours
    static func cleanupOldExports() {
        Task {
            do {
                let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let exportsDir = documentsDir.appendingPathComponent("Exports")
                
                guard FileManager.default.fileExists(atPath: exportsDir.path) else { return }
                
                let files = try FileManager.default.contentsOfDirectory(at: exportsDir, includingPropertiesForKeys: [.creationDateKey])
                let dayAgo = Date().addingTimeInterval(-24 * 60 * 60)
                
                for file in files {
                    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                    if let creationDate = attributes[.creationDate] as? Date,
                       creationDate < dayAgo {
                        try FileManager.default.removeItem(at: file)
                    }
                }
            } catch {
                print("Failed to cleanup old exports: \(error)")
            }
        }
    }
    
    // MARK: - Path Resolution Helper
    /// Attempt to resolve an audio file path that might have moved between app launches/containers.
    private static func resolveAudioURL(originalPath: String) -> URL? {
        let fileManager = FileManager.default
        let originalURL = URL(fileURLWithPath: originalPath)
        if fileManager.fileExists(atPath: originalURL.path) { return originalURL }

        // Attempt 1 – current Recordings directory (handles new app sandbox path)
        let recordingsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings")
        let candidate = recordingsDir.appendingPathComponent(originalURL.lastPathComponent)
        if fileManager.fileExists(atPath: candidate.path) { return candidate }

        // Attempt 2 – try .m4a extension (if master was converted previously)
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        let m4aCandidate = recordingsDir.appendingPathComponent(baseName + ".m4a")
        if fileManager.fileExists(atPath: m4aCandidate.path) { return m4aCandidate }

        return nil
    }
}

// MARK: - Export Errors

enum ExportError: LocalizedError {
    case sourceFileNotFound
    case conversionFailed(String)
    case noTranscriptAvailable
    case fileWriteFailed(String)
    case shareNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .sourceFileNotFound:
            return "Source audio file not found"
        case .conversionFailed(let message):
            return "Audio conversion failed: \(message)"
        case .noTranscriptAvailable:
            return "No transcript available to export"
        case .fileWriteFailed(let message):
            return "Failed to write file: \(message)"
        case .shareNotAvailable:
            return "Sharing is not available"
        }
    }
} 