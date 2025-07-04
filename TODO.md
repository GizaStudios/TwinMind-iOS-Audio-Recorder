[-] Implement automatic audio route-change recovery (pause and resume with correct device)  
[-] Enable true background recording with Background Modes entitlement and background task handling  
[-] Wire quality settings from SettingsSheet (sample-rate, bit-depth, format) into AVAudioEngine configuration  
[ ] Add real-time audio level / waveform visualisation bound to `audioLevel`  
[ ] Expose Pause / Resume control in the UI connected to `pauseRecording` and `resumeRecording`  
[ ] Add robust error handling for microphone permission denial, disk-full, AVAudioEngine failure, and microphone revocation  
[ ] Recover interrupted recording session on next app launch  
[ ] Implement cleanup strategy for large / orphaned CAF and temporary M4A files  
[ ] Encrypt on-device audio files  
[ ] Implement exponential back-off and retry logic for transcription failures and update `retryCount`  
[ ] Queue failed segments for offline retry and automatically resend when network returns  
[ ] Add fallback to local speech-to-text after 5 consecutive failures  
[ ] Add TLS pinning or request signing for secure transcription uploads  
[ ] Move API keys / JWT out of source code and store securely in Keychain  
[ ] Add indexes and sort descriptors in SwiftData for large datasets  
[ ] Implement batch fetch and pagination APIs for memory-efficient scrolling  
[ ] Enable encryption of the SwiftData persistent store  
[ ] Create migration / versioning strategy and data-pruning policy  
[ ] Implement search and filter on the sessions list  
[ ] Implement pagination or virtualised list for very large datasets  
[ ] Add live transcription progress indicators per segment and per session  
[ ] Show loading, success, and error banners for network and transcription states  
[ ] Add full accessibility support (VoiceOver labels, dynamic type, contrast)  
[ ] Show offline / online status indicator in the UI  
[ ] Add pull-to-refresh to Home and Session views  
[ ] Connect settings toggles (background recording, show levels) to actual behaviour  
[ ] Implement “Export Audio” functionality  
[ ] Implement “Export Transcript” functionality  
[ ] Implement “Share” functionality  
[ ] Replace placeholder waveforms with real-time waveform component  
[ ] Implement disk-space pre-check and graceful stop with user alert  
[ ] Implement comprehensive network-failure handling with retries / offline queue  
[ ] Add data-corruption detection and repair for audio files and SwiftData store  
[ ] Cleanly stop recording when low-memory or termination signal is received  
[ ] Optimise memory usage during long recordings (stream chunks, avoid large buffers)  
[ ] Lower sample-rate or processing load in background to save battery  
[ ] Implement background upload of segments via `URLSession` background tasks  
[ ] Implement old-session cleanup or archive routine to free storage  
[ ] Update Info.plist privacy strings and document data usage  
[ ] Create unit tests for RecordingViewModel (segmentation, retry logic, level calculation)  
[ ] Create integration tests for audio interruptions and recovery paths  
[ ] Create network stubs and tests for TranscriptionService success / failure cases  
[ ] Create UI tests for recording flow, background resume, and error banners  
[ ] Add performance tests for scrolling through 10 000+ segments