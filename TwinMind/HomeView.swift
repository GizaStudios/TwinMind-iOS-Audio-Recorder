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
    
    @State private var totalDuration: TimeInterval
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var timer: Timer?
    
    init(audioFilePath: String, duration: TimeInterval) {
        self.audioFilePath = audioFilePath
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
    @StateObject private var vm = HomeViewModel()
    @State private var navigateToRecord = false
    @State private var selectedSession: RecordingSession?
    @State private var showSettings = false
    @State private var showDeleteAlert = false
    @State private var sessionToDelete: RecordingSession?
    
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
        // only in-section search bar
        .onAppear {
            vm.setContext(modelContext)
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
            // Search bar above the list
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search memories", text: $vm.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
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
                            Button(action: { selectedSession = session; navigateToRecord = true }) {
                                HStack {
                                    // left time column
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(session.createdAt.formatted(date: .omitted, time: .shortened))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(session.title)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                    }
                                    Spacer()
                                    Text(formatDuration(session.duration))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
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
            print("Capture button tapped!")
            selectedSession = nil  // Clear any existing session to start new recording
            navigateToRecord = true 
        }) {
            HStack {
                Image(systemName: "mic")
                Text("Capture")
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [Color.tmBlueDark, Color.tmBlue], startPoint: .leading, endPoint: .trailing)
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
            RecordingViewTemp(existingSession: session)
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
    @StateObject private var viewModel = RecordingViewModel()
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
    
    init(existingSession: RecordingSession? = nil) {
        self.existingSession = existingSession
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
        existingSession == nil && viewModel.isRecording
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
        if let session = existingSession {
            // Viewing existing session
            sessionTitle = session.title
            selectedTab = .transcript
        } else {
            // New recording
            viewModel.startRecording()
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
                Text(formatTimerDuration(existingSession?.duration ?? 0))
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
                   !session.audioFilePath.isEmpty {
                    AudioPlaybar(audioFilePath: session.audioFilePath, duration: session.duration)
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
                        Text(line)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
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
                // Summary Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Summary")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Button(action: {}) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text(mockSummary)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                
                Divider()
                
                // Action Items Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Action Items")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "square")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(mockActionItem)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        Spacer()
                    }
                }
                
                Divider()
                
                // Your Notes Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Notes")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Click 'Edit Notes' to add your own notes or provide instructions to regenerate summary (e.g. correct spellings to fix transcription errors)")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .italic()
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
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
    
    // MARK: - Mock Data
    private var mockSummary: String {
        if let session = existingSession {
            return session.duration < 60 ? "Transcript too short to generate a summary" : "Brief discussion about project timeline and next steps."
        }
        return "Recording in progress..."
    }
    
    private var mockActionItem: String {
        if let session = existingSession {
            return session.title.contains("Greeting") ? "No action items identified from brief greeting" : "Follow up on discussed action items"
        }
        return "Recording in progress..."
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

#Preview {
    NavigationView { HomeView() }
} 