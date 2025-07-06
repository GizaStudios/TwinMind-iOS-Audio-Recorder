import Foundation
import CryptoKit

// Key names for Keychain
private enum KeychainKeys {
    static let hmacSecret = "tm_hmac_secret"
    static let jwtToken = "tm_jwt_token"
}

/// Handles communication with the Supabase Edge function that wraps OpenAI Whisper.
struct TranscriptionService {
    struct TranscriptionResponse: Decodable { let text: String }

    private static let endpoint: URL = URL(string: "https://btmcixjzbkdxuqjcwhil.supabase.co/functions/v1/transcribe-audio")!

    // Injected by tests to provide a custom URLSession
    static var sessionProvider: () -> URLSession = {
        URLSession(configuration: .ephemeral)
    }

    /// Uploads an audio file and returns the transcribed text.
    /// Implements up to three retries with exponential backoff (1 s, 2 s, 4 s) for transient
    /// network/server errors.
    static func transcribeAudio(at fileURL: URL) async throws -> String {
        var lastError: Error?
        // 3 attempts: initial + 2 retries
        for attempt in 0..<3 {
            do {
                return try await performSingleUpload(at: fileURL)
            } catch {
                lastError = error
                // Don't retry for 4xx client errors except 429 (rate-limit)
                if let urlErr = error as? URLError {
                    // For URLError we will retry (network likely transient)
                } else if let nsErr = error as NSError?, (400...499).contains(nsErr.code), nsErr.code != 429 {
                    break // no point retrying client error
                }
                // Exponential backoff before next retry
                let delay = pow(2.0, Double(attempt))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        throw lastError ?? URLError(.unknown)
    }

    // MARK: - Internal helpers
    private static func performSingleUpload(at fileURL: URL) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"

        // Generate request signing headers
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let nonce = UUID().uuidString
        if let secret = try? SecureStore.read(key: KeychainKeys.hmacSecret) {
            let signature = sign(timestamp: timestamp, nonce: nonce, path: endpoint.path, secret: secret)
            request.setValue(timestamp, forHTTPHeaderField: "X-TM-Timestamp")
            request.setValue(nonce, forHTTPHeaderField: "X-TM-Nonce")
            request.setValue(signature, forHTTPHeaderField: "X-TM-Signature")
        }
        if let jwt = try? SecureStore.read(key: KeychainKeys.jwtToken) {
            request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }

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

        // Use injectable session (allows stubbing in tests)
        let session = Self.sessionProvider()
        let (respData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard http.statusCode == 200 else {
            if let errorString = String(data: respData, encoding: .utf8), !errorString.isEmpty {
                throw NSError(domain: "TranscriptionService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: errorString])
            }
            throw NSError(domain: "TranscriptionService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status \(http.statusCode)"])
        }

        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: respData)
        return decoded.text
    }

    private static func sign(timestamp: String, nonce: String, path: String, secret: String) -> String {
        let payload = "\(timestamp):\(nonce):\(path)"
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return Data(signature).base64EncodedString()
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