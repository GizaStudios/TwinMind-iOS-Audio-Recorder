//
//  TwinMindApp.swift
//  TwinMind
//
//  Created by Devin Morgan on 7/1/25.
//

import SwiftUI
import SwiftData
import Speech
import WidgetKit

@main
struct TwinMindApp: App {
    @StateObject private var recordingViewModel = RecordingViewModel()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            RecordingSession.self,
            AudioSegment.self,
            Transcription.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            // Apply Complete protection to persistent store file
            if let url = container.configurations.first?.url {
                do {
                    try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
                    print("[Security] Applied FileProtection.complete to store")
                } catch {
                    print("[Security] Failed to apply file protection: \(error)")
                }
            }
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recordingViewModel)
                .environmentObject(BannerManager.shared)
                .overlay(BannerOverlay().environmentObject(BannerManager.shared))
                .preferredColorScheme(.light)
                .onAppear {
                    recordingViewModel.modelContext = sharedModelContainer.mainContext
                    
                    // Clean up old export files on app launch
                    ExportManager.cleanupOldExports()
                    
                    // Run integrity check/repair
                    DataIntegrityManager.run(in: sharedModelContainer.mainContext)
                    
                    // Request speech recognition authorization
                    SFSpeechRecognizer.requestAuthorization { authStatus in
                        // Handle authorization status on the main thread
                        DispatchQueue.main.async {
                            switch authStatus {
                            case .authorized:
                                print("Speech recognition authorized.")
                            case .denied:
                                print("User denied access to speech recognition.")
                            case .restricted:
                                print("Speech recognition restricted on this device.")
                            case .notDetermined:
                                print("Speech recognition not yet authorized.")
                            @unknown default:
                                fatalError()
                            }
                        }
                    }
                    
                    // Setup widget integration
                    setupWidgetIntegration()
                    
                    // Update widget data
                    updateWidgetSessionCount()
                }
                .onOpenURL { url in
                    handleWidgetURL(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    // MARK: - Widget Integration
    
    private func setupWidgetIntegration() {
        // Listen for widget notifications
        NotificationCenter.default.addObserver(
            forName: .widgetStartRecording,
            object: nil,
            queue: .main
        ) { _ in
            self.handleWidgetStartRecording()
        }
        
        NotificationCenter.default.addObserver(
            forName: .widgetStopRecording,
            object: nil,
            queue: .main
        ) { _ in
            self.handleWidgetStopRecording()
        }
        
        // Listen for session updates to refresh widget
        NotificationCenter.default.addObserver(
            forName: .tmSessionCreated,
            object: nil,
            queue: .main
        ) { _ in
            self.updateWidgetSessionCount()
        }
        
        // Update widget with current session count
        updateWidgetSessionCount()
    }
    
    private func handleWidgetStartRecording() {
        print("[Widget] Received start recording request")
        recordingViewModel.startRecording()
        // Notify UI to navigate to recording page
        NotificationCenter.default.post(name: .openRecordingPage, object: nil)
    }
    
    private func handleWidgetStopRecording() {
        print("[Widget] Received stop recording request")
        recordingViewModel.stopRecording()
    }
    
    private func handleWidgetURL(_ url: URL) {
        guard url.scheme == "twinmind" else { return }
        
        print("[Widget] Handling URL: \(url)")
        
        switch url.host {
        case "record":
            handleRecordRequest()
        default:
            break
        }
    }
    
    private func handleRecordRequest() {
        print("[Widget] Handling record request, current recording state: \(recordingViewModel.isRecording)")
        
        if recordingViewModel.isRecording {
            // If currently recording, just stop it
            print("[Widget] Stopping current recording")
            recordingViewModel.stopRecording()
        } else {
            // If not recording, start new recording and navigate
            print("[Widget] Starting new recording session")
            recordingViewModel.startRecording()
            
            // Navigate to recording page
            NotificationCenter.default.post(name: .openRecordingPage, object: nil)
            print("[Widget] Posted navigation notification")
        }
    }
    
    private func updateWidgetSessionCount() {
        let context = sharedModelContainer.mainContext
        let fetchDescriptor = FetchDescriptor<RecordingSession>()
        
        do {
            let sessions = try context.fetch(fetchDescriptor)
            print("[Widget] Found \(sessions.count) sessions in database")
            SharedWidgetManager.shared.updateSessionCount(sessions.count)
            
            // Update recent sessions for widget
            updateWidgetRecentSessions(sessions: sessions)
        } catch {
            print("[Widget] Failed to fetch session count: \(error)")
        }
    }
    
    private func updateWidgetRecentSessions(sessions: [RecordingSession]) {
        print("[Widget] Updating recent sessions, total sessions: \(sessions.count)")
        
        let recentSessions = sessions
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
            .compactMap { session -> WidgetSessionInfo? in
                print("[Widget] Processing session: \(session.title), segments: \(session.segments.count)")
                
                // Get transcript snippet from the first segment with completed transcription
                let transcriptSnippet = session.segments
                    .first { $0.transcription?.text.isEmpty == false }
                    .flatMap { $0.transcription?.text }
                    ?? "No transcript available"
                
                print("[Widget] Found transcript snippet: \(String(transcriptSnippet.prefix(50)))...")
                
                // Truncate transcript snippet to reasonable length
                let truncatedSnippet = String(transcriptSnippet.prefix(100))
                let finalSnippet = transcriptSnippet.count > 100 ? truncatedSnippet + "..." : truncatedSnippet
                
                return WidgetSessionInfo(
                    title: session.title,
                    createdAt: session.createdAt,
                    duration: session.duration,
                    transcriptSnippet: finalSnippet,
                    sessionCount: sessions.count
                )
            }
        
        print("[Widget] Sending \(recentSessions.count) recent sessions to widget")
        SharedWidgetManager.shared.updateRecentSessions(Array(recentSessions))
    }
    

}
