//
//  RecordingView.swift
//  TwinMind
//
//  Created by Devin Morgan on 7/1/25.
//

#if canImport(UIKit)
import UIKit
#endif

import SwiftUI

struct RecordingView: View {
    enum RecordingTab: String, CaseIterable, Identifiable {
        case questions = "Questions"
        case notes = "Notes"
        case transcript = "Transcript"
        var id: String { rawValue }
    }
    
    @StateObject private var viewModel = RecordingViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTab: RecordingTab = .questions
    @State private var showAddNotes = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Bar
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                // Recording Timer
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                    Text(formatDuration(viewModel.currentDuration))
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .cornerRadius(20)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Untitled")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Text("July 2, 2025 • 2:56 PM • Hampton, VA")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Notes Section
                    VStack(spacing: 12) {
                        HStack {
                            Text("You can write your own notes!")
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Add Notes") {
                                showAddNotes.toggle()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(radius: 2)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Tab Bar
                    VStack(spacing: 0) {
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
                        
                        Divider()
                    }
                    
                    // Content Area
                    VStack(spacing: 20) {
                        if selectedTab == .questions {
                            VStack(spacing: 12) {
                                Image(systemName: "arrow.down")
                                    .foregroundColor(.secondary)
                                Text("Pull down to get suggested searches")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else if selectedTab == .notes {
                            Text("Notes content coming soon")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            Text("Transcript content coming soon")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        }
                        
                        Spacer()
                        
                        // Real-time waveform visualisation
                        if AppSettings.shared.showLevels {
                            WaveformView(samples: viewModel.waveformSamples)
                                .frame(height: 60)
                                .padding(.top, 20)
                        }
                        
                        // Transcription Status
                        VStack(spacing: 12) {
                            Text("TwinMind is transcribing...")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("You can write your own notes in the notes tab or run in the background until you tap Stop.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button(action: {}) {
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
                            .padding(.top, 8)
                        }
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal)
                }
            }
            
            // Bottom Control Bar
            HStack(spacing: 12) {
                // Pause / Resume toggle
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
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.white)
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.startRecording()
        }
        .alert(item: $viewModel.recordingError) { err in
            Alert(title: Text("Recording Error"), message: Text(err.localizedDescription), dismissButton: .default(Text("OK")))
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    RecordingView()
} 