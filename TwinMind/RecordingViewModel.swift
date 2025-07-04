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

@MainActor
class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var currentDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0.0
    @Published var isOnline = true
    @Published var currentSession: RecordingSession?
    
    var modelContext: ModelContext?
    
    private var durationTimer: Timer?
    
    // MARK: Audio properties
    private let engine = AVAudioEngine()
    private var inputFormat: AVAudioFormat?
    private var currentFile: AVAudioFile?
    private let segmentLength: TimeInterval = 30.0
    private var segmentTimer: Timer?
    private var masterAudioFile: AVAudioFile?
    
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
    
    // Keep track of active transcription tasks by segment id
    private var transcriptionTasks: [UUID: Task<Void, Never>] = [:]
    
    // MARK: - Recording Flow
    func startRecording() {
        // recording permission
        #if os(iOS)
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                guard granted else { return }
                Task { @MainActor in
                    self.configureAndStartSession()
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                guard granted else { return }
                Task { @MainActor in
                    self.configureAndStartSession()
                }
            }
        }
        #endif
    }
    
    private func configureAndStartSession() {
        let selectedQuality = AppSettings.shared.quality
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
            try session.setPreferredSampleRate(Double(selectedQuality.sampleRate))
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            registerForNotifications()
        } catch {
            print("AudioSession error: \(error)")
        }
        
        // Build a recording format that the audio engine is guaranteed to work with (mono, 32-bit float). Using
        // `.pcmFormatFloat32` avoids the crash that occurs when the buffer format doesn't exactly match the file
        // format during `AVAudioFile.write(from:)`.
        guard let manualFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                               sampleRate: Double(selectedQuality.sampleRate),
                                               channels: 1,
                                               interleaved: false) else {
            print("Failed to create manual AVAudioFormat")
            return
        }

        inputFormat = manualFormat

        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: manualFormat) { [weak self] buffer, _ in
            guard let self, let file = self.currentFile else { return }
            do {
                try file.write(from: buffer)
                try self.masterAudioFile?.write(from: buffer)
                self.computeAudioLevel(buffer: buffer)
            } catch {
                print("Write error: \(error)")
            }
        }
        
        do {
            try engine.start()
            prepareNewSession()
            createNewSegmentFile()
            startTimers()
            isRecording = true
        } catch {
            print("Engine start error: \(error)")
        }
    }
    
    private func prepareNewSession() {
        guard let format = inputFormat else { return }
        
        // Create master audio file for the full session
        let masterFileName = UUID().uuidString + "." + AppSettings.shared.quality.fileExtension
        let masterFileURL = recordingsDir.appendingPathComponent(masterFileName)
        
        do {
            masterAudioFile = try AVAudioFile(forWriting: masterFileURL, settings: format.settings)
        } catch {
            print("Master file creation error: \(error)")
            return
        }
        
        let sessionModel = RecordingSession(
            title: "Recording \(Date().formatted(date: .abbreviated, time: .shortened))",
            audioFilePath: masterFileURL.path,
            sampleRate: format.sampleRate,
            bitDepth: Int(truncating: format.settings[AVLinearPCMBitDepthKey] as? NSNumber ?? 16),
            format: "caf"
        )
        currentSession = sessionModel
        currentDuration = 0
    }
    
    private func createNewSegmentFile() {
        guard let format = inputFormat else { return }
        let filename = UUID().uuidString + ".caf"
        let fileURL = recordingsDir.appendingPathComponent(filename)
        do {
            currentFile = try AVAudioFile(forWriting: fileURL, settings: format.settings)
            appendSegmentModel(fileURL: fileURL)
        } catch {
            print("File create error: \(error)")
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
    }
    
    private func rotateSegmentFile() {
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
        let level = max(0.05, min(1.0, rms * 20))
        DispatchQueue.main.async {
            self.audioLevel = level
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        durationTimer?.invalidate(); durationTimer = nil
        segmentTimer?.invalidate(); segmentTimer = nil
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
        }
        
        masterAudioFile = nil
        currentFile = nil
        // TODO: trigger transcription pipeline here
    }
    
    // MARK: Notifications
    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
#if canImport(UIKit)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
#endif
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            pauseRecording()
        case .ended:
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) { resumeRecording() }
            }
        @unknown default: break
        }
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
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
        // Avoid duplicate work
        guard transcriptionTasks[segment.id] == nil else { return }
        
        // Update status
        segment.status = .inProgress
        if let context = modelContext {
            try? context.save()
        }
        
        let task = Task.detached { [weak self] in
            guard let self else { return }
            do {
                // Convert CAF to M4A for Whisper compatibility
                let cafURL = URL(fileURLWithPath: segment.segmentFilePath)
                let m4aURL = AudioConverter.temporaryM4AURL()
                let convertedURL = try AudioConverter.convertCAFToM4A(sourceURL: cafURL, destinationURL: m4aURL)
                
                // Upload the M4A file to transcription service
                let text = try await TranscriptionService.transcribeAudio(at: convertedURL)
                
                // Clean up temporary M4A file
                try? FileManager.default.removeItem(at: convertedURL)
                
                _ = await MainActor.run {
                    // Create transcription model and persist
                    let transcription = Transcription(text: text, confidence: 1.0, source: .whisperAPI)
                    transcription.segment = segment
                    segment.transcription = transcription
                    segment.status = .completed
                    if let context = self.modelContext {
                        try? context.save()
                    }
                    // Notify any SwiftUI views bound to this view model
                    self.objectWillChange.send()
                }
            } catch {
                _ = await MainActor.run {
                    segment.status = .failed
                    segment.lastError = error.localizedDescription
                    if let context = self.modelContext {
                        try? context.save()
                    }
                    self.objectWillChange.send()
                }
            }
            _ = await MainActor.run { self.transcriptionTasks.removeValue(forKey: segment.id) }
        }
        
        transcriptionTasks[segment.id] = task
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
#endif
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