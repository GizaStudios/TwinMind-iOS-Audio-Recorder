import Foundation
import WidgetKit

/// Shared manager for widget functionality that can be used by both main app and widget
class SharedWidgetManager {
    static let shared = SharedWidgetManager()
    
    private let userDefaults = UserDefaults(suiteName: "group.com.gizastudios.twinmind.widget")
    private let recordingKey = "isRecording"
    private let sessionCountKey = "sessionCount"
    private let lastRecordingStartKey = "lastRecordingStart"
    private let recentSessionsKey = "recentSessions"
    
    private init() {}
    
    /// Check if recording is currently active
    func isCurrentlyRecording() -> Bool {
        return userDefaults?.bool(forKey: recordingKey) ?? false
    }
    
    /// Get the total number of recording sessions
    func getSessionCount() -> Int {
        return userDefaults?.integer(forKey: sessionCountKey) ?? 0
    }
    
    /// Start recording by sending a notification to the main app
    func startRecording() {
        // Update widget state
        userDefaults?.set(true, forKey: recordingKey)
        userDefaults?.set(Date(), forKey: lastRecordingStartKey)
        
        // Send notification to main app to start recording
        NotificationCenter.default.post(name: .widgetStartRecording, object: nil)
        
        // Update widget timeline
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Stop recording by sending a notification to the main app
    func stopRecording() {
        // Update widget state
        userDefaults?.set(false, forKey: recordingKey)
        
        // Send notification to main app to stop recording
        NotificationCenter.default.post(name: .widgetStopRecording, object: nil)
        
        // Update widget timeline
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Update session count (called from main app)
    func updateSessionCount(_ count: Int) {
        userDefaults?.set(count, forKey: sessionCountKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Update recording status (called from main app)
    func updateRecordingStatus(_ isRecording: Bool) {
        userDefaults?.set(isRecording, forKey: recordingKey)
        if isRecording {
            userDefaults?.set(Date(), forKey: lastRecordingStartKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Get the last recording start time
    func getLastRecordingStart() -> Date? {
        return userDefaults?.object(forKey: lastRecordingStartKey) as? Date
    }
    
    /// Clear recording state (called when app is terminated)
    func clearRecordingState() {
        userDefaults?.set(false, forKey: recordingKey)
        userDefaults?.removeObject(forKey: lastRecordingStartKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Manual refresh of widget (for testing)
    func refreshWidget() {
        print("[Widget] Manual refresh triggered")
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Update recent sessions for widget display (called from main app)
    func updateRecentSessions(_ sessions: [WidgetSessionInfo]) {
        print("[Widget] SharedWidgetManager: Updating \(sessions.count) sessions")
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(sessions)
            userDefaults?.set(data, forKey: recentSessionsKey)
            print("[Widget] SharedWidgetManager: Successfully encoded and stored \(data.count) bytes")
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("[Widget] Failed to encode recent sessions: \(error)")
        }
    }
}

// MARK: - Widget Session Info
struct WidgetSessionInfo: Codable {
    let title: String
    let createdAt: Date
    let duration: TimeInterval
    let transcriptSnippet: String
    let sessionCount: Int
    
    init(title: String, createdAt: Date, duration: TimeInterval, transcriptSnippet: String, sessionCount: Int) {
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.transcriptSnippet = transcriptSnippet
        self.sessionCount = sessionCount
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let widgetStartRecording = Notification.Name("widgetStartRecording")
    static let widgetStopRecording = Notification.Name("widgetStopRecording")
    static let widgetUpdateSessionCount = Notification.Name("widgetUpdateSessionCount")
    static let sessionUpdated = Notification.Name("sessionUpdated")
    static let openRecordingPage = Notification.Name("openRecordingPage")
}
 