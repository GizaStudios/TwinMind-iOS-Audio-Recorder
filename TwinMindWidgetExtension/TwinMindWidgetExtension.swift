//
//  TwinMindWidgetExtension.swift
//  TwinMindWidgetExtension
//
//  Created by Devin Morgan on 7/6/25.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> RecordingEntry {
        RecordingEntry(date: Date(), isRecording: false, sessionCount: 0, recentSessions: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (RecordingEntry) -> ()) {
        let entry = RecordingEntry(date: Date(), isRecording: false, sessionCount: 0, recentSessions: [])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Get current recording status and session count from shared UserDefaults
        let userDefaults = UserDefaults(suiteName: "group.com.gizastudios.twinmind.widget")
        let isRecording = userDefaults?.bool(forKey: "isRecording") ?? false
        let sessionCount = userDefaults?.integer(forKey: "sessionCount") ?? 0
        
        // Get recent sessions data
        let recentSessionsData = userDefaults?.data(forKey: "recentSessions") ?? Data()
        print("[Widget] Timeline: Received \(recentSessionsData.count) bytes of session data")
        let recentSessions = decodeRecentSessions(from: recentSessionsData)
        print("[Widget] Timeline: Decoded \(recentSessions.count) sessions")
        
        let entry = RecordingEntry(date: Date(), isRecording: isRecording, sessionCount: sessionCount, recentSessions: recentSessions)
        
        // Update every 30 seconds to show real-time status
        let nextUpdate = Calendar.current.date(byAdding: .second, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func decodeRecentSessions(from data: Data) -> [RecentSessionInfo] {
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([RecentSessionInfo].self, from: data)
        } catch {
            return []
        }
    }
}

struct RecentSessionInfo: Codable {
    let title: String
    let createdAt: Date
    let duration: TimeInterval
    let transcriptSnippet: String
    let sessionCount: Int
}

struct RecordingEntry: TimelineEntry {
    let date: Date
    let isRecording: Bool
    let sessionCount: Int
    let recentSessions: [RecentSessionInfo]
}

struct TwinMindWidgetExtensionEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: entry.isRecording ? "record.circle.fill" : "mic.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(entry.isRecording ? .red : .blue)
                .scaleEffect(entry.isRecording ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: entry.isRecording)
            
            Text(entry.isRecording ? "Recording..." : "Quick Record")
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
            
            Text("\(entry.sessionCount) sessions")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .widgetURL(URL(string: "twinmind://record"))
    }
}

struct MediumWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: entry.isRecording ? "record.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                        .foregroundColor(entry.isRecording ? .red : .blue)
                        .scaleEffect(entry.isRecording ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: entry.isRecording)
                    
                    Text("TwinMind")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Text(entry.isRecording ? "Recording in progress..." : "Tap to start recording")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(entry.sessionCount) recording sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack {
                Image(systemName: entry.isRecording ? "stop.circle.fill" : "record.circle")
                    .font(.system(size: 40))
                    .foregroundColor(entry.isRecording ? .red : .blue)
                
                Text(entry.isRecording ? "Stop Recording" : "Start Recording")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(entry.isRecording ? .red : .primary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .widgetURL(URL(string: "twinmind://record"))
    }
}

struct LargeWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("TwinMind Recorder")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                if entry.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                            .scaleEffect(1.0)
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: entry.isRecording)
                        
                        Text("LIVE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Recording Controls
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(entry.sessionCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: entry.isRecording ? "stop.fill" : "record.fill")
                        .font(.caption)
                    Text(entry.isRecording ? "Stop" : "Record")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(entry.isRecording ? Color.red : Color.blue)
                .cornerRadius(16)
            }
            
            // Recent Sessions Section
            if !entry.recentSessions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Sessions")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    ForEach(Array(entry.recentSessions.prefix(3).enumerated()), id: \.offset) { index, session in
                        RecentSessionRow(session: session)
                    }
                }
            } else {
                // Placeholder when no recent sessions
                VStack(spacing: 8) {
                    Image(systemName: "mic.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No recent sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .widgetURL(URL(string: "twinmind://record"))
    }
}

struct RecentSessionRow: View {
    let session: RecentSessionInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer()
                
                Text(formatDuration(session.duration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !session.transcriptSnippet.isEmpty {
                Text(session.transcriptSnippet)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            Text(formatDate(session.createdAt))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TwinMindWidgetExtension: Widget {
    let kind: String = "TwinMindWidgetExtension"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                TwinMindWidgetExtensionEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                TwinMindWidgetExtensionEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("TwinMind Recorder")
        .description("Quick access to start recording sessions")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    TwinMindWidgetExtension()
} timeline: {
    RecordingEntry(date: .now, isRecording: false, sessionCount: 5, recentSessions: [])
    RecordingEntry(date: .now, isRecording: true, sessionCount: 5, recentSessions: [])
}

#Preview(as: .systemMedium) {
    TwinMindWidgetExtension()
} timeline: {
    RecordingEntry(date: .now, isRecording: false, sessionCount: 12, recentSessions: [])
    RecordingEntry(date: .now, isRecording: true, sessionCount: 12, recentSessions: [])
}

#Preview(as: .systemLarge) {
    TwinMindWidgetExtension()
} timeline: {
    let sampleSessions = [
        RecentSessionInfo(
            title: "Team Meeting Notes",
            createdAt: Date().addingTimeInterval(-3600),
            duration: 1800,
            transcriptSnippet: "Today we discussed the Q4 roadmap and upcoming product launches...",
            sessionCount: 25
        ),
        RecentSessionInfo(
            title: "Interview with John",
            createdAt: Date().addingTimeInterval(-7200),
            duration: 2400,
            transcriptSnippet: "John shared his experience working on the mobile app development...",
            sessionCount: 25
        ),
        RecentSessionInfo(
            title: "Ideas for New Feature",
            createdAt: Date().addingTimeInterval(-10800),
            duration: 900,
            transcriptSnippet: "Voice-to-text integration could really improve user experience...",
            sessionCount: 25
        )
    ]
    
    RecordingEntry(date: .now, isRecording: false, sessionCount: 25, recentSessions: sampleSessions)
    RecordingEntry(date: .now, isRecording: true, sessionCount: 25, recentSessions: sampleSessions)
}
