import XCTest
import AVFoundation
import SwiftData
@testable import TwinMind

final class RecordingViewModelAdditionalTests: XCTestCase {
    // Convenience wait helper
    func wait(seconds: TimeInterval) {
        let exp = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exp.fulfill() }
        wait(for: [exp], timeout: seconds + 1)
    }

    // MARK: Segmentation ------------------------------------------------------------------
    @MainActor
    func testRotateSegmentCreatesNewSegment() {
        UserDefaults.standard.set(RecordingQuality.low.rawValue, forKey: "selectedQuality")
        let vm = RecordingViewModel()
        vm.configureAndStartSession()
        wait(seconds: 0.3)
        XCTAssertNotNil(vm.currentSession)
        let initialCount = vm.currentSession?.segments.count ?? 0
        // Manually trigger rotation (method marked @objc for testability)
        vm.perform(Selector("rotateSegmentFile"))
        wait(seconds: 0.1)
        let newCount = vm.currentSession?.segments.count ?? 0
        XCTAssertEqual(newCount, initialCount + 1, "rotateSegmentFile should append a new AudioSegment")
        vm.stopRecording()
    }

    // MARK: Retry logic --------------------------------------------------------------------
    @MainActor
    func testTranscriptionRetryCountIncrements() async throws {
        // Force offline so TranscriptionManager will mark failure quickly
        AppSettings.shared.simulateOfflineMode = true
        defer { AppSettings.shared.simulateOfflineMode = false }

        // In-memory SwiftData container
        let schema = Schema([RecordingSession.self, AudioSegment.self, Transcription.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let ctx = container.mainContext

        // Minimal session & segment
        let session = RecordingSession(title: "Test", audioFilePath: "", sampleRate: 48000, bitDepth: 16, format: "caf")
        ctx.insert(session)
        let seg = AudioSegment(startTime: 0, endTime: 30, segmentFilePath: NSTemporaryDirectory() + "dummy.caf")
        seg.session = session
        session.segments.append(seg)
        try ctx.save()

        let manager = TranscriptionManager(modelContext: ctx)
        manager.enqueue(segment: seg)

        // Wait a short time for failure path
        try await Task.sleep(nanoseconds: 1_000_000_000)
        XCTAssertEqual(seg.retryCount, 1, "Retry count should increment after first failed attempt")
    }

    // MARK: Level meter --------------------------------------------------------------------
    @MainActor
    func testAudioLevelUpdatesWhileRecording() {
        UserDefaults.standard.set(RecordingQuality.low.rawValue, forKey: "selectedQuality")
        let vm = RecordingViewModel()
        vm.configureAndStartSession()
        wait(seconds: 0.5)
        XCTAssertTrue(vm.audioLevel > 0.0, "audioLevel should update from initial 0 during recording")
        vm.stopRecording()
    }

    // MARK: Interruption recovery -----------------------------------------------------------
    @MainActor
    func testInterruptionPausesAndResumes() {
        UserDefaults.standard.set(RecordingQuality.low.rawValue, forKey: "selectedQuality")
        let vm = RecordingViewModel()
        vm.configureAndStartSession()
        wait(seconds: 0.2)
        XCTAssertTrue(vm.isRecording)
        XCTAssertFalse(vm.isPaused)

        // Send interruption began
        let beganNote = Notification(name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(), userInfo: [ AVAudioSessionInterruptionTypeKey : AVAudioSession.InterruptionType.began.rawValue ])
        NotificationCenter.default.post(beganNote)
        wait(seconds: 0.05)
        XCTAssertTrue(vm.isPaused)

        // Send interruption ended with shouldResume flag
        let endedNote = Notification(name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(), userInfo: [ AVAudioSessionInterruptionTypeKey : AVAudioSession.InterruptionType.ended.rawValue, AVAudioSessionInterruptionOptionKey : AVAudioSession.InterruptionOptions.shouldResume.rawValue ])
        NotificationCenter.default.post(endedNote)
        wait(seconds: 0.3)
        XCTAssertFalse(vm.isPaused)
        XCTAssertTrue(vm.isRecording)
        vm.stopRecording()
    }
} 