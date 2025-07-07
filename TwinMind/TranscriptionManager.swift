import Foundation
import SwiftData
import Network
import Speech
import SwiftUI

@MainActor
class TranscriptionManager {
    private var modelContext: ModelContext
    private let pathMonitor = NWPathMonitor()
    private var isNetworkAvailable = false
    
    // Timer for retries
    private var retryTimer: Timer?

    // Keep strong references to local speech tasks to prevent deallocation
    private var localTasks: [UUID: SFSpeechRecognitionTask] = [:]

    // Track segments currently being processed to avoid duplicates
    private var activeSegmentIDs: Set<UUID> = []

    private var hasNetwork: Bool { isNetworkAvailable && !AppSettings.shared.simulateOfflineMode }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Network monitoring
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            Task { @MainActor in
                self.isNetworkAvailable = path.status == .satisfied
                print("[Network] Path status changed: \(path.status == .satisfied ? "online" : "offline")")
                if AppSettings.shared.simulateOfflineMode {
                    print("[Network] Simulate Offline Mode enabled – forcing offline.")
                }
                if self.hasNetwork {
                    print("[Network] Connection available -> processing queue")
                    self.processQueue()
                    BannerManager.shared.isOnline = true
                } else {
                    BannerManager.shared.isOnline = false
                    BannerManager.shared.show(message: "Offline mode", type: .warning)
                }
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        pathMonitor.start(queue: queue)
        
        // Start a timer to periodically check for segments to process.
        retryTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.processQueue()
            }
        }
    }
    
    deinit {
        pathMonitor.cancel()
        retryTimer?.invalidate()
    }
    
    func enqueue(segment: AudioSegment) {
        guard !activeSegmentIDs.contains(segment.id) else { return }
        print("[Transcription] Enqueue segment \(segment.id). Status: \(segment.status) retries: \(segment.retryCount)")
        activeSegmentIDs.insert(segment.id)
        segment.status = .inProgress
        segment.progress = 0.05
        try? modelContext.save()
        process(segment: segment)
    }
    
    func processQueue() {
        let descriptor = FetchDescriptor<AudioSegment>()
        if let allSegments = try? modelContext.fetch(descriptor) {
            let segmentsToRetry = allSegments.filter { $0.status == .failed && $0.retryCount < 5 }
            if !segmentsToRetry.isEmpty {
                print("[Transcription] Processing retry queue: \(segmentsToRetry.count) segments")
            }
            for segment in segmentsToRetry where !self.activeSegmentIDs.contains(segment.id) {
                self.activeSegmentIDs.insert(segment.id)
                self.process(segment: segment)
            }
        }
    }
    
    private func process(segment: AudioSegment) {
        print("[Transcription] Processing segment \(segment.id) (retry \(segment.retryCount)) hasNetwork=\(hasNetwork)")
        Task.detached { [weak self] in
            guard let self else { return }

            if await self.hasNetwork {
                await self.attemptRemoteTranscription(for: segment)
            } else {
                await self.attemptLocalTranscription(for: segment)
            }
        }
    }

    @MainActor
    private func attemptRemoteTranscription(for segment: AudioSegment) async {
        print("[Transcription] Remote transcription start for segment \(segment.id)")
        let cafURL = URL(fileURLWithPath: segment.segmentFilePath)
        
        do {
            let m4aURL = AudioConverter.temporaryM4AURL()
            let convertedURL = try AudioConverter.convertCAFToM4A(sourceURL: cafURL, destinationURL: m4aURL)
            
            let text = try await TranscriptionService.transcribeAudio(at: convertedURL)
            
            try? FileManager.default.removeItem(at: convertedURL)
            
            segment.progress = 0.2
            try? modelContext.save()
            
            BannerManager.shared.show(message: "Segment transcribed", type: .success)
            await handleTranscriptionSuccess(segment: segment, text: text, source: .whisperAPI)
            self.markFinished(segment)
            print("[Transcription] Remote transcription succeeded for segment \(segment.id)")
            segment.progress = 0.9
            try? modelContext.save()
            segment.progress = 1.0
        } catch {
            print("[Transcription] Remote transcription failed for segment \(segment.id): \(error.localizedDescription)")
            BannerManager.shared.show(message: "Transcription failed", type: .error)
            await handleTranscriptionFailure(segment: segment, error: error)
            self.markFinished(segment)
        }
    }
    
    @MainActor
    private func attemptLocalTranscription(for segment: AudioSegment) async {
        print("[Transcription] Local transcription start for segment \(segment.id)")
        let cafURL = URL(fileURLWithPath: segment.segmentFilePath)
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            await handleTranscriptionFailure(segment: segment, error: NSError(domain: "TranscriptionManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized."]))
            self.markFinished(segment)
            return
        }
        
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            await handleTranscriptionFailure(segment: segment, error: NSError(domain: "TranscriptionManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable."]))
            self.markFinished(segment)
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: cafURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        
        do {
            let text = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                var lastBest = ""
                let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                    if let error {
                        if !lastBest.isEmpty {
                            // We have some text, treat as success despite error (often cancellation)
                            continuation.resume(returning: lastBest)
                        } else {
                            continuation.resume(throwing: error)
                        }
                        return
                    }
                    guard let result = result else { return }
                    lastBest = result.bestTranscription.formattedString
                    if result.isFinal {
                        if lastBest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            continuation.resume(throwing: NSError(domain: "TranscriptionManager", code: -5, userInfo: [NSLocalizedDescriptionKey: "Empty transcription result"]))
                        } else {
                            continuation.resume(returning: lastBest)
                        }
                    }
                }
                // keep strong reference
                self.localTasks[segment.id] = task
            }
            self.localTasks.removeValue(forKey: segment.id)
            await handleTranscriptionSuccess(segment: segment, text: text, source: .appleLocal)
            print("[Transcription] Local transcription succeeded for segment \(segment.id) – text length: \(text.count)")
            self.markFinished(segment)
            segment.progress = 0.3
            try? modelContext.save()
            segment.progress = 1.0
        } catch {
            print("[Transcription] Local transcription failed for segment \(segment.id): \(error.localizedDescription)")
            await handleTranscriptionFailure(segment: segment, error: error)
            self.markFinished(segment)
        }
    }

    private func handleTranscriptionSuccess(segment: AudioSegment, text: String, source: TranscriptionSource) async {
        print("[Transcription] Success segment \(segment.id) via \(source)")
        await MainActor.run {
            let transcription = Transcription(text: text, confidence: 1.0, source: source)
            transcription.segment = segment
            segment.transcription = transcription
            segment.status = .completed
            segment.lastError = nil
            try? modelContext.save()
            
            // Update widget when transcription is completed
            NotificationCenter.default.post(name: .tmSessionCreated, object: nil)
            
            // Check if all transcriptions for this session are complete
            if let session = segment.session {
                checkSessionCompletionAndGenerateSummary(for: session)
            }
        }
    }
    
    /// Check if all transcriptions for a session are complete and generate summary if so
    private func checkSessionCompletionAndGenerateSummary(for session: RecordingSession) {
        let allSegments = session.segments
        let completedSegments = allSegments.filter { $0.status == .completed && $0.transcription?.text.isEmpty == false }
        let failedSegments = allSegments.filter { $0.status == .failed && $0.retryCount >= 5 }
        
        // Consider session complete if all segments are either completed with transcription or failed after max retries
        let processedSegments = completedSegments.count + failedSegments.count
        let totalSegments = allSegments.count
        
        print("[SessionSummary] Session '\(session.title)' progress: \(processedSegments)/\(totalSegments) segments processed")
        
        if processedSegments == totalSegments && processedSegments > 0 {
            print("[SessionSummary] All transcriptions complete for session: \(session.title)")
            
            // Only generate summary if we have at least some transcribed content
            if completedSegments.count > 0 {
                Task {
                    await SessionSummaryService.shared.generateSummary(for: session, modelContext: modelContext)
                }
            } else {
                print("[SessionSummary] No successful transcriptions for session, skipping summary generation")
            }
        }
    }

    private func handleTranscriptionFailure(segment: AudioSegment, error: Error) async {
        print("[Transcription] Failure segment \(segment.id) currentRetry=\(segment.retryCount) error=\(error.localizedDescription)")
        await MainActor.run {
            let nextRetry = segment.retryCount + 1
            if nextRetry < 5 {
                segment.retryCount = nextRetry
                segment.status = .failed
                segment.lastError = error.localizedDescription
                try? modelContext.save()
                // Exponential backoff
                let delay = pow(2.0, Double(nextRetry)) * 2.0
                Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self, segID = segment.id] _ in
                    Task { @MainActor in
                        guard let self else { return }
                        self.activeSegmentIDs.remove(segID)
                        if let descriptor = try? self.modelContext.fetch(FetchDescriptor<AudioSegment>()),
                           let seg = descriptor.first(where: { $0.id == segID }) {
                            self.process(segment: seg)
                        }
                    }
                }
            } else {
                // After 5 remote failures, fall back to local transcription
                segment.retryCount = nextRetry // set to 5
                segment.lastError = error.localizedDescription
                segment.status = .inProgress
                try? modelContext.save()
                Task { [weak self] in
                    guard let self else { return }
                    await self.attemptLocalTranscription(for: segment)
                }
            }
        }
    }

    private func markFinished(_ segment: AudioSegment) {
        activeSegmentIDs.remove(segment.id)
    }
} 