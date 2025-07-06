import SwiftUI

/// Horizontally scrolling bar-style waveform that visualises recent audio amplitudes.
/// Pass in an array of values normalised 0‒1 (newest last).  The view automatically
/// fits the bars to the available width.
struct WaveformView: View {
    var samples: [Float]
    var barColor: Color = .green
    
    private var maxSample: Float { samples.max() ?? 1 }
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let barSpacing: CGFloat = 2
            let barCount = samples.count
            let barWidth = max(1, (width - CGFloat(barCount - 1) * barSpacing) / CGFloat(max(barCount, 1)))
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(samples.indices, id: \.self) { idx in
                    let norm = CGFloat(samples[idx]) // already 0‒1
                    Capsule()
                        .fill(barColor)
                        .frame(width: barWidth, height: max(1, norm * height))
                        .animation(.linear(duration: 0.05), value: samples[idx])
                }
            }
            // Flip vertically so higher amplitude renders upwards
            .scaleEffect(y: -1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    WaveformView(samples: (0..<100).map { _ in Float.random(in: 0...1) })
        .frame(height: 60)
        .padding()
} 