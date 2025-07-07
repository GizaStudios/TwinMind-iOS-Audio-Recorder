//
//  HomeView.swift
//  TwinMind
//
//  Created by Devin Morgan on 7/2/25.
//

import SwiftUI
import SwiftData
import AVFoundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Brand colours
extension Color {
    static let tmBlue = Color(red: 0.03, green: 0.46, blue: 0.71) // #0A75B5 approx
    static let tmBlueDark = Color(red: 0.02, green: 0.34, blue: 0.55)
    static let tmYellow = Color(red: 1.0, green: 0.71, blue: 0.04) // avatar bg
}

// MARK: - Audio Playbar Component
struct AudioPlaybar: View {
    let audioFilePath: String
    let duration: TimeInterval
    let recordingViewModel: RecordingViewModel?
    
    @State private var totalDuration: TimeInterval
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var timer: Timer?
    
    init(audioFilePath: String, duration: TimeInterval, recordingViewModel: RecordingViewModel? = nil) {
        self.audioFilePath = audioFilePath
        self.duration = duration
        self.recordingViewModel = recordingViewModel
        _totalDuration = State(initialValue: duration)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(totalDuration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: currentTime, total: max(totalDuration, 1))
                        .accentColor(.blue)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .onAppear(perform: setupAudioPlayer)
        .onDisappear(perform: stopPlayback)
    }
    
    private func setupAudioPlayer() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Always switch to playback (no options) – this is a safe category for AVAudioPlayer.
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("AVAudioSession playback activation error: \(error)")
        }

        guard let resolvedURL = resolveAudioURL(originalPath: audioFilePath) else {
            print("Audio file not found after resolution attempts: \(audioFilePath)")
            return
        }

        do {
            // First try letting the system infer the type.
            audioPlayer = try AVAudioPlayer(contentsOf: resolvedURL)
         
            audioPlayer?.prepareToPlay()
            // Always use the actual file duration for accurate progress view
            totalDuration = audioPlayer?.duration ?? totalDuration
        } catch {
            // Retry with CAF hint in case inference failed (older iOS versions).
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: resolvedURL, fileTypeHint: AVFileType.caf.rawValue)
                audioPlayer?.prepareToPlay()
                // Always use the actual file duration for accurate progress view
                totalDuration = audioPlayer?.duration ?? totalDuration
            } catch {
                print("Audio player setup error: \(error)")
            }
        }
    }
    
    private func togglePlayPause() {
        // Prevent playback if recording is active
        if let recordingViewModel = recordingViewModel, recordingViewModel.isRecording {
            print("Cannot play audio while recording is active")
            return
        }
        
        guard let player = audioPlayer else { return }
        
        if isPlaying {
            player.pause()
            timer?.invalidate()
            timer = nil
        } else {
            player.play()
            startTimer()
        }
        isPlaying.toggle()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let player = audioPlayer {
                currentTime = min(player.currentTime, totalDuration)
                if !player.isPlaying {
                    isPlaying = false
                    timer?.invalidate()
                    timer = nil
                }
            }
        }
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        timer?.invalidate()
        timer = nil
        isPlaying = false
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Path Resolution
    private func resolveAudioURL(originalPath: String) -> URL? {
        let fileManager = FileManager.default
        let originalURL = URL(fileURLWithPath: originalPath)
        if fileManager.fileExists(atPath: originalURL.path) { return originalURL }

        // Attempt 1: same filename in current Recordings directory (handles new app container)
        let recordingsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings")
        let candidate = recordingsDir.appendingPathComponent(originalURL.lastPathComponent)
        if fileManager.fileExists(atPath: candidate.path) { return candidate }

        // Attempt 2: try with .m4a extension (in case master files were converted)
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        let m4aCandidate = recordingsDir.appendingPathComponent(baseName + ".m4a")
        if fileManager.fileExists(atPath: m4aCandidate.path) { return m4aCandidate }

        return nil // give up
    }
}

struct HomeView: View {
    enum Tab: String, CaseIterable, Identifiable { case memories, calendar, questions; var id: String { rawValue } }
    
    @State private var selectedTab: Tab = .memories
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var recordingViewModel: RecordingViewModel
    @StateObject private var vm = HomeViewModel()
    @State private var navigateToRecord = false
    @State private var selectedSession: RecordingSession?
    @State private var showSettings = false
    @State private var showDeleteAlert = false
    @State private var sessionToDelete: RecordingSession?
    @State private var showIntroScreen = false
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false
    
    // Group sessions by calendar day for sectioned list
    private var sessionsByDay: [(date: Date, sessions: [RecordingSession])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: vm.sessions) { calendar.startOfDay(for: $0.createdAt) }
        return grouped.map { (date: $0.key, sessions: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Hidden NavigationLink for programmatic navigation
            NavigationLink(destination: recordingViewDestination, isActive: $navigateToRecord) {
                EmptyView()
            }
            .onChange(of: navigateToRecord) { newValue in
                print("[Navigation] navigateToRecord changed to: \(newValue)")
            }
            header
            Divider()
            tabBar
            Divider()
            TabView(selection: $selectedTab) {
                memoriesPage.tag(Tab.memories)
                placeholder("Calendar coming soon").tag(Tab.calendar)
                placeholder("Questions coming soon").tag(Tab.questions)
            }
#if os(iOS)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
#endif
            .animation(.easeInOut, value: selectedTab)
            captureBar
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showSettings) {
            SettingsSheet(isPresented: $showSettings)
        }
        .sheet(isPresented: $showIntroScreen) {
            IntroScreen(isPresented: $showIntroScreen)
        }
        .onChange(of: showIntroScreen) { newValue in
            // If intro screen was dismissed (set to false), mark as seen
            if !newValue && !hasSeenIntro {
                print("[Intro] Intro screen dismissed, marking as seen")
                UserDefaults.standard.set(true, forKey: "hasSeenIntro")
                hasSeenIntro = true
            }
        }
        // only in-section search bar
        .onAppear {
            vm.setContext(modelContext)
            // Check if user has seen intro screen
            let hasSeenIntroDirect = UserDefaults.standard.bool(forKey: "hasSeenIntro")
            print("[Intro] hasSeenIntro from @AppStorage: \(hasSeenIntro)")
            print("[Intro] hasSeenIntro from UserDefaults: \(hasSeenIntroDirect)")
            
            if !hasSeenIntroDirect {
                print("[Intro] Showing intro screen for first time")
                showIntroScreen = true
            } else {
                print("[Intro] User has already seen intro, skipping")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRecordingPage)) { _ in
            print("[Navigation] Received openRecordingPage notification")
            selectedSession = nil
            navigateToRecord = true
            print("[Navigation] Set navigateToRecord = true, selectedSession = nil")
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Delete Recording"),
                message: Text("Are you sure you want to delete this recording? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    if let session = sessionToDelete {
                        deleteSession(session)
                        sessionToDelete = nil
                    }
                },
                secondaryButton: .cancel {
                    sessionToDelete = nil
                }
            )
        }
    }
    
    // MARK: Header
    private var header: some View {
        HStack {
            // Avatar
            ZStack {
                Circle().fill(Color.tmYellow)
                Text("DG").fontWeight(.bold).foregroundColor(.white)
            }
            .frame(width: 44, height: 44)
            
            Spacer()
            
            // Brand name
            Text("TwinMind")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.tmBlueDark)

            Circle()
                .fill(BannerManager.shared.isOnline ? Color.green : Color.red)
                .frame(width: 10, height: 10)
                .accessibilityLabel(Text(BannerManager.shared.isOnline ? "Online" : "Offline"))
            
            Spacer()
            
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundColor(.tmBlueDark)
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .padding(.bottom, 4)
        .background(Color.white)
    }
    
    // MARK: UI Components
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Text(tab.rawValue.capitalized)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                            .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        Rectangle()
                            .frame(height: 3)
                            .foregroundColor(selectedTab == tab ? .tmBlue : .clear)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var memoriesPage: some View {
        VStack(spacing: 0) {
            // Enhanced search bar with results feedback
            VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search memories", text: $vm.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    
                    if !vm.searchText.isEmpty {
                        Button(action: { vm.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
            }
            .padding(8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
                
                // Search results feedback
                if vm.hasSearchResults {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("\(vm.searchResultCount) result\(vm.searchResultCount == 1 ? "" : "s") found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                } else if vm.hasNoSearchResults {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.orange)
                        Text("No results found for \"\(vm.searchText)\"")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Virtualized List for performance
            List {
                ForEach(sessionsByDay, id: \.date) { group in
                    Section(header: Text(formatDateHeader(group.date))
                        .font(.headline)
                        .foregroundColor(.primary)
                        .textCase(nil)) {
                        ForEach(group.sessions, id: \.id) { session in
                            SearchResultRow(session: session, searchQuery: vm.searchText) {
                                selectedSession = session
                                navigateToRecord = true
                            }
                            .onAppear { vm.loadNextPageIfNeeded(current: session) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    sessionToDelete = session
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    sessionToDelete = session
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .refreshable { vm.refresh() }
        }
    }
    
    private func placeholder(_ text: String) -> some View {
        Text(text).foregroundColor(.secondary).frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private var captureBar: some View {
        Button(action: { 
            print("Capture button tapped! Current recording state: \(recordingViewModel.isRecording)")
            
            if recordingViewModel.isRecording {
                // If recording, navigate to show current recording
                selectedSession = nil
                navigateToRecord = true
            } else {
                // If not recording, start recording and navigate
                selectedSession = nil
                recordingViewModel.startRecording()
                navigateToRecord = true
            }
        }) {
            HStack {
                Image(systemName: recordingViewModel.isRecording ? "stop.fill" : "mic")
                Text(recordingViewModel.isRecording ? "Recording..." : "Capture")
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: recordingViewModel.isRecording ? [Color.red, Color.red.opacity(0.8)] : [Color.tmBlueDark, Color.tmBlue], 
                    startPoint: .leading, 
                    endPoint: .trailing
                )
            )
            .cornerRadius(40)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, safeAreaBottomPadding + 12)
        }
    }
    
    private var safeAreaBottomPadding: CGFloat {
#if canImport(UIKit)
        // Use UIWindowScene.windows to avoid deprecated API
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.safeAreaInsets.bottom ?? 0
#else
        return 0
#endif
    }
    
    // helper colors
    private var cardBackground: Color {
#if canImport(UIKit)
        return Color(UIColor.systemBackground)
#else
        return Color.white
#endif
    }
    private var cellBackground: Color {
#if canImport(UIKit)
        return Color(UIColor.secondarySystemBackground)
#else
        return Color.secondary
#endif
    }
    
    @ViewBuilder
    private var recordingViewDestination: some View {
        if let session = selectedSession {
            RecordingViewTemp(existingSession: session, searchQuery: vm.searchText.isEmpty ? nil : vm.searchText)
        } else {
            RecordingViewTemp()
        }
    }
    
    // MARK: - Delete Logic
    private func deleteSession(_ session: RecordingSession) {
        // Remove audio files from disk
        let fileManager = FileManager.default
        // master file
        if !session.audioFilePath.isEmpty {
            try? fileManager.removeItem(atPath: session.audioFilePath)
        }
        // segment files
        for seg in session.segments {
            try? fileManager.removeItem(atPath: seg.segmentFilePath)
        }
        // Delete from SwiftData
        modelContext.delete(session)
        try? modelContext.save()

        // Remove from in-memory list so UI updates immediately
        vm.remove(session: session)
    }
    
    // Formats a date for the section header, e.g. "Wed, Jul 2".
    private func formatDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE, MMM d")
        return formatter.string(from: date)
    }
    
    // Helper to format durations like 1:05 or 0:45
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        if totalSeconds < 60 {
            return "\(totalSeconds)s"
        } else if totalSeconds < 3600 {
            let minutes = totalSeconds / 60
            return "\(minutes)m"
        } else {
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
        }
    }
}

// Temporary RecordingView for testing
struct RecordingViewTemp: View {
    enum RecordingTab: String, CaseIterable, Identifiable {
        case questions = "Questions"
        case notes = "Notes"
        case transcript = "Transcript"
        var id: String { rawValue }
    }
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var viewModel: RecordingViewModel
    @State private var selectedTab: RecordingTab = .notes
    @State private var sessionTitle: String = "Untitled"
    @State private var isEditingTitle: Bool = false
    // Export / Share state
    @State private var isExporting = false
    @State private var exportError: ExportError?
    @State private var showingExportSuccess = false
    @State private var exportedFileURL: URL?
    
    // For viewing existing sessions
    let existingSession: RecordingSession?
    let searchQuery: String?
    
    init(existingSession: RecordingSession? = nil, searchQuery: String? = nil) {
        self.existingSession = existingSession
        self.searchQuery = searchQuery
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: Custom Nav Bar
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                }
                Spacer()
                if !isRecordingMode {
                    Menu {
                        Button(action: exportAudio) {
                            Label("Export Audio", systemImage: "music.note")
                        }
                        .disabled(isExporting)

                        Button(action: exportTranscript) {
                            Label("Export Transcript", systemImage: "doc.text")
                        }
                        .disabled(isExporting || !hasTranscription)

                        Button(action: shareSession) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .disabled(isExporting)
                    } label: {
                        // Fixed-size container to avoid jitter when switching between icon and spinner
                        ZStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .opacity(isExporting ? 0 : 1)
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                                .scaleEffect(0.8)
                                .opacity(isExporting ? 1 : 0)
                        }
                        .frame(width: 24, height: 24) // Keeps width/height constant
                    }
                }
            }
            .overlay(timerView)
            .padding(.horizontal)
            .padding(.top, 0)
            .padding(.bottom, 4)
            
            // MARK: Header
            VStack(alignment: .leading, spacing: 8) {
                if isEditingTitle {
                    HStack(spacing: 8) {
                        TextField("Session title", text: $sessionTitle)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .autocapitalization(.words)
                        Button(action: {
                            // Exit editing mode and persist the new title
                            isEditingTitle = false
                            if let session = existingSession {
                                // Update existing session and save context
                                session.title = sessionTitle
                                try? modelContext.save()
                                NotificationCenter.default.post(name: .tmSessionCreated, object: nil) // refresh lists
                            } else {
                                // Update in-progress recording session; it will be saved on stopRecording()
                                viewModel.currentSession?.title = sessionTitle
                            }
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                    }
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary, lineWidth: 1)
                    )
                } else {
                    Text(sessionTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .onTapGesture { isEditingTitle = true }
                }
                Text(dateLocationString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // MARK: Tabs
            tabBar
            Divider()
            
            // MARK: Tab Content (scrollable within section)
            TabView(selection: $selectedTab) {
                questionsSection.tag(RecordingTab.questions)
                notesSection.tag(RecordingTab.notes)
                transcriptSection.tag(RecordingTab.transcript)
            }
#if os(iOS)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
#endif
            Spacer(minLength: 0)
            
            if isRecordingMode {
                // MARK: Recording UI - Waveform & Status
                waveformSection
                    .padding(.top, 12)
                statusSection
                
                // MARK: Bottom Controls
                recordingBottomControls
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.white)
            } else {
                // MARK: Viewing mode - just chat button
                viewingBottomControls
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.white)
            }
        }
#if os(iOS)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
#endif
        .onAppear {
            viewModel.modelContext = modelContext
            setupView()
        }
        .onDisappear {
            if viewModel.isRecording {
                viewModel.stopRecording()
            }
        }
        // Export alerts
        .alert("Export Successful", isPresented: $showingExportSuccess) {
            Button("OK") { }
            if let url = exportedFileURL {
                Button("Open") { openFile(url) }
            }
        } message: {
            Text("File has been exported successfully.")
        }
        .alert("Export Error", isPresented: .constant(exportError != nil)) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError?.errorDescription ?? "Unknown error occurred.")
        }
    }
    
    // MARK: - Computed Properties
    private var isRecordingMode: Bool {
        // We're in recording mode if we're actively recording and not viewing an existing session
        return existingSession == nil && viewModel.isRecording
    }
    
    private var currentSessionNotes: String? {
        return existingSession?.notes ?? viewModel.currentSession?.notes
    }
    
    private var isGeneratingSummary: Bool {
        // Check if transcriptions are complete but notes haven't been generated yet
        guard let session = existingSession ?? viewModel.currentSession else { return false }
        
        // If we already have notes, not generating
        if let notes = session.notes, !notes.isEmpty { return false }
        
        // If summary generation has failed, not generating
        if session.summaryGenerationFailed { return false }
        
        // If recording is in progress, not generating yet
        if isRecordingMode { return false }
        
        // Check if all transcriptions are complete
        let allSegments = session.segments
        let completedSegments = allSegments.filter { $0.status == .completed && $0.transcription?.text.isEmpty == false }
        let failedSegments = allSegments.filter { $0.status == .failed && $0.retryCount >= 5 }
        let processedSegments = completedSegments.count + failedSegments.count
        
        // If all segments are processed and we have some transcriptions but no notes, we're generating
        return processedSegments == allSegments.count && processedSegments > 0 && completedSegments.count > 0
    }
    
    private var hasSummaryGenerationFailed: Bool {
        return (existingSession ?? viewModel.currentSession)?.summaryGenerationFailed ?? false
    }
    
    private var dateLocationString: String {
        if let session = existingSession {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            let dateStr = formatter.string(from: session.createdAt)
            formatter.dateFormat = "h:mm a"
            let timeStr = formatter.string(from: session.createdAt)
            return "\(dateStr) • \(timeStr) • Menlo Park"
        } else {
            return "\(currentDateString) • \(currentTimeString) • Menlo Park"
        }
    }
    
    private func setupView() {
        print("[RecordingViewTemp] setupView called, existingSession: \(existingSession?.title ?? "nil"), viewModel.isRecording: \(viewModel.isRecording)")
        
        if let session = existingSession {
            // Viewing existing session
            sessionTitle = session.title
            selectedTab = .transcript
        } else {
            // New recording view
            if viewModel.isRecording {
                print("[RecordingViewTemp] Recording already in progress, using current session")
                // If recording is already in progress, use the current session
                if let currentSession = viewModel.currentSession {
                    sessionTitle = currentSession.title
                } else {
                    sessionTitle = "Untitled"
                }
            } else {
                print("[RecordingViewTemp] No recording in progress, will show empty state")
                sessionTitle = "Untitled"
            }
            selectedTab = .transcript
        }
    }
    
    // MARK: Components
    private var timerView: some View {
        HStack(spacing: 6) {
            if isRecordingMode {
                Circle().fill(Color.red).frame(width: 12, height: 12)
                Text(formatTimerDuration(viewModel.currentDuration))
                    .font(.system(.body, design: .monospaced))
            } else {
                Circle().fill(Color.secondary).frame(width: 12, height: 12)
                Text(formatTimerDuration(existingSession?.duration ?? viewModel.currentSession?.duration ?? 0))
                    .font(.system(.body, design: .monospaced))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isRecordingMode ? Color.red.opacity(0.1) : Color.secondary.opacity(0.1))
        .cornerRadius(20)
    }
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(RecordingTab.allCases) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                            .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        Rectangle()
                            .frame(height: 3)
                            .foregroundColor(selectedTab == tab ? .blue : .clear)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var transcriptSection: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Add audio playbar for completed sessions or newly finished recordings
                if let session = existingSession ?? (!viewModel.isRecording ? viewModel.currentSession : nil),
                   viewModel.isAudioFileReady(for: session) {
                    AudioPlaybar(audioFilePath: session.audioFilePath, duration: session.duration, recordingViewModel: viewModel)
                        .padding(.vertical, 16)
                }
                
                if shouldShowNoTranscriptMessage {
                    // Show "No transcript available" for completed sessions with no transcriptions
                    VStack(spacing: 16) {
                        Image(systemName: "waveform")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                        
                        VStack(spacing: 8) {
                            Text("No transcript available")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("TwinMind may not have captured any speech, try again or check your microphone settings.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else {
                    ForEach(transcriptLines, id: \.self) { line in
                        if let searchQuery = searchQuery, !searchQuery.isEmpty {
                            HighlightedText(text: line, searchQuery: searchQuery)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 2)
                        } else {
                        Text(line)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                        }
                    }
                    if transcriptLines.isEmpty && isRecordingMode {
                        Text("Transcribing…")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    private var questionsSection: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Question suggestion cards
                QuestionCard(
                    icon: "✏️",
                    text: "Draft a follow-up email with next steps"
                )
                
                QuestionCard(
                    icon: "💫", 
                    text: "Find memorable moments and funny quotes"
                )
                
                QuestionCard(
                    icon: "💡",
                    text: "What are the key insights?"
                )
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
    }
    
    private var notesSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // AI-Generated Notes Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("AI Summary")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Button(action: {
                            retrySummaryGeneration()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                        }
                        .disabled(isGeneratingSummary || isRecordingMode)
                    }
                    
                    Group {
                        if isGeneratingSummary {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Generating summary...")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                        } else if hasSummaryGenerationFailed {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                    Text("Failed to generate summary")
                                        .foregroundColor(.orange)
                                        .font(.subheadline)
                                }
                                
                                Button(action: {
                                    retrySummaryGeneration()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Try Again")
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                                }
                            }
                        } else if let notes = currentSessionNotes, !notes.isEmpty {
                            Text(notes)
                                .foregroundColor(.primary)
                                .font(.subheadline)
                        } else if isRecordingMode {
                            Text("Summary will be generated when recording is complete")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                                .italic()
                        } else {
                            Text("No summary available")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                                .italic()
                        }
                    }
                }
                
                Divider()
                
                // Manual Notes Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Notes")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Add your own notes or provide feedback to improve AI summaries")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .italic()
                    
                    Button(action: {
                        // TODO: Add manual notes editing
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Add Notes")
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
        .onReceive(NotificationCenter.default.publisher(for: .tmSessionUpdated)) { notification in
            // Refresh notes when session is updated
            if let updatedSession = notification.object as? RecordingSession,
               updatedSession.id == (existingSession?.id ?? viewModel.currentSession?.id) {
                print("[Notes] Session updated, refreshing notes display")
            }
        }
    }
    
    private var waveformSection: some View {
        HStack {
            Spacer()
            Group {
                if isRecordingMode {
                    LiveAudioIndicator(level: $viewModel.audioLevel)
                } else {
                    Image(systemName: "waveform")
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .frame(height: 40)
    }
    
    // Live audio indicator view
    private struct LiveAudioIndicator: View {
        @Binding var level: Float // 0.0 - 1.0
        private let barCount = 12
        
        var body: some View {
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.secondary.opacity(0.7))
                        .frame(width: 3, height: barHeight)
                }
            }
            .animation(.linear(duration: 0.05), value: level)
        }
        
        private var barHeight: CGFloat {
            // scale level to 8...32 with some randomness for visual richness
            let base = CGFloat(level) * 24 + 8
            return base * CGFloat.random(in: 0.7...1.3)
        }
    }
    
    private var statusSection: some View {
        VStack(spacing: 8) {
            Text("TwinMind is transcribing…")
                .font(.headline)
                .fontWeight(.semibold)
            Text("You can run in the background until you tap Stop.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                // mock action
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Tap to Get Answer")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(25)
            }
        }
    }
    
    private var recordingBottomControls: some View {
        HStack(spacing: 12) {
            // Pause / Resume
            Button(action: {
                if viewModel.isPaused { viewModel.resumeRecording() } else { viewModel.pauseRecording() }
            }) {
                HStack {
                    Image(systemName: viewModel.isPaused ? "play.circle" : "pause.circle")
                    Text(viewModel.isPaused ? "Resume" : "Pause")
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(25)
            }
            // Existing chat button (optional) - keeping minimal
            Button(action: {}) {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("Chat")
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(25)
            }
            // Stop button
            Button(action: { viewModel.stopRecording() }) {
                HStack {
                    Image(systemName: "stop.circle")
                    Text("Stop")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.red)
                .cornerRadius(25)
            }
        }
    }
    
    private var viewingBottomControls: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                Text("Chat with Transcript")
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(25)
            .frame(maxWidth: .infinity)
        }
    }
    

    
    // Computed transcript lines from available transcriptions
    private var transcriptLines: [String] {
        let session = existingSession ?? viewModel.currentSession
        guard let segs = session?.segments else { return [] }
        return segs.map { seg in
            switch seg.status {
            case .completed:
                return seg.transcription?.text ?? ""
            case .inProgress:
                return "Transcribing audio…"
            case .failed:
                return "❌ Error transcribing audio"
            case .notStarted:
                return "Recording…"
            }
        }
    }
    
    // MARK: Helpers
    private func formatTimerDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: Date Helpers
    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: Date())
    }
    
    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: Date())
    }
    
    // MARK: Summary Generation
    private func retrySummaryGeneration() {
        guard let session = existingSession ?? viewModel.currentSession else { return }
        
        print("[Notes] Retrying summary generation for session: \(session.title)")
        
        // Clear the failed state to trigger regeneration
        session.summaryGenerationFailed = false
        try? modelContext.save()
        
        // Trigger summary generation with force retry
        Task {
            await SessionSummaryService.shared.generateSummary(for: session, modelContext: modelContext, forceRetry: true)
        }
    }
    
    // Check if we should show "No transcript available" message
    private var shouldShowNoTranscriptMessage: Bool {
        guard let session = existingSession else { return false }
        // Only show for completed sessions (not currently recording)
        guard !viewModel.isRecording else { return false }
        // Check if all segments have no transcription
        let hasAnyTranscription = session.segments.contains { $0.transcription?.text.isEmpty == false }
        return !hasAnyTranscription
    }
    
    // MARK: - Export & Share
    private func exportAudio() {
        guard let session = existingSession else { return }
        isExporting = true
        ExportManager.exportAudio(for: session) { result in
            isExporting = false
            switch result {
            case .success(let url):
                exportedFileURL = url
                showingExportSuccess = true
            case .failure(let error):
                exportError = error
            }
        }
    }

    private func exportTranscript() {
        guard let session = existingSession else { return }
        isExporting = true
        ExportManager.exportTranscript(for: session) { result in
            isExporting = false
            switch result {
            case .success(let url):
                exportedFileURL = url
                showingExportSuccess = true
            case .failure(let error):
                exportError = error
            }
        }
    }

    private func shareSession() {
        guard let session = existingSession else { return }
        isExporting = true
        ExportManager.exportTranscript(for: session) { result in
            isExporting = false
            switch result {
            case .success(let url):
                presentActivity(with: [url])
            case .failure(let error):
                exportError = error
            }
        }
    }

    private func openFile(_ url: URL) {
        presentActivity(with: [url])
    }

    // Presents a system share sheet (QuickLook-friendly)
    private func presentActivity(with items: [Any]) {
#if canImport(UIKit)
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            var presenter = rootVC
            while let presented = presenter.presentedViewController { presenter = presented }
            presenter.present(activityVC, animated: true)
        }
#endif
    }

    // Are there any completed transcriptions?
    private var hasTranscription: Bool {
        existingSession?.segments.contains { $0.transcription != nil } ?? false
    }
}

// Question card component
private struct QuestionCard: View {
    let icon: String
    let text: String
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.title2)
                
                Text(text)
                    .foregroundColor(.primary)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.blue)
                    .font(.body)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Search Result Row Component
struct SearchResultRow: View {
    let session: RecordingSession
    let searchQuery: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Main session info
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Highlighted title if it matches search
                        if !searchQuery.isEmpty && SearchHelper.textContainsQuery(session.title, query: searchQuery) {
                            HighlightedText(text: session.title, searchQuery: searchQuery)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        } else {
                            Text(session.title)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Spacer()
                    
                    Text(formatDuration(session.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Show search snippets if there are matching transcriptions
                if !searchQuery.isEmpty {
                    let matchingSegments = session.segments.filter { segment in
                        guard let transcription = segment.transcription else { return false }
                        return SearchHelper.textContainsQuery(transcription.text, query: searchQuery)
                    }
                    
                    if !matchingSegments.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(matchingSegments.prefix(2), id: \.id) { segment in
                                if let transcription = segment.transcription {
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(formatTime(segment.startTime))
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                            .frame(width: 35, alignment: .leading)
                                        
                                        HighlightedText(
                                            text: SearchHelper.extractSearchSnippet(from: transcription.text, searchQuery: searchQuery),
                                            searchQuery: searchQuery
                                        )
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                    }
                                }
                            }
                            
                            if matchingSegments.count > 2 {
                                Text("... and \(matchingSegments.count - 2) more matches")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .padding(.leading, 43)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        if totalSeconds < 60 {
            return "\(totalSeconds)s"
        } else if totalSeconds < 3600 {
            let minutes = totalSeconds / 60
            return "\(minutes)m"
        } else {
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Highlighted Text Component
struct HighlightedText: View {
    let text: String
    let searchQuery: String
    
    var body: some View {
        if searchQuery.isEmpty {
            Text(text)
        } else {
            let attributedString = createAttributedString(from: text, highlighting: searchQuery)
            Text(attributedString)
        }
    }
    
    private func createAttributedString(from text: String, highlighting searchQuery: String) -> AttributedString {
        var attributedString = AttributedString(text)
        let searchRanges = SearchHelper.findSearchRanges(in: text, searchQuery: searchQuery)
        
        for range in searchRanges {
            if let attributedRange = Range<AttributedString.Index>(range, in: attributedString) {
                attributedString[attributedRange].font = .boldSystemFont(ofSize: UIFont.systemFontSize)
                attributedString[attributedRange].backgroundColor = .yellow.withAlphaComponent(0.3)
            }
        }
        
        return attributedString
    }
}

// MARK: - Intro Screen
struct IntroScreen: View {
    @Binding var isPresented: Bool
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Hearts animation area
            ZStack {
                // Background hearts
                ForEach(0..<8, id: \.self) { index in
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20 + CGFloat(index * 3)))
                        .foregroundColor(.pink.opacity(0.3))
                        .offset(
                            x: CGFloat.random(in: -100...100),
                            y: CGFloat.random(in: -50...50)
                        )
                        .animation(
                            Animation.easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.3),
                            value: index
                        )
                }
                
                // Main heart
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.pink)
                    .scaleEffect(1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: UUID()
                    )
            }
            .frame(height: 200)
            
            // Thank you message
            VStack(spacing: 16) {
                Text("Thank you for taking the time to review this TwinMind audio-recording demo. Your consideration means a lot! I appreciate the opportunity.")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(4)
                
                // Smile emoji
                Text("😊")
                    .font(.system(size: 48))
                    .scaleEffect(1.0)
                    .animation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                        value: UUID()
                    )
            }
            
            Spacer()
            
            // Get Started button
            Button(action: {
                print("[Intro] Get Started tapped, setting hasSeenIntro = true")
                hasSeenIntro = true
                print("[Intro] hasSeenIntro after setting: \(hasSeenIntro)")
                isPresented = false
            }) {
                HStack(spacing: 8) {
                    Text("Get Started")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.tmBlue, Color.tmBlueDark]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            .padding(.bottom, 50)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white,
                    Color.pink.opacity(0.05),
                    Color.white
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            print("[Intro] IntroScreen appeared, hasSeenIntro: \(hasSeenIntro)")
        }
    }
}

#Preview {
    NavigationView { HomeView() }
} 