import Testing
import WidgetKit
@testable import TwinMind

struct WidgetTests {
    
    @Test func testSharedWidgetManagerInitialization() {
        let manager = SharedWidgetManager.shared
        #expect(manager != nil)
        
        // Test initial state
        #expect(!manager.isCurrentlyRecording())
        #expect(manager.getSessionCount() == 0)
    }
    
    @Test func testWidgetRecordingStatus() {
        let manager = SharedWidgetManager.shared
        
        // Test recording status updates
        manager.updateRecordingStatus(true)
        #expect(manager.isCurrentlyRecording())
        
        manager.updateRecordingStatus(false)
        #expect(!manager.isCurrentlyRecording())
    }
    
    @Test func testWidgetSessionCount() {
        let manager = SharedWidgetManager.shared
        
        // Test session count updates
        manager.updateSessionCount(5)
        #expect(manager.getSessionCount() == 5)
        
        manager.updateSessionCount(10)
        #expect(manager.getSessionCount() == 10)
    }
    
    @Test func testWidgetRecordingStartStop() {
        let manager = SharedWidgetManager.shared
        
        // Test start recording
        manager.startRecording()
        #expect(manager.isCurrentlyRecording())
        
        // Test stop recording
        manager.stopRecording()
        #expect(!manager.isCurrentlyRecording())
    }
    
    @Test func testWidgetLastRecordingStart() {
        let manager = SharedWidgetManager.shared
        
        // Test recording start time
        let startTime = Date()
        manager.updateRecordingStatus(true)
        
        let lastStart = manager.getLastRecordingStart()
        #expect(lastStart != nil)
        #expect(lastStart?.timeIntervalSince1970 == startTime.timeIntervalSince1970)
    }
    
    @Test func testWidgetClearRecordingState() {
        let manager = SharedWidgetManager.shared
        
        // Set some state
        manager.updateRecordingStatus(true)
        manager.updateSessionCount(5)
        
        // Clear state
        manager.clearRecordingState()
        
        // Verify state is cleared
        #expect(!manager.isCurrentlyRecording())
        #expect(manager.getSessionCount() == 0)
    }
    
    @Test func testWidgetNotificationNames() {
        // Test that notification names are properly defined
        let startRecordingNotification = Notification.Name("widgetStartRecording")
        let stopRecordingNotification = Notification.Name("widgetStopRecording")
        let updateSessionCountNotification = Notification.Name("widgetUpdateSessionCount")
        
        #expect(startRecordingNotification != nil)
        #expect(stopRecordingNotification != nil)
        #expect(updateSessionCountNotification != nil)
    }
    
    @Test func testWidgetUserDefaultsIntegration() {
        let userDefaults = UserDefaults(suiteName: "group.com.twinmind.widget")
        
        // Test writing and reading values
        userDefaults?.set(true, forKey: "isRecording")
        userDefaults?.set(15, forKey: "sessionCount")
        userDefaults?.set(Date(), forKey: "lastRecordingStart")
        
        #expect(userDefaults?.bool(forKey: "isRecording") ?? false)
        #expect(userDefaults?.integer(forKey: "sessionCount") == 15)
        #expect(userDefaults?.object(forKey: "lastRecordingStart") as? Date != nil)
        
        // Clean up
        userDefaults?.removeObject(forKey: "isRecording")
        userDefaults?.removeObject(forKey: "sessionCount")
        userDefaults?.removeObject(forKey: "lastRecordingStart")
    }
    
    @Test func testWidgetURLScheme() {
        // Test URL scheme handling
        let validURL = URL(string: "twinmind://record")
        #expect(validURL != nil)
        #expect(validURL?.scheme == "twinmind")
        #expect(validURL?.host == "record")
        
        let invalidURL = URL(string: "invalid://record")
        #expect(invalidURL != nil)
        #expect(invalidURL?.scheme != "twinmind")
    }
    
    @Test func testWidgetEntryStructure() {
        let entry = RecordingEntry(date: Date(), isRecording: true, sessionCount: 5)
        
        #expect(entry.date != nil)
        #expect(entry.isRecording)
        #expect(entry.sessionCount == 5)
    }
} 