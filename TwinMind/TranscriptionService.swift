import Foundation

/// Handles communication with the Supabase Edge function that wraps OpenAI Whisper.
struct TranscriptionService {
    struct TranscriptionResponse: Decodable { let text: String }

    private static let endpoint: URL = URL(string: "https://btmcixjzbkdxuqjcwhil.supabase.co/functions/v1/transcribe-audio")!

    /// Uploads an audio file and returns the transcribed text.
    static func transcribeAudio(at fileURL: URL) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"

        // Build multipart/form-data body
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var data = Data()
        // Opening boundary
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        // Form-data headers
        let filename = fileURL.lastPathComponent
        let mimeType = Self.mimeType(for: fileURL)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        // File data
        let fileData = try Data(contentsOf: fileURL)
        data.append(fileData)
        data.append("\r\n".data(using: .utf8)!)
        // Closing boundary
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = data

        // Perform request
        let (respData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard http.statusCode == 200 else {
            // Attempt to read server error message
            if let errorString = String(data: respData, encoding: .utf8), !errorString.isEmpty {
                throw NSError(domain: "TranscriptionService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: errorString])
            }
            throw NSError(domain: "TranscriptionService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status \(http.statusCode)"])
        }

        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: respData)
        return decoded.text
    }

    private static func mimeType(for url: URL) -> String {
        // Basic guess; Whisper accepts various audio types
        switch url.pathExtension.lowercased() {
        case "wav": return "audio/wav"
        case "m4a": return "audio/m4a"
        case "mp3": return "audio/mpeg"
        case "caf": return "audio/x-caf"
        default: return "application/octet-stream"
        }
    }
}

// No additional helpers needed 