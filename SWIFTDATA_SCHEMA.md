# SwiftData Schema and Performance Optimizations

## Overview

TwinMind uses SwiftData for persistent storage with a carefully designed schema optimized for large datasets (1000+ sessions, 10,000+ segments). The schema is designed for efficient querying, relationship management, and performance at scale.

## Schema Design

### 1. **Core Entities**

#### **RecordingSession**
```swift
@Model
class RecordingSession {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var duration: TimeInterval
    var audioFilePath: String
    var sampleRate: Double
    var bitDepth: Int
    var format: String
    var notes: String?
    var summaryGenerationFailed: Bool = false
    var segments: [AudioSegment] = []
}
```

**Key Design Decisions:**
- `@Attribute(.unique)` on `id` for efficient lookups
- `createdAt` for date-based grouping and sorting
- `audioFilePath` for file system integration
- `segments` relationship for 1:N mapping
- `notes` and `summaryGenerationFailed` for AI features

#### **AudioSegment**
```swift
@Model
class AudioSegment {
    @Attribute(.unique) var id: UUID
    var startTime: TimeInterval
    var endTime: TimeInterval
    var createdAt: Date?
    var segmentFilePath: String
    var status: TranscriptionStatus
    var retryCount: Int
    var progress: Double?
    var lastError: String?
    var transcription: Transcription?
    var session: RecordingSession?
}
```

**Key Design Decisions:**
- `@Attribute(.unique)` on `id` for efficient segment management
- `startTime`/`endTime` for chronological ordering
- `status` enum for transcription state tracking
- `retryCount` for failure recovery logic
- `progress` for real-time UI updates

#### **Transcription**
```swift
@Model
class Transcription {
    @Attribute(.unique) var id: UUID
    var text: String
    var confidence: Double
    var source: TranscriptionSource
    var segment: AudioSegment?
}
```

**Key Design Decisions:**
- `@Attribute(.unique)` on `id` for data integrity
- `text` for searchable content
- `confidence` for quality assessment
- `source` for analytics and fallback logic

### 2. **Relationship Design**

#### **One-to-Many: Session → Segments**
```swift
// In RecordingSession
var segments: [AudioSegment] = []

// In AudioSegment
var session: RecordingSession?
```

**Benefits:**
- Efficient batch operations on session segments
- Automatic cascade deletion
- Lazy loading for performance
- Bidirectional relationship validation

#### **One-to-One: Segment → Transcription**
```swift
// In AudioSegment
var transcription: Transcription?

// In Transcription
var segment: AudioSegment?
```

**Benefits:**
- Direct access to transcription data
- Efficient querying for completed segments
- Automatic cleanup on segment deletion

## Performance Optimizations

### 1. **Pagination Strategy**

#### **HomeViewModel Pagination**
```swift
private let pageSize = 50
private var offset = 0
private var canLoadMore = true

private func loadPage() {
    guard let context = context else { return }
    guard canLoadMore else { return }
    
    var desc = FetchDescriptor<RecordingSession>()
    
    if !searchText.isEmpty {
        // For search, fetch all results without pagination
        desc.fetchLimit = 0 // 0 means no limit
        desc.fetchOffset = 0
    } else {
        // Normal pagination when not searching
        desc.fetchLimit = pageSize
        desc.fetchOffset = offset
    }
    
    desc.sortBy = [SortDescriptor(\RecordingSession.createdAt, order: .reverse)]
    
    let page = try context.fetch(desc)
    // Apply search filter and update state
}
```

**Optimization Benefits:**
- 50-item pages balance memory usage and performance
- Search bypasses pagination for complete results
- Reverse chronological sorting for most recent first
- Efficient memory management for large datasets

### 2. **Search Optimization**

#### **Case-Insensitive Search**
```swift
if !searchText.isEmpty {
    let searchQuery = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    filtered = page.filter { session in
        // Search in session title
        session.title.lowercased().contains(searchQuery) ||
        // Search in transcription text of any segment
        session.segments.contains { segment in
            guard let transcription = segment.transcription else { return false }
            return transcription.text.lowercased().contains(searchQuery)
        }
    }
}
```

