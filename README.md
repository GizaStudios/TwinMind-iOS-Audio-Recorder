# TwinMind 📱🎙️

A robust iOS audio recording application that handles real-world audio challenges, integrates with backend transcription services, and efficiently manages large datasets with SwiftData.

## 🌟 Features

### 🎙️ **Advanced Audio Recording**
- **Production-ready audio system** using AVAudioEngine
- **Real-time audio monitoring** with waveform visualization
- **Configurable quality settings** (Low: 22kHz/16-bit, Medium: 44kHz/16-bit, High: 48kHz/24-bit)
- **Voice processing** with noise reduction and echo cancellation
- **Background recording** support with proper task management

### 🔄 **Intelligent Audio Handling**
- **Route change recovery** (headphones plugged/unplugged, Bluetooth connections)
- **Audio interruption handling** (phone calls, Siri, notifications) with automatic resumption
- **Pause/resume functionality** with visual feedback
- **Error recovery** for recording failures and storage limitations

### 🤖 **Smart Transcription System**
- **Automatic 30-second segmentation** for optimal processing
- **Cloud transcription** using OpenAI Whisper via Supabase Edge Functions
- **Offline fallback** to Apple's local speech recognition
- **Exponential backoff retry** with up to 5 attempts
- **Concurrent processing** of multiple transcription requests
- **Secure transmission** with HMAC request signing

### 📊 **AI-Powered Summaries**
- **Automatic session summarization** using AI processing
- **Smart title generation** based on content
- **Session notes** with key insights and highlights
- **Retry mechanism** for failed summary generation

### 📱 **Modern iOS Widget**
- **Quick recording access** from home screen
- **Real-time status updates** (recording/not recording)
- **Session count display** with recent activity
- **Deep linking** to app for seamless navigation
- **Multiple widget sizes** (Small, Medium, Large)

### 🔍 **Powerful Search & Organization**
- **Full-text search** across session titles and transcriptions
- **Date-based grouping** with efficient pagination
- **Session management** with export and sharing capabilities
- **Large dataset optimization** (1000+ sessions, 10,000+ segments)

### 🛡️ **Security & Privacy**
- **File encryption** at rest with FileProtection.complete
- **Secure API communication** with HMAC signing
- **Keychain storage** for sensitive data
- **Local-first processing** with optional cloud fallback
- **Privacy-focused design** with minimal data transmission

## 📋 Requirements

### **Development Environment**
- **Xcode 15.0+** (iOS 17.0+ deployment target)
- **iOS 17.0+** for SwiftData and modern audio features
- **macOS 14.0+** for development
- **Swift 5.9+** for latest language features

### **Device Requirements**
- **iPhone** with iOS 17.0 or later
- **Microphone access** for recording functionality
- **Internet connection** for cloud transcription (optional)
- **Storage space** for audio files and transcriptions

### **Dependencies**
- **SwiftData** for data persistence
- **AVFoundation** for audio processing
- **Speech** framework for local transcription
- **Network** framework for connectivity monitoring
- **WidgetKit** for iOS widget functionality

## 🚀 Installation & Setup

### **1. Clone the Repository**
```bash
git clone https://github.com/yourusername/TwinMind.git
cd TwinMind
```

### **2. Open in Xcode**
```bash
open TwinMind.xcodeproj
```

### **3. Configure Bundle Identifiers**
Update the bundle identifiers in the project settings:

**Main App:**
- Bundle Identifier: `com.yourcompany.twinmind`
- Team: Your Apple Developer Team

**Widget Extension:**
- Bundle Identifier: `com.yourcompany.twinmind.widget`
- Team: Your Apple Developer Team

### **4. Configure App Groups**
Ensure both targets have the same App Group:
- App Group: `group.com.yourcompany.twinmind.widget`

### **5. Set Up API Keys (Optional)**
For cloud transcription functionality:

1. **Create a Supabase project** and set up Edge Functions
2. **Configure HMAC secret** in iOS Keychain:
   ```swift
   // Add to your app's initialization
   try SecureStore.save(key: "tm_hmac_secret", value: "your_hmac_secret")
   ```
3. **Configure JWT token** (if required):
   ```swift
   try SecureStore.save(key: "tm_jwt_token", value: "your_jwt_token")
   ```

### **6. Build and Run**
1. Select your target device or simulator
2. Press `Cmd + R` to build and run
3. Grant microphone permissions when prompted

## 🔧 Configuration

### **Audio Settings**
Configure recording quality and processing in `AppSettings.swift`:

```swift
// Recording quality options
enum RecordingQuality: String, CaseIterable {
    case low    // 22,050 Hz, 16-bit
    case medium // 44,100 Hz, 16-bit  
    case high   // 48,000 Hz, 24-bit
}

// Voice processing settings
var voiceProcessingEnabled: Bool = true
var noiseReductionEnabled: Bool = true
var echoCancellationEnabled: Bool = true
var automaticGainControlEnabled: Bool = true
```

### **Transcription Settings**
Configure transcription behavior in `TranscriptionManager.swift`:

```swift
// Retry configuration
private let maxRetryAttempts = 5
private let retryDelayMultiplier = 2.0

// Network monitoring
private let networkCheckInterval: TimeInterval = 30.0
```

