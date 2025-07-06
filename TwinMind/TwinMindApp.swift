//
//  TwinMindApp.swift
//  TwinMind
//
//  Created by Devin Morgan on 7/1/25.
//

import SwiftUI
import SwiftData
import Speech

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
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
