import SwiftUI

// MARK: - Animated Energy Waveform

struct WaveformView: View {
    let energy: Double // 0.0 – 1.0
    var barCount: Int = 24
    var color: Color = .spotifyGreen

    @State private var phases: [Double] = []
    @State private var timer: Timer?

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: geo.size.width / CGFloat(barCount * 2)) {
                ForEach(0..<barCount, id: \.self) { index in
                    WaveBar(
                        phase: phases.indices.contains(index) ? phases[index] : 0,
                        energy: energy,
                        index: index,
                        barCount: barCount,
                        color: color
                    )
                }
            }
        }
        .onAppear {
            phases = (0..<barCount).map { Double($0) * (.pi * 2.0 / Double(barCount)) }
            startAnimation()
        }
        .onDisappear { stopAnimation() }
    }

    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                for i in 0..<phases.count {
                    phases[i] += 0.15 + energy * 0.3
                }
            }
        }
    }

    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
}

private struct WaveBar: View {
    let phase: Double
    let energy: Double
    let index: Int
    let barCount: Int
    let color: Color

    private var height: CGFloat {
        let base = 4.0
        let amplitude = 20.0 * energy + 4.0
        let positional = Double(index) / Double(barCount) * .pi
        let wave = sin(phase + positional)
        return CGFloat(base + amplitude * (0.5 + 0.5 * wave))
    }

    var body: some View {
        Capsule()
            .fill(color.opacity(0.6 + energy * 0.4))
            .frame(width: 3, height: height)
            .animation(.easeInOut(duration: 0.05), value: height)
    }
}

// MARK: - Pulse Ring (for album art)

struct PulseRingView: View {
    let energy: Double
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.0

    var body: some View {
        Circle()
            .stroke(Color.spotifyGreen, lineWidth: 2)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear { pulse() }
    }

    private func pulse() {
        let duration = 2.0 - energy * 1.0 // faster pulse for high energy
        withAnimation(.easeOut(duration: duration).repeatForever(autoreverses: false)) {
            scale = 1.3
            opacity = 0
        }
        scale = 1.0
        opacity = energy * 0.6
    }
}
