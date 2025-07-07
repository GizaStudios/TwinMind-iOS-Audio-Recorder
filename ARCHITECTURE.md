# TwinMind Architecture Document

## Overview

TwinMind is a robust iOS audio recording application built with SwiftUI and SwiftData that handles real-world audio challenges, integrates with backend transcription services, and efficiently manages large datasets. The application is designed to be production-ready with comprehensive error handling, offline capabilities, and scalable architecture.

## High-Level Architecture

### 1. **MVVM + SwiftUI Architecture**

The application follows the Model-View-ViewModel (MVVM) pattern with SwiftUI:

- **Models**: SwiftData entities (`RecordingSession`, `AudioSegment`, `Transcription`)
- **Views**: SwiftUI views with declarative UI
- **ViewModels**: Observable objects managing business logic and state
- **Services**: Dedicated service classes for specific functionality

### 2. **Core Components**

#### **RecordingViewModel**
- Central coordinator for audio recording lifecycle
- Manages AVAudioEngine configuration and state
- Handles audio session interruptions and route changes
- Coordinates with TranscriptionManager for processing
- Manages recording quality settings and file management

#### **TranscriptionManager**
- Orchestrates transcription pipeline (remote → local fallback)
- Manages network connectivity and offline queuing
- Implements exponential backoff retry logic
- Handles concurrent transcription processing
- Coordinates with SessionSummaryService for AI summaries

#### **HomeViewModel**
- Manages session list with pagination and search
- Handles large dataset virtualization
- Implements search across titles and transcription text
- Manages session grouping by date

### 3. **Data Layer**

#### **SwiftData Schema**
```swift
RecordingSession (1) ←→ (N) AudioSegment (1) ←→ (1) Transcription
```

- **RecordingSession**: Top-level entity representing user recording sessions
- **AudioSegment**: 30-second chunks for independent transcription
- **Transcription**: Results from speech-to-text processing

#### **Performance Optimizations**
- Pagination with 50-item pages for large datasets
- Lazy loading with `onAppear` triggers
- Virtualized lists for smooth scrolling
- Efficient search with case-insensitive matching

### 4. **Audio System Architecture**

#### **AVAudioEngine Integration**
- Single audio engine instance per app lifecycle
- Hardware format detection for optimal compatibility
- Voice processing for noise reduction and enhancement
- Real-time audio level monitoring and waveform generation

#### **File Management**
- CAF format for recording (Core Audio Format)
- Automatic conversion to M4A for compatibility
- File protection with encryption at rest
- Automatic cleanup of orphaned files

### 5. **Network Layer**

#### **Transcription Service**
- Supabase Edge Functions for OpenAI Whisper integration
- HMAC request signing for security
- Exponential backoff retry (1s, 2s, 4s delays)
- Multipart form data for audio file uploads

#### **Session Summary Service**
- AI-powered session summarization
- Truncated payload (4000 chars) for efficiency
- Error handling with retry mechanisms
- Automatic title generation

### 6. **Security Architecture**

#### **Data Protection**
- File protection with `FileProtectionType.complete`
- Keychain storage for API secrets
- HMAC request signing for API authentication
- Encrypted SwiftData store

#### **Privacy Compliance**
- On-device speech recognition fallback
- Local audio processing when possible
- Minimal data transmission to backend
- User consent for microphone access

### 7. **Widget Integration**

#### **Shared Data**
- App Groups for main app ↔ widget communication
- Shared UserDefaults for session counts
- Notification-based updates
- Deep linking with custom URL schemes

### 8. **Error Handling Strategy**

#### **Graceful Degradation**
- Offline mode with local transcription
- Automatic retry with exponential backoff
- Fallback mechanisms for critical failures
- User-friendly error messages

#### **Recovery Mechanisms**
- Session recovery after app termination
- Data integrity checks on app launch
- Automatic file cleanup and repair
- State restoration for interrupted operations

## Design Decisions

### 1. **Why SwiftData over Core Data?**
- Modern Swift-native API
- Better SwiftUI integration
- Simplified schema management
- Automatic migration handling
- Better performance for iOS 17+

### 2. **Why AVAudioEngine over AVAudioRecorder?**
- Real-time audio processing capabilities
- Better control over audio session
- Voice processing integration
- Real-time level monitoring
- More flexible buffer management

### 3. **Why 30-second segmentation?**
- Optimal balance between transcription accuracy and retry efficiency
- Reduces memory usage for large recordings
- Enables parallel processing
- Better error isolation and recovery

### 4. **Why HMAC request signing?**
- Prevents request tampering
- No need to store API keys in app bundle
- Server-side validation capability
- Enhanced security for production deployment

### 5. **Why pagination in HomeViewModel?**
- Handles large datasets efficiently
- Reduces memory usage
- Enables smooth scrolling performance
- Better user experience with thousands of sessions

## Scalability Considerations

### 1. **Database Performance**
- Indexed queries on `createdAt` for date-based grouping
- Efficient relationship queries with lazy loading
- Automatic cleanup of old data (90-day retention)
- Optimized fetch descriptors with limits

### 2. **Memory Management**
- Streaming audio processing to avoid large buffers
- Pagination to limit in-memory session count
- Automatic cleanup of temporary files
- Efficient waveform sample management (120 samples max)

### 3. **Network Efficiency**
- Compressed audio format (M4A) for uploads
- Truncated text payloads for summaries
- Exponential backoff to prevent server overload
- Offline queuing to handle connectivity issues

### 4. **Battery Optimization**
- Efficient audio session management
- Background task handling for recording
- Minimal network requests with smart retry logic
- On-device processing when possible

## Testing Strategy

### 1. **Unit Tests**
- Core business logic validation
- Audio processing pipeline testing
- Network service mocking
- SwiftData model validation

### 2. **Integration Tests**
- End-to-end recording workflows
- Transcription pipeline testing
- Error scenario simulation
- Performance benchmarking

### 3. **UI Tests**
- User interaction flows
- Accessibility validation
- Cross-device compatibility
- Widget integration testing

## Future Considerations

### 1. **Potential Enhancements**
- Cloud sync for cross-device access
- Advanced audio processing (noise cancellation)
- Real-time collaboration features
- Advanced search with semantic understanding

### 2. **Scalability Improvements**
- Background processing for large datasets
- Incremental sync for cloud integration
- Advanced caching strategies
- Microservice architecture for backend

### 3. **Performance Optimizations**
- GPU acceleration for audio processing
- Advanced compression algorithms
- Predictive loading for better UX
- Memory-mapped file access for large audio files

This architecture provides a solid foundation for a production-ready audio recording application with robust error handling, scalable data management, and excellent user experience. 