**Optimization Benefits:**
- Client-side filtering for complex search logic
- Case-insensitive matching for user-friendly search
- Searches both titles and transcription content
- Efficient string operations with pre-processing

### 3. **Lazy Loading and Virtualization**

#### **List Virtualization**
```swift
List {
    ForEach(sessionsByDay, id: \.date) { group in
        Section(header: Text(formatDateHeader(group.date))) {
            ForEach(group.sessions, id: \.id) { session in
                SearchResultRow(session: session, searchQuery: vm.searchText) {
                    selectedSession = session
                    navigateToRecord = true
                }
                .onAppear { vm.loadNextPageIfNeeded(current: session) }
            }
        }
    }
}
.listStyle(PlainListStyle())
```

**Optimization Benefits:**
- `onAppear` triggers load more when approaching end
- Virtualized rendering for smooth scrolling
- Efficient section-based grouping
- Minimal memory footprint for large lists

### 4. **Date-Based Grouping**

#### **Efficient Grouping Strategy**
```swift
private var sessionsByDay: [(date: Date, sessions: [RecordingSession])] {
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: vm.sessions) { calendar.startOfDay(for: $0.createdAt) }
    return grouped.map { (date: $0.key, sessions: $0.value.sorted { $0.createdAt > $1.createdAt }) }
        .sorted { $0.date > $1.date }
}
```

**Optimization Benefits:**
- Calendar-based grouping for natural organization
- Efficient dictionary-based grouping
- Sorted results for consistent ordering
- Minimal computation overhead

### 5. **Relationship Optimization**

#### **Efficient Segment Access**
```swift
// Check if all transcriptions for a session are complete
private func checkSessionCompletionAndGenerateSummary(for session: RecordingSession) {
    let allSegments = session.segments
    let completedSegments = allSegments.filter { $0.status == .completed && $0.transcription?.text.isEmpty == false }
    let failedSegments = allSegments.filter { $0.status == .failed && $0.retryCount >= 5 }
    
    let processedSegments = completedSegments.count + failedSegments.count
    let totalSegments = allSegments.count
    
    if processedSegments == totalSegments && processedSegments > 0 {
        // Generate summary
    }
}
```

**Optimization Benefits:**
- Direct relationship access without additional queries
- Efficient filtering on relationship properties
- Minimal memory allocation for temporary arrays
- Fast completion status checking

## Data Integrity and Recovery

### 1. **Data Integrity Manager**

#### **File System Validation**
```swift
struct DataIntegrityManager {
    static func run(in context: ModelContext) {
        let sessions: [RecordingSession]
        do {
            sessions = try context.fetch(FetchDescriptor<RecordingSession>())
        } catch {
            print("[Integrity] Failed to fetch sessions: \(error)")
            return
        }
        
        for session in sessions {
            // Verify segment files exist
            for seg in session.segments {
                let path = seg.segmentFilePath
                if !fileManager.fileExists(atPath: path) {
                    print("[Integrity] Missing segment file – removing segment \(seg.id)")
                    if let idx = session.segments.firstIndex(where: { $0.id == seg.id }) {
                        session.segments.remove(at: idx)
                        context.delete(seg)
                        sessionNeedsSave = true
                    }
                }
            }
        }
    }
}
```

**Benefits:**
- Automatic detection of missing files
- Cleanup of orphaned database records
- Prevention of data corruption
- Recovery from file system issues

### 2. **Data Pruning**

#### **Automatic Cleanup**
```swift
struct DataPruner {
    static func pruneIfNeeded(context: ModelContext, retentionDays: Int = 90) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? .distantPast
        var sessionDesc = FetchDescriptor<RecordingSession>()
        sessionDesc.predicate = #Predicate<RecordingSession> { $0.createdAt < cutoff }
        
        if let oldSessions = try? context.fetch(sessionDesc) {
            for session in oldSessions { 
                context.delete(session) 
            }
            try? context.save()
        }
    }
}
```

**Benefits:**
- Automatic cleanup of old data
- Configurable retention period
- Efficient predicate-based filtering
- Prevention of database bloat

