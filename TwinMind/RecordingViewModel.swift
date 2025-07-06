//
//  RecordingViewModel.swift
//  TwinMind
//
//  Created by Devin Morgan on 7/1/25.
//

import Foundation
import SwiftUI
import Combine
import SwiftData
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Error types reported to the UI
enum RecordingError: LocalizedError, Identifiable {
    case micPermissionDenied
    case diskFull
    case engineFailure(String)
    case microphoneRevoked
    case fileWrite(String)

    var id: String { localizedDescription }

    var errorDescription: String? {
        switch self {
        case .micPermissionDenied:      return "Microphone permission was denied. Please enable it in Settings."
        case .diskFull:                 return "Recording stopped – your device is out of free space."
        case .engineFailure(let msg):   return "Audio engine error: \(msg)"
        case .microphoneRevoked:        return "Microphone access was revoked while recording."
        case .fileWrite(let msg):       return "Could not write audio data: \(msg)"
        }
    }
}

@MainActor
class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var currentDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0.0
    @Published var isOnline = true
    @Published var currentSession: RecordingSession?
    @Published var recordingError: RecordingError?
    @Published var waveformSamples: [Float] = []
    /// Maximum number of samples kept in memory for the on-screen waveform.
    private let maxWaveformSamples = 120
    
    var modelContext: ModelContext? {
        didSet {
            if let modelContext = modelContext, transcriptionManager == nil {
                transcriptionManager = TranscriptionManager(modelContext: modelContext)
            }
        }
    }
    
    private var transcriptionManager: TranscriptionManager?
    private var durationTimer: Timer?
    
    // MARK: Audio properties
    private let engine = AVAudioEngine()
    internal(set) var inputFormat: AVAudioFormat?
    private var currentFile: AVAudioFile?
    private var segmentTimer: Timer?
    private var masterAudioFile: AVAudioFile?
    
    // Computed property that reads from AppSettings
    private var segmentLength: TimeInterval {
        AppSettings.shared.segmentLength
    }
    
    // Background task identifier (iOS)
