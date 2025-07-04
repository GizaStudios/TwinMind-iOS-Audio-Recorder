//
//  Banner.swift
//  TwinMind
//
//  Created by Devin Morgan on 7/2/25.
//

import SwiftUI

struct Banner: View {
    enum BannerType { case info, warning, error }
    
    let message: String
    let type: BannerType
    
    @Binding var isPresented: Bool
    
    var body: some View {
        if isPresented {
            VStack {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: iconName)
                        .foregroundColor(iconColor)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: { withAnimation { isPresented = false } }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(backgroundColor)
                .cornerRadius(12)
                .shadow(radius: 4)
                Spacer()
            }
            .padding()
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(), value: isPresented)
        }
    }
    
    private var iconName: String {
        switch type {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "exclamationmark.octagon"
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
    
    private var backgroundColor: Color {
        switch type {
        case .info: return Color.blue.opacity(0.1)
        case .warning: return Color.orange.opacity(0.1)
        case .error: return Color.red.opacity(0.1)
        }
    }
} 