[✓] Configure audio session for recording with appropriate categories and options
[✓] Handle audio route changes (headphones plugged/unplugged, Bluetooth connections) and interruptions with automatic resumption
[✓] Support background recording continuation when app enters the background
[✓] Provide configurable recording quality settings (sample rate, bit depth, format)
[✓] Implement optional real-time audio level visualization during recording
[✓] Use AVAudioEngine as the core recording engine
[✓] Observe and handle audio session notifications (route changes, interruptions, etc.)
[✓] Gracefully handle recording failures, storage limitations, and permission denials

[✓] Split recordings into configurable time segments (default: 30 seconds)
[✓] Send audio segments to a backend transcription API (e.g., OpenAI Whisper)
[✓] Implement exponential backoff retry logic for failed transcription requests
[✓] Support concurrent processing of multiple transcription requests
[✓] Ensure secure (encrypted) transmission of audio data to the backend
[✓] Queue segments for transcription when the network is unavailable (offline queuing)
[✓] Fallback to local speech-to-text models after 5 consecutive transcription failures

[✓] Design SwiftData models for recording sessions and transcription segments with processing metadata
[✓] Establish relationships between sessions, segments, and transcriptions in SwiftData
[-] Optimize the SwiftData stack for 1 000+ sessions and 10 000+ segments

[✓] Implement recording controls (start / stop / pause) with clear visual feedback
[✓] Build a session list view grouped by date with search and filter capabilities
[✓] Build a session detail view showing segments with transcription status and text
[✓] Provide live UI updates during recording and transcription processes
[✓] Ensure smooth scrolling performance with large datasets via list virtualization
[✓] Implement full VoiceOver support and add accessibility labels throughout the UI
[✓] Gracefully handle loading states in the UI
[✓] Add pull-to-refresh and pagination for long lists
[✓] Display transcription progress indicators
[✓] Show offline / online status indicators in the UI

[✓] Handle audio permission denied or revoked scenarios
[✓] Detect and respond to insufficient storage space
[✓] Manage network failures during transcription gracefully
[✓] Recover from app termination during an active recording session
[✓] Handle audio route changes that occur mid-recording
[✓] Address background processing limitations while recording or transcribing
[✓] Handle errors returned by the transcription service
[✓] Detect and recover from data corruption scenarios

---------------------------------------------------------------------

[✓] Optimize memory usage when working with large audio files
[-] Minimize battery drain during extended recording sessions
[✓] Implement audio file cleanup strategies to manage storage

[✓] Encrypt audio files at rest
[✓] Securely store API tokens using the Keychain
[✓] Follow iOS privacy best practices for microphone access

[✓] Publish the complete Xcode project to a GitHub repository
[X] Write a clear README with setup instructions
[✓] Maintain a proper git history that reflects the development process
[✓] Add code comments explaining complex audio and concurrency logic

[X] Produce an architecture document detailing high-level design decisions
[X] Document the audio system design, including route-change and interruption handling
[X] Document the SwiftData schema and performance optimizations
[X] Compile a list of known issues and areas for future improvement

[✓] Write unit tests for core business logic and data models
[✓] Write integration tests covering the audio system and API interaction
[✓] Write tests for edge cases, error scenarios, and recovery paths
[-] Perform basic performance tests with large datasets

[✓] Implement real-time audio waveform or level-meter visualization (Bonus)
[✓] Add export functionality to share sessions in various formats (Bonus)
[✓] Implement full-text search across transcriptions (Bonus)
[✓] Add custom audio processing such as noise reduction or enhancement (Bonus)
[✓] Develop an iOS widget for quick recording access (Bonus) 