import Foundation
import SwiftData

/// Service for generating session summaries using AI processing
class SessionSummaryService {
    static let shared = SessionSummaryService()
    
    private let baseURL = "https://btmcixjzbkdxuqjcwhil.supabase.co/functions/v1/transcription-complete"
    
    private init() {}
    
    /// Generate summary for a completed recording session
    /// - Parameters:
    ///   - session: The completed recording session
    ///   - modelContext: SwiftData context for saving updates
    ///   - forceRetry: Whether to retry even if generation previously failed
    @MainActor
    func generateSummary(for session: RecordingSession, modelContext: ModelContext, forceRetry: Bool = false) async {
        // Skip if already has notes and not forcing retry
        if !forceRetry && session.notes != nil && !session.notes!.isEmpty {
            print("[SessionSummary] Session already has notes, skipping generation")
            return
        }
        
        // Skip if failed before and not forcing retry
        if !forceRetry && session.summaryGenerationFailed {
            print("[SessionSummary] Session previously failed generation, skipping (use forceRetry: true to override)")
            return
        }
        // Build the full transcription text from all segments
        let fullTranscription = buildFullTranscription(from: session)
        
        guard !fullTranscription.isEmpty else {
            print("[SessionSummary] No transcription text available for session: \(session.title)")
            return
        }
        
        // Only send the first 4000 characters to reduce payload size
        let truncatedTranscription = String(fullTranscription.prefix(4000))
        
        print("[SessionSummary] Generating summary for session: \(session.title)")
        print("[SessionSummary] Transcription length (truncated): \(truncatedTranscription.count) characters (original: \(fullTranscription.count))")
        
        do {
            let summary = try await callSummaryAPI(transcription: truncatedTranscription)
            
            // Update the session with the generated title and notes
            session.title = summary.title
            session.notes = summary.notes
            session.summaryGenerationFailed = false // Clear any previous error state
            
            do {
                try modelContext.save()
                print("[SessionSummary] Successfully updated session with title: '\(summary.title)'")
                
                // Notify UI of session update
                NotificationCenter.default.post(name: .tmSessionUpdated, object: session)
            } catch {
                print("[SessionSummary] Failed to save session updates: \(error)")
                // Mark as failed since we couldn't save the successful result
                session.summaryGenerationFailed = true
                try? modelContext.save()
            }
        } catch {
            print("[SessionSummary] Failed to generate summary: \(error)")
            
            // Mark summary generation as failed but keep the existing title
            session.summaryGenerationFailed = true
            
            do {
                try modelContext.save()
                print("[SessionSummary] Marked session as summary generation failed")
                
                // Notify UI of session update (to clear loading state)
                NotificationCenter.default.post(name: .tmSessionUpdated, object: session)
            } catch {
                print("[SessionSummary] Failed to save error state: \(error)")
            }
        }
    }
    
    /// Build the full transcription text from all segments in chronological order
    private func buildFullTranscription(from session: RecordingSession) -> String {
        let sortedSegments = session.segments
            .filter { $0.transcription?.text.isEmpty == false }
            .sorted { $0.startTime < $1.startTime }
        
        let transcriptionTexts = sortedSegments.compactMap { segment in
            segment.transcription?.text
        }
        
        return transcriptionTexts.joined(separator: " ")
    }
    
    /// Call the Supabase function to generate session summary
    private func callSummaryAPI(transcription: String) async throws -> SessionSummary {
        guard let url = URL(string: baseURL) else {
            throw SessionSummaryError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = SummaryRequest(text: transcription)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SessionSummaryError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            print("[SessionSummary] API returned status code: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("[SessionSummary] API response: \(responseString)")
            }
            throw SessionSummaryError.apiError(httpResponse.statusCode)
        }
        
        let summary = try JSONDecoder().decode(SessionSummary.self, from: data)
        return summary
    }
}

// MARK: - Data Models

struct SummaryRequest: Codable {
    let text: String
}

struct SessionSummary: Codable {
    let title: String
    let notes: String
}

// MARK: - Errors

enum SessionSummaryError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(Int)
    case noTranscription
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid API response"
        case .apiError(let statusCode):
            return "API error with status code: \(statusCode)"
        case .noTranscription:
            return "No transcription text available"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let tmSessionUpdated = Notification.Name("tmSessionUpdated")
} 