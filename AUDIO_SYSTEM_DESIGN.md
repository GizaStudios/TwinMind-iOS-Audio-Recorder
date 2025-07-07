# Audio System Design Document

## Overview

TwinMind's audio system is built around AVAudioEngine with comprehensive handling of real-world audio challenges including route changes, interruptions, background recording, and error recovery. The system is designed to provide a seamless recording experience regardless of external audio events.

## Core Audio Architecture

### 1. **AVAudioEngine Integration**

#### **Single Engine Instance**
```swift
private let engine = AVAudioEngine()
```
- Single engine instance per app lifecycle
- Prevents multiple concurrent recording sessions
- Centralized audio processing pipeline

#### **Hardware Format Detection**
```swift
let hwFormat = engine.inputNode.outputFormat(forBus: 0)
inputFormat = hwFormat
```
- Dynamically detects hardware capabilities
- Ensures format compatibility across devices
- Prevents Core Audio format mismatch exceptions

### 2. **Audio Session Management**

#### **Session Configuration**
```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(.record, mode: .default, options: [.allowBluetooth])
try session.setPreferredSampleRate(Double(selectedQuality.sampleRate))
try session.setActive(true, options: .notifyOthersOnDeactivation)
```

**Key Features:**
- `.record` category for optimal recording performance
- `.allowBluetooth` for wireless headset support
- Dynamic sample rate configuration
- Proper session activation with notification

#### **Quality Settings**
```swift
enum RecordingQuality: String, CaseIterable {
    case low    // 22,050 Hz, 16-bit
    case medium // 44,100 Hz, 16-bit  
    case high   // 48,000 Hz, 24-bit
}
```

### 3. **Voice Processing Integration**

#### **Enhanced Audio Quality**
```swift
private func configureVoiceProcessing() {
    guard AppSettings.shared.voiceProcessingEnabled else { return }
    
    do {
        try engine.inputNode.setVoiceProcessingEnabled(true)
        print("[AudioProcessing] Voice processing enabled successfully")
    } catch {
        print("[AudioProcessing] Failed to enable voice processing: \(error)")
    }
}
```

**Benefits:**
- Automatic noise reduction
- Echo cancellation
- Automatic gain control
- Improved transcription accuracy

## Route Change Handling

### 1. **Route Change Detection**

#### **Notification Registration**
```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleRouteChange),
    name: AVAudioSession.routeChangeNotification,
    object: nil
)
```

#### **Route Change Handler**
```swift
@objc func handleRouteChange(_ notification: Notification) {
    guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

    switch reason {
    case .oldDeviceUnavailable, .newDeviceAvailable:
        pauseRecording()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            // Re-apply audio session configuration
            let session = AVAudioSession.sharedInstance()
            let selectedQuality = AppSettings.shared.quality
            try? session.setPreferredSampleRate(Double(selectedQuality.sampleRate))
            try? session.setCategory(.record, mode: .default, options: [.allowBluetooth])
            self.resumeRecording()
        }
    default:
        print("Ignoring route configuration change to prevent pause/resume loop")
    }
}
```

### 2. **Route Change Scenarios**

#### **Headphones Unplugged**
1. System detects `.oldDeviceUnavailable`
2. Recording pauses immediately
3. Audio session reconfigures for built-in microphone
4. Recording resumes after 300ms stabilization delay

#### **Bluetooth Device Connected**
1. System detects `.newDeviceAvailable`
2. Recording pauses for route stabilization
3. Audio session reconfigures for new device
4. Recording resumes with new audio route

#### **Configuration Changes**
- Ignored to prevent pause/resume loops
- Internal system changes that don't affect user experience

### 3. **Route Change Recovery**

#### **Pause/Resume Logic**
```swift
func pauseRecording() {
    guard isRecording, !isPaused else { return }
    engine.pause()
    isPaused = true
    durationTimer?.invalidate()
    segmentTimer?.invalidate()
    
    // Switch to playback category when paused
    do {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
        print("Failed to switch to playback category when paused: \(error)")
    }
}

func resumeRecording() {
    guard isRecording, isPaused else { return }
    do {
        // Switch back to record category when resuming
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default, options: [.allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        
        try engine.start()
        isPaused = false
        startTimers()
    } catch {
        print("Resume error: \(error)")
    }
}
```

## Audio Interruption Handling

### 1. **Interruption Detection**

#### **Notification Registration**
```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleInterruption),
    name: AVAudioSession.interruptionNotification,
    object: nil
)
```

#### **Interruption Handler**
```swift
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
            if options.contains(.shouldResume) { 
                resumeRecording() 
            }
        }
    @unknown default: 
        break
    }
}
```

### 2. **Interruption Scenarios**

#### **Phone Call Interruption**
1. System sends `.began` interruption
2. Recording pauses immediately
3. User interface shows "Microphone Revoked" error
4. When call ends, system sends `.ended` with `.shouldResume`
5. Recording automatically resumes

#### **Siri Activation**
1. System interrupts audio session
2. Recording pauses
3. After Siri completes, recording may resume based on system flags

#### **Other App Audio**
1. Higher priority audio takes control
2. Recording pauses
3. Automatic resume when audio session becomes available

### 3. **Interruption Recovery**

#### **Automatic Resume Logic**
- Only resumes if system provides `.shouldResume` flag
- Prevents unwanted resumption in inappropriate contexts
- Maintains user control over recording state

