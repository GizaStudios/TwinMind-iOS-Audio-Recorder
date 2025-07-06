import XCTest
import AVFoundation
@testable import TwinMind

final class RecordingFeatureTests: XCTestCase {

    // Helper allowing async delay in tests
    private func wait(seconds: TimeInterval) {
        let expectation = self.expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: seconds + 1)
    }

    // MARK: Quality wiring ------------------------------------------------------------------
    @MainActor
    func testQualitySettingAffectsEngineSampleRate() {
        let cases: [(RecordingQuality, ClosedRange<Double>)] = [
            (.low, 20_000...26_000),         // expect ~22 kHz or rounded variant
            (.medium, 40_000...46_000),      // expect ~44.1 kHz
            (.high, 46_000...49_000)         // expect ~48 kHz
        ]

        for (quality, expectedRange) in cases {
            // Persist selected quality via UserDefaults (AppSettings reads from there)
            UserDefaults.standard.set(quality.rawValue, forKey: "selectedQuality")

            let vm = RecordingViewModel()
            vm.configureAndStartSession()          // already on main actor
            wait(seconds: 0.3)                           // give engine a moment to start

            guard let format = vm.inputFormat else {
                XCTFail("inputFormat not set for quality \(quality)")
                vm.stopRecording()
                continue
            }
            XCTAssertTrue(expectedRange.contains(format.sampleRate),
                          "sample-rate \(format.sampleRate) not in expected range for \(quality)")
            vm.stopRecording()
        }
    }

    // MARK: Route-change recovery -----------------------------------------------------------
    @MainActor
    func testRouteChangePausesAndResumesRecording() {
        UserDefaults.standard.set(RecordingQuality.medium.rawValue, forKey: "selectedQuality")
        let vm = RecordingViewModel()
        vm.configureAndStartSession()
        wait(seconds: 0.2)
        XCTAssertTrue(vm.isRecording)
        XCTAssertFalse(vm.isPaused)

        // Post a fake route-change (e.g. headphones unplugged)
        let note = Notification(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [ AVAudioSessionRouteChangeReasonKey :
                        AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue ])
        NotificationCenter.default.post(note)

        // Immediately after the notification we should be paused
        wait(seconds: 0.05)
        XCTAssertTrue(vm.isPaused)

        // After 0.5 s we expect resumeRecording to have fired
        wait(seconds: 0.6)
        XCTAssertFalse(vm.isPaused)
        XCTAssertTrue(vm.isRecording)

        vm.stopRecording()
    }
} 