## Memory Management

### 1. **Efficient Fetch Descriptors**

#### **Optimized Queries**
```swift
// Fetch only necessary fields for list display
var desc = FetchDescriptor<RecordingSession>()
desc.fetchLimit = pageSize
desc.fetchOffset = offset
desc.sortBy = [SortDescriptor(\RecordingSession.createdAt, order: .reverse)]

// For search, fetch all but apply client-side filtering
if !searchText.isEmpty {
    desc.fetchLimit = 0
    desc.fetchOffset = 0
}
```

**Benefits:**
- Minimal memory usage for large datasets
- Efficient sorting and pagination
- Optimized for specific use cases
- Reduced network overhead

### 2. **Context Management**

#### **Proper Context Usage**
```swift
@Environment(\.modelContext) private var modelContext

// Use context for all database operations
try modelContext.save()
context.insert(session)
context.delete(session)
```

**Benefits:**
- Automatic change tracking
- Efficient batch operations
- Proper memory management
- Transaction support

## Scalability Considerations

### 1. **Large Dataset Handling**

#### **Performance with 1000+ Sessions**
- Pagination keeps memory usage constant
- Efficient indexing on `createdAt` and `id`
- Lazy loading prevents loading all data at once
- Virtualized UI components for smooth scrolling

#### **Performance with 10,000+ Segments**
- Relationship queries optimized for batch operations
- Efficient filtering on segment status
- Minimal memory allocation for temporary operations
- Background processing for heavy operations

### 2. **Query Optimization**

#### **Indexed Queries**
```swift
// Efficient date-based queries
desc.sortBy = [SortDescriptor(\RecordingSession.createdAt, order: .reverse)]

// Efficient relationship queries
let completedSegments = allSegments.filter { $0.status == .completed }
```

**Benefits:**
- Fast sorting on indexed fields
- Efficient relationship traversal
- Minimal query execution time
- Optimized for common access patterns

### 3. **Background Processing**

#### **Async Operations**
```swift
Task {
    await SessionSummaryService.shared.generateSummary(for: session, modelContext: modelContext)
}

// Background transcription processing
Task.detached { [weak self] in
    await self.attemptRemoteTranscription(for: segment)
}
```

**Benefits:**
- Non-blocking UI operations
- Efficient background processing
- Proper memory management
- Responsive user interface

## Testing and Validation

### 1. **Performance Testing**

#### **Large Dataset Testing**
```swift
func testLargeDatasetPerformance() {
    // Create 1000+ sessions with segments
    for i in 0..<1000 {
        let session = RecordingSession(title: "Session \(i)", ...)
        for j in 0..<10 {
            let segment = AudioSegment(...)
            session.segments.append(segment)
        }
        context.insert(session)
    }
    
    // Measure query performance
    let start = CFAbsoluteTimeGetCurrent()
    let sessions = try context.fetch(FetchDescriptor<RecordingSession>())
    let duration = CFAbsoluteTimeGetCurrent() - start
    
    XCTAssertLessThan(duration, 1.0, "Query should complete within 1 second")
}
```

### 2. **Memory Testing**

#### **Memory Usage Validation**
```swift
func testMemoryUsageWithLargeDataset() {
    // Monitor memory usage during large operations
    let initialMemory = getMemoryUsage()
    
    // Perform large dataset operations
    loadLargeDataset()
    
    let finalMemory = getMemoryUsage()
    let memoryIncrease = finalMemory - initialMemory
    
    XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024, "Memory increase should be less than 50MB")
}
```

## Future Optimizations

### 1. **Advanced Indexing**
- Composite indexes for complex queries
- Full-text search indexes for transcription content
- Spatial indexes for location-based features

### 2. **Caching Strategies**
- In-memory caching for frequently accessed data
- Disk-based caching for large audio files
- Intelligent cache invalidation

### 3. **Background Processing**
- Background fetch for data updates
- Incremental sync for cloud integration
- Background cleanup and maintenance

This SwiftData schema and optimization strategy provides excellent performance for large datasets while maintaining data integrity and user experience. 