#### **Error State Management**
- Sets `recordingError = .microphoneRevoked` during interruptions
- Provides clear user feedback about interruption cause
- Allows manual resume if automatic resume fails

## Background Recording Support

### 1. **Background Task Management**

#### **Background Task Registration**
```swift
#if canImport(UIKit)
private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

private func beginBackgroundTask() {
    backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
        self?.endBackgroundTask()
    }
}

private func endBackgroundTask() {
    if backgroundTaskID != .invalid {
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}
#endif
```

#### **Background Recording Flow**
1. User starts recording
2. Background task begins
3. Recording continues in background
4. Background task ends when recording stops or app terminates

### 2. **Session Recovery**

#### **Active Session Tracking**
```swift
var activeRecordingSessionID: String? {
    get { defaults.string(forKey: Keys.activeSession) }
    nonmutating set {
        if let id = newValue {
            defaults.set(id, forKey: Keys.activeSession)
        } else {
            defaults.removeObject(forKey: Keys.activeSession)
        }
    }
}
```

#### **Recovery on App Launch**
1. Check for active recording session ID
2. If found, attempt to recover session state
3. Clean up incomplete recordings
4. Restore UI state if needed

## Error Handling and Recovery

### 1. **Recording Error Types**

```swift
enum RecordingError: LocalizedError {
    case micPermissionDenied
    case diskFull
    case engineFailure(String)
    case fileWrite(String)
    case microphoneRevoked
}
```

### 2. **Error Recovery Strategies**

#### **Permission Denied**
- Request microphone permission
- Provide clear user guidance
- Graceful degradation to settings

#### **Disk Full**
- Check available space before recording
- Provide user feedback
- Suggest cleanup options

#### **Engine Failure**
- Attempt engine restart
- Fallback to simpler configuration
- User notification with retry option

#### **File Write Errors**
- Automatic retry with exponential backoff
- Fallback to temporary storage
- Data integrity validation

### 3. **Data Integrity Protection**

#### **File Protection**
```swift
private func applyFileProtection(to url: URL) {
    do {
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete], 
            ofItemAtPath: url.path
        )
    } catch {
        print("Failed to apply file protection: \(error)")
    }
}
```

#### **Corruption Detection**
```swift
private func AVAudioFileIsCorrupted(path: String) -> Bool {
    do {
        let url = URL(fileURLWithPath: path)
        _ = try AVAudioFile(forReading: url)
        return false
    } catch {
        return true
    }
}
```

## Performance Optimizations

### 1. **Memory Management**

#### **Streaming Audio Processing**
```swift
engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: hwFormat) { [weak self] buffer, _ in
    autoreleasepool {
        guard let self, let file = self.currentFile else { return }
        do {
            try file.write(from: buffer)
            try self.masterAudioFile?.write(from: buffer)
            self.computeAudioLevel(buffer: buffer)
        } catch {
            // Handle write errors
        }
    }
}
```

#### **Waveform Sample Management**
```swift
private let maxWaveformSamples = 120

// Maintain waveform sample history for the UI
self.waveformSamples.append(level)
if self.waveformSamples.count > self.maxWaveformSamples {
    self.waveformSamples.removeFirst(self.waveformSamples.count - self.maxWaveformSamples)
}
```

### 2. **Battery Optimization**

#### **Efficient Audio Session Management**
- Minimal session category changes
- Proper session deactivation
- Background task optimization

#### **Smart Timer Management**
- Invalidate timers when paused
- Efficient timer scheduling
- Background task coordination

## Testing and Validation

### 1. **Route Change Testing**
```swift
func testRouteChangePausesAndResumesRecording() {
    // Simulate headphones unplugged
    let note = Notification(
        name: AVAudioSession.routeChangeNotification,
        object: AVAudioSession.sharedInstance(),
        userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue]
    )
    NotificationCenter.default.post(note)
    
    // Verify pause and resume behavior
    XCTAssertTrue(vm.isPaused)
    wait(seconds: 0.6)
    XCTAssertFalse(vm.isPaused)
    XCTAssertTrue(vm.isRecording)
}
```

### 2. **Interruption Testing**
```swift
func testInterruptionPausesAndResumes() {
    // Send interruption began
    let beganNote = Notification(
        name: AVAudioSession.interruptionNotification,
        object: AVAudioSession.sharedInstance(),
        userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
    )
    NotificationCenter.default.post(beganNote)
    
    // Verify pause
    XCTAssertTrue(vm.isPaused)
    
    // Send interruption ended with shouldResume
    let endedNote = Notification(
        name: AVAudioSession.interruptionNotification,
        object: AVAudioSession.sharedInstance(),
        userInfo: [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
        ]
    )
    NotificationCenter.default.post(endedNote)
    
    // Verify resume
    XCTAssertFalse(vm.isPaused)
    XCTAssertTrue(vm.isRecording)
}
```

## Future Enhancements

### 1. **Advanced Audio Processing**
- Real-time noise cancellation
- Audio enhancement algorithms
- Multi-channel recording support
- Advanced compression options

### 2. **Enhanced Route Management**
- Bluetooth device prioritization
- Automatic device switching
- Route change prediction
- Custom audio routing

### 3. **Background Processing**
- Extended background recording
- Background transcription processing
- Cloud sync in background
- Advanced background task management

This audio system design provides robust handling of real-world audio challenges while maintaining excellent performance and user experience. 