#if canImport(UIKit)
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
#endif
    
    private let fileManager = FileManager.default
    private var recordingsDir: URL {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Recordings")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    // MARK: Device storage safety
    /// Minimum free space (bytes) required to start or continue a recording (~50 MB).
    private let minimumRequiredFreeSpace: Int64 = 50 * 1024 * 1024
    private var diskMonitorTimer: Timer?
    
    // MARK: - Recording Flow
    func startRecording() {
        // recording permission
        #if os(iOS)
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                guard granted else {
                    Task { @MainActor in self.recordingError = .micPermissionDenied }
                    return
                }
                Task { @MainActor in
                    guard self.hasSufficientDiskSpace() else {
                        self.recordingError = .diskFull
                        return
                    }
                    self.configureAndStartSession()
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                guard granted else {
                    Task { @MainActor in self.recordingError = .micPermissionDenied }
                    return
                }
                Task { @MainActor in
                    guard self.hasSufficientDiskSpace() else {
                        self.recordingError = .diskFull
                        return
                    }
                    self.configureAndStartSession()
                }
            }
        }
        #endif
    }
    
    @objc func configureAndStartSession() {
        // Double-check free space before engaging audio engine – user may have deleted/added files since permission prompt.
        guard hasSufficientDiskSpace() else {
            self.recordingError = .diskFull
            return
        }
        let selectedQuality = AppSettings.shared.quality
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
            try session.setPreferredSampleRate(Double(selectedQuality.sampleRate))
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            registerForNotifications()
        } catch {
            print("AudioSession error: \(error)")
            recordingError = .engineFailure(error.localizedDescription)
        }
        
        // Ask the engine for its actual hardware input format (takes into account current route, sample-rate, channel
        // count, etc.). Using this format for the tap guarantees that Core Audio doesn't throw the "Input HW format
        // and tap format not matching" exception.
        let hwFormat = engine.inputNode.outputFormat(forBus: 0)

        inputFormat = hwFormat

        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: hwFormat) { [weak self] buffer, _ in
            autoreleasepool {
                guard let self, let file = self.currentFile else { return }
                do {
                    try file.write(from: buffer)
                    try self.masterAudioFile?.write(from: buffer)
                    self.computeAudioLevel(buffer: buffer)
                } catch {
                    print("Write error: \(error)")
                    if let nsError = error as NSError?, nsError.code == NSFileWriteOutOfSpaceError {
                        self.recordingError = .diskFull
                        self.stopRecording()
                    } else {
                        self.recordingError = .fileWrite(error.localizedDescription)
                    }
                }
            }
        }
        
        do {
            try engine.start()
            prepareNewSession()
            createNewSegmentFile()
            startTimers()
            isRecording = true
            
            // Set active session flag for recovery
            if let uuid = currentSession?.id {
                AppSettings.shared.activeRecordingSessionID = uuid.uuidString
            }
        } catch {
            print("Engine start error: \(error)")
            recordingError = .engineFailure(error.localizedDescription)
        }
    }
    
    private func prepareNewSession() {
        guard let format = inputFormat else { return }
        
        // Create master audio file for the full session
        let selectedQuality = AppSettings.shared.quality
        let masterFileName = UUID().uuidString + "." + selectedQuality.fileExtension
        let masterFileURL = recordingsDir.appendingPathComponent(masterFileName)
        
        do {
            masterAudioFile = try AVAudioFile(forWriting: masterFileURL, settings: audioFileSettings(channelCount: format.channelCount))
            
            // Apply file protection to encrypt on-disk audio
            applyFileProtection(to: masterFileURL)
        } catch {
            print("Master file creation error: \(error)")
            recordingError = .fileWrite(error.localizedDescription)
            return
        }
        
        let sessionModel = RecordingSession(
            title: "Recording \(Date().formatted(date: .abbreviated, time: .shortened))",
            audioFilePath: masterFileURL.path,
            sampleRate: Double(selectedQuality.sampleRate),
            bitDepth: selectedQuality.bitDepth,
            format: selectedQuality.fileExtension
        )
        currentSession = sessionModel
        currentDuration = 0
    }
    
    private func createNewSegmentFile() {
        guard let format = inputFormat else { return }
        let filename = UUID().uuidString + "." + AppSettings.shared.quality.fileExtension
        let fileURL = recordingsDir.appendingPathComponent(filename)
        do {
            currentFile = try AVAudioFile(forWriting: fileURL, settings: audioFileSettings(channelCount: format.channelCount))
            applyFileProtection(to: fileURL)
            appendSegmentModel(fileURL: fileURL)
        } catch {
            print("File create error: \(error)")
            recordingError = .fileWrite(error.localizedDescription)
        }
    }
    
    private func appendSegmentModel(fileURL: URL) {
        guard let sessionModel = currentSession else { return }
        let startTime = currentDuration
        let segment = AudioSegment(
            startTime: startTime,
            endTime: startTime + segmentLength,
            segmentFilePath: fileURL.path
        )
        segment.session = sessionModel
        sessionModel.segments.append(segment)
    }
    
    // MARK: Timers
    private func startTimers() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.currentDuration += 1
            }
        }
        
        segmentTimer = Timer.scheduledTimer(withTimeInterval: segmentLength, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.rotateSegmentFile()
            }
        }
        
        // Periodic disk-space safety check (every 5 s)
        diskMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if !self.hasSufficientDiskSpace() {
                Task { @MainActor in
                    self.recordingError = .diskFull
                    self.stopRecording()
                }
            }
        }
    }
    
    @objc private func rotateSegmentFile() {
        // Capture the segment that just finished recording
        let justFinishedSegment = currentSession?.segments.last
        
        currentFile = nil
        createNewSegmentFile()
        
        // Kick off transcription for the finished segment
        if let segment = justFinishedSegment {
            startTranscription(for: segment)
        }
    }
    
    private func computeAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let level = max(0.0, min(1.0, rms * 20))
        DispatchQueue.main.async {
            self.audioLevel = level
            // Maintain waveform sample history for the UI
            self.waveformSamples.append(level)
            if self.waveformSamples.count > self.maxWaveformSamples {
                self.waveformSamples.removeFirst(self.waveformSamples.count - self.maxWaveformSamples)
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        durationTimer?.invalidate(); durationTimer = nil
        segmentTimer?.invalidate(); segmentTimer = nil
        diskMonitorTimer?.invalidate(); diskMonitorTimer = nil
        isRecording = false
        
        // Save to SwiftData
        currentSession?.duration = currentDuration
        
        // Finalize the last (possibly partial) segment before transcription
        if let lastSeg = currentSession?.segments.last {
            // Update its true end-time based on final duration
            lastSeg.endTime = currentDuration
            // Close the file handle so it can be read for conversion
            currentFile = nil
            // Kick off transcription
            startTranscription(for: lastSeg)
        }
        
        if let session = currentSession, let context = modelContext {
            context.insert(session)
            try? context.save()
            NotificationCenter.default.post(name: .tmSessionCreated, object: nil)
        }
        
        masterAudioFile = nil
        currentFile = nil
        // TODO: trigger transcription pipeline here
        
        // Clear active session flag
        AppSettings.shared.activeRecordingSessionID = nil
    }
    
    // MARK: Notifications
    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
#if canImport(UIKit)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleMemoryWarning), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppWillTerminate), name: UIApplication.willTerminateNotification, object: nil)
#endif
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            pauseRecording()
            recordingError = .microphoneRevoked
        case .ended:
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) { resumeRecording() }
            }
        @unknown default: break
        }
    }
    
    @objc func handleRouteChange(_ notification: Notification) {
        guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        print("Audio route changed: \(reason)")

        switch reason {
        case .oldDeviceUnavailable, .newDeviceAvailable, .routeConfigurationChange, .override, .categoryChange:
            pauseRecording()
            // Give the system a brief moment to stabilise the route before resuming.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }
                // Re-apply preferred sample-rate in case the underlying HW changed
                let session = AVAudioSession.sharedInstance()
                let selectedQuality = AppSettings.shared.quality
                try? session.setPreferredSampleRate(Double(selectedQuality.sampleRate))
                self.resumeRecording()
            }
        default:
            break
        }
    }
    
    // Pause / resume with engine
    func pauseRecording() {
        guard isRecording, !isPaused else { return }
        engine.pause()
        isPaused = true
        durationTimer?.invalidate(); durationTimer = nil
        segmentTimer?.invalidate(); segmentTimer = nil
    }
    
    func resumeRecording() {
        guard isRecording, isPaused else { return }
        do {
            try engine.start()
            isPaused = false
            startTimers()
        } catch {
            print("Resume error: \(error)")
        }
    }
    
    func toggleOnlineStatus() {
        isOnline.toggle()
    }
    
    // MARK: - Transcription Logic
    private func startTranscription(for segment: AudioSegment) {
        transcriptionManager?.enqueue(segment: segment)
    }

#if canImport(UIKit)
    // MARK: - Background handling
    @objc private func appDidEnterBackground() {
        guard AppSettings.shared.backgroundRecordingEnabled, isRecording else { return }
        if backgroundTaskID == .invalid {
            backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Recording") { [weak self] in
                if let id = self?.backgroundTaskID, id != .invalid {
                    UIApplication.shared.endBackgroundTask(id)
                    self?.backgroundTaskID = .invalid
                }
            }
        }
    }

    @objc private func appWillEnterForeground() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    @objc private func handleMemoryWarning() {
        print("[Memory] Warning received – stopping recording to free resources")
        stopRecording()
    }

    @objc private func handleAppWillTerminate() {
        print("[Lifecycle] App terminating – stopping recording")
        stopRecording()
    }
#endif

    // MARK: File Protection Helper
    private func applyFileProtection(to url: URL) {
        #if os(iOS)
        do {
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        } catch {
            print("Failed to set file protection: \(error)")
        }
        #endif
    }

    // MARK: Disk space helpers
    /// Returns `true` if the device currently has at least `minimumRequiredFreeSpace` bytes available.
    private func hasSufficientDiskSpace() -> Bool {
        do {
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let values = try documentsURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let available = values.volumeAvailableCapacityForImportantUsage {
                return available > minimumRequiredFreeSpace
            }
        } catch {
            print("[Disk] Could not read free space: \(error)")
            // Fail-open so we don't block recording unnecessarily.
            return true
        }
        return true
    }

    // Helper to build audio file settings according to the selected quality
    private func audioFileSettings(channelCount: AVAudioChannelCount) -> [String: Any] {
        let quality = AppSettings.shared.quality
        return [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: Double(quality.sampleRate),
            AVNumberOfChannelsKey: channelCount,
            AVLinearPCMBitDepthKey: quality.bitDepth,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
    }
}

// Mock data (only used for previews / debug)
#if DEBUG
extension RecordingViewModel {
    static let mockTranscriptionTexts = [
        "This is a sample transcription of what was said during this segment of the recording.",
        "The user discussed important points about the project timeline and deliverables.",
        "Meeting notes include action items and next steps for the team to follow.",
        "The conversation covered technical requirements and implementation details.",
        "Key decisions were made regarding the user interface and user experience design.",
        "Discussion about database architecture and data modeling approaches.",
        "Review of testing strategies and quality assurance processes.",
        "Planning session for the next sprint and resource allocation.",
        "Brainstorming new features and functionality for the application.",
        "Performance optimization and scalability considerations were discussed."
    ]
}
#endif 