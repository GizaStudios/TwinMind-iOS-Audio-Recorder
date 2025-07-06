import SwiftUI

/// Simple vertical bar level meter driven by a normalised `level` (0.0‒1.0).
struct LevelMeterView: View {
    var level: Float                       // 0…1 value supplied by RecordingViewModel
    private let barCount = 20
    @State private var randomFactors: [CGFloat] = (0..<20).map { _ in CGFloat.random(in: 0.3...1) }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { idx in
                let height = CGFloat(level) * 40 * randomFactors[idx]
                Capsule()
                    .fill(Color.green)
                    .frame(width: 3, height: max(4, height))
            }
        }
        .onChange(of: level) { _ in
            // Slightly shuffle factors each update so the meter looks dynamic.
            randomFactors = randomFactors.map { _ in CGFloat.random(in: 0.3...1) }
        }
        .animation(.linear(duration: 0.08), value: level)
    }
}

#Preview {
    VStack {
        LevelMeterView(level: 0.1)
        LevelMeterView(level: 0.5)
        LevelMeterView(level: 1.0)
    }
    .padding()
} 