### **Data Management**
Configure data retention and cleanup in `DataPruner.swift`:

```swift
// Data retention (90 days default)
static func pruneIfNeeded(context: ModelContext, retentionDays: Int = 90)
```

## 📱 Usage

### **Recording Audio**
1. **Start Recording**: Tap the record button to begin
2. **Monitor Audio**: View real-time waveform and audio levels
3. **Pause/Resume**: Tap pause to temporarily stop, resume to continue
4. **Stop Recording**: Tap stop to end the session

### **Managing Sessions**
1. **View Sessions**: Browse recordings grouped by date
2. **Search**: Use the search bar to find specific content
3. **View Details**: Tap a session to see segments and transcriptions
4. **Export**: Share audio files and transcripts

### **Widget Usage**
1. **Add Widget**: Long press home screen → Add Widget → TwinMind
2. **Quick Record**: Tap widget to start recording immediately
3. **View Status**: See recording status and session count
4. **Navigate**: Tap to open the app

## 🧪 Testing

### **Unit Tests**
Run unit tests to verify core functionality:
```bash
# Run all tests
xcodebuild test -scheme TwinMind -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -scheme TwinMind -only-testing:TwinMindTests/RecordingFeatureTests
```

### **UI Tests**
Run UI tests for user interface validation:
```bash
xcodebuild test -scheme TwinMind -only-testing:TwinMindUITests
```

### **Performance Testing**
Test with large datasets:
```bash
# Run performance tests
xcodebuild test -scheme TwinMind -only-testing:TwinMindTests/PerformanceTests
```

## 📁 Project Structure

```
TwinMind/
├── TwinMind/                    # Main app target
│   ├── TwinMindApp.swift       # App entry point
│   ├── Models.swift            # SwiftData models
│   ├── RecordingViewModel.swift # Audio recording logic
│   ├── TranscriptionManager.swift # Transcription pipeline
│   ├── HomeViewModel.swift     # Session list management
│   ├── Views/                  # SwiftUI views
│   ├── Services/               # Business logic services
│   └── Utilities/              # Helper classes
├── TwinMindWidgetExtension/    # iOS widget target
├── TwinMindTests/              # Unit tests
├── TwinMindUITests/            # UI tests
└── Documentation/              # Architecture docs
```

## 🔒 Privacy & Security

### **Data Collection**
- **Audio recordings** stored locally on device
- **Transcription text** stored in encrypted SwiftData store
- **No personal data** transmitted to third parties
- **Optional cloud processing** for transcription only

### **Permissions**
- **Microphone**: Required for audio recording
- **Speech Recognition**: Optional for offline transcription
- **Bluetooth**: Optional for wireless audio devices
- **Local Network**: Optional for AirPods and similar devices

### **Data Retention**
- **90-day automatic cleanup** of old recordings
- **User-controlled deletion** of individual sessions
- **No cloud storage** of audio files
- **Secure file protection** with iOS encryption

## 🐛 Troubleshooting

### **Common Issues**

#### **Recording Won't Start**
- Check microphone permissions in Settings
- Ensure no other app is using the microphone
- Verify sufficient storage space (50MB minimum)

#### **Transcription Fails**
- Check internet connection for cloud transcription
- Verify speech recognition permissions
- Check API configuration for cloud services

#### **Widget Not Updating**
- Ensure App Groups are properly configured
- Check widget permissions in Settings
- Restart the app and widget

#### **Audio Quality Issues**
- Adjust recording quality settings
- Enable voice processing for noise reduction
- Check audio route (headphones vs. built-in mic)

### **Debug Mode**
Enable debug logging by setting environment variables:
```bash
# Enable audio debug logging
export TWINMIND_AUDIO_DEBUG=1

# Enable transcription debug logging
export TWINMIND_TRANSCRIPTION_DEBUG=1
```

## 📚 Documentation

- **[Architecture Document](ARCHITECTURE.md)** - High-level design decisions
- **[Audio System Design](AUDIO_SYSTEM_DESIGN.md)** - Route change and interruption handling
- **[SwiftData Schema](SWIFTDATA_SCHEMA.md)** - Data model and performance optimizations
- **[Known Issues](KNOWN_ISSUES_AND_FUTURE_IMPROVEMENTS.md)** - Limitations and future plans
- **[Data Usage](DATA_USAGE.md)** - Privacy and data handling details

## 🤝 Contributing

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit your changes**: `git commit -m 'Add amazing feature'`
4. **Push to the branch**: `git push origin feature/amazing-feature`
5. **Open a Pull Request**

### **Development Guidelines**
- Follow Swift style guidelines
- Add unit tests for new features
- Update documentation for API changes
- Test on multiple iOS versions and devices

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **OpenAI Whisper** for cloud transcription
- **Supabase** for serverless backend services
- **Apple** for iOS frameworks and development tools
- **SwiftUI** for modern iOS development

## 📞 Support

For support and questions:
- **Email**: support@twinmind.app
- **Issues**: [GitHub Issues](https://github.com/yourusername/TwinMind/issues)
- **Documentation**: [Project Wiki](https://github.com/yourusername/TwinMind/wiki)

---

**TwinMind** - Transform your thoughts into organized, searchable memories. 🧠✨ 