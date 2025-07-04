//
//  SessionDetailView.swift
//  TwinMind
//
//  Created by Devin Morgan on 7/1/25.
//

import SwiftUI

struct SessionDetailView: View {
    let session: RecordingSession
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedSegment: AudioSegment?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Session Header
                SessionHeaderView(session: session)
                
                // Quick Stats
                SessionStatsView(session: session)
                
                // Segments List
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Segments")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text("\(session.segments.count) total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if session.segments.isEmpty {
                        EmptySegmentsView()
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(session.segments, id: \.id) { segment in
                                SegmentRowView(
                                    segment: segment,
                                    isSelected: selectedSegment?.id == segment.id,
                                    onTap: {
                                        selectedSegment = selectedSegment?.id == segment.id ? nil : segment
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {}) {
                        Label("Export Audio", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: {}) {
                        Label("Export Transcript", systemImage: "doc.text")
                    }
                    
                    Button(action: {}) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    Button(action: {}) {
                        Label("Edit Title", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: {}) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct SessionHeaderView: View {
    let session: RecordingSession
    
    private var statusText: String {
        if session.segments.isEmpty {
            return "Recording"
        }
        let completed = session.segments.filter { $0.status == .completed }.count
        if completed == session.segments.count {
            return "Completed"
        }
        if session.segments.contains(where: { $0.status == .failed }) {
            return "Failed"
        }
        return "In Progress"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 16) {
                        Label(
                            session.createdAt.formatted(date: .complete, time: .shortened),
                            systemImage: "calendar"
                        )
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        
                        Label(
                            formatDuration(session.duration),
                            systemImage: "clock"
                        )
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                StatusBadge(statusText: statusText)
            }
        }
        .padding(.horizontal)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%dm %ds", minutes, seconds)
    }
}

struct SessionStatsView: View {
    let session: RecordingSession
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                StatCard(
                    title: "Segments",
                    value: "\(session.segments.count)",
                    icon: "waveform",
                    color: .blue
                )
                
                StatCard(
                    title: "Transcribed",
                    value: "\(completedSegments)/\(session.segments.count)",
                    icon: "text.quote",
                    color: .green
                )
                
                StatCard(
                    title: "Progress",
                    value: "\(Int(transcriptionProgress * 100))%",
                    icon: "chart.pie",
                    color: .orange
                )
            }
        }
        .padding(.horizontal)
    }
    
    private var completedSegments: Int {
        session.segments.filter { $0.status == .completed }.count
    }
    
    private var transcriptionProgress: Double {
        guard !session.segments.isEmpty else { return 0 }
        return Double(completedSegments) / Double(session.segments.count)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

struct SegmentRowView: View {
    let segment: AudioSegment
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Main segment row
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Time indicator
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatTime(segment.startTime))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("→ \(formatTime(segment.endTime))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 60, alignment: .leading)
                    
                    // Waveform placeholder
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.3))
                        .frame(height: 40)
                        .overlay(
                            HStack(spacing: 2) {
                                ForEach(0..<12, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(Color.blue)
                                        .frame(width: 2, height: CGFloat.random(in: 8...32))
                                }
                            }
                        )
                    
                    // Status and info
                    VStack(alignment: .trailing, spacing: 4) {
                        TranscriptionStatusBadge(status: segment.status)
                        
                        if segment.status == .inProgress {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                        
                        if segment.retryCount > 0 {
                            Text("Retry \(segment.retryCount)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isSelected ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.05))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded transcription view
            if isSelected {
                TranscriptionDetailView(segment: segment)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeInOut(duration: 0.3), value: isSelected)
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct TranscriptionStatusBadge: View {
    let status: TranscriptionStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.caption2)
            
            Text(status.rawValue.capitalized)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .cornerRadius(8)
    }
    
    private var iconName: String {
        switch status {
        case .notStarted:
            return "clock"
        case .inProgress:
            return "gear"
        case .completed:
            return "checkmark"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
    
    private var backgroundColor: Color {
        switch status {
        case .notStarted:
            return .gray.opacity(0.2)
        case .inProgress:
            return .blue.opacity(0.2)
        case .completed:
            return .green.opacity(0.2)
        case .failed:
            return .red.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch status {
        case .notStarted:
            return .gray
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

struct TranscriptionDetailView: View {
    let segment: AudioSegment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let transcriptionText = segment.transcription?.text {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcription")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(transcriptionText)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcription")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.orange)
                        
                        Text(transcriptionMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
            }
            
            // Segment actions
            HStack(spacing: 16) {
                Button(action: {}) {
                    Label("Play", systemImage: "play.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                
                if segment.status == .failed {
                    Button(action: {}) {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
        .padding(.top, 8)
    }
    
    private var transcriptionMessage: String {
        switch segment.status {
        case .notStarted:
            return "Transcription pending..."
        case .inProgress:
            return "Transcribing audio..."
        case .failed:
            return "Transcription failed"
        case .completed:
            return "Transcription completed"
        }
    }
}

struct EmptySegmentsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                Text("No Segments")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("This recording doesn't have any segments yet")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
    }
}

struct StatusBadge: View {
    let statusText: String
    
    var body: some View {
        Text(statusText)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(8)
    }
    
    private var backgroundColor: Color {
        return .blue.opacity(0.2)
    }
    
    private var foregroundColor: Color {
        return .blue
    }
}

#if DEBUG
#Preview {
    NavigationView {
        SessionDetailView(session: {
            let session = RecordingSession(
                title: "Sample Recording",
                createdAt: Date(),
                duration: 120,
                audioFilePath: "",
                sampleRate: 44100,
                bitDepth: 16,
                format: "caf"
            )
            
            // Add sample segments
            for i in 0..<3 {
                let seg = AudioSegment(
                    startTime: TimeInterval(i * 30),
                    endTime: TimeInterval((i + 1) * 30),
                    segmentFilePath: ""
                )
                seg.status = i == 0 ? .completed : .notStarted
                if i == 0 {
                    let t = Transcription(text: "Sample transcription text", confidence: 0.9, source: .whisperAPI)
                    seg.transcription = t
                }
                seg.session = session
                session.segments.append(seg)
            }
            
            return session
        }())
    }
}
#endif 