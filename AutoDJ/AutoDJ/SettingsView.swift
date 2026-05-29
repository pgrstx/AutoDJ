import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var djEngine:    DJEngine
    @EnvironmentObject var authManager: SpotifyAuthManager
    @EnvironmentObject var settings:    AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.djBlack.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        transitionStyleCard
                        transitionLengthCard
                        compatibilityCard
                        energyArcCard
                        howItWorksCard
                        accountCard
                        Text("AutoDJ v1.0")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.2))
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Settings")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.spotifyGreen)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Transition Style

    private var transitionStyleCard: some View {
        SettingsCard(title: "Transition Style", icon: "arrow.triangle.2.circlepath") {
            VStack(spacing: 10) {
                ForEach(TransitionStyle.allCases, id: \.self) { style in
                    SelectionRow(
                        label: style.rawValue,
                        subtitle: styleDescription(style),
                        isSelected: settings.transitionStyle == style
                    ) {
                        settings.transitionStyle = style
                    }
                }
            }
        }
    }

    private func styleDescription(_ style: TransitionStyle) -> String {
        switch style {
        case .auto:      return "Uses BPM + key compatibility to pick the best mix"
        case .fullDJ:    return "Always 16-beat blend with EQ swap"
        case .crossfade: return "Simple 8-second volume crossfade"
        case .quickCut:  return "Fast 2s fade, silence, fade in"
        }
    }

    // MARK: - Transition Length

    private var transitionLengthCard: some View {
        SettingsCard(title: "Transition Length", icon: "ruler") {
            HStack(spacing: 10) {
                ForEach(TransitionLength.allCases, id: \.self) { length in
                    let parts = length.rawValue.components(separatedBy: " (")
                    DurationChip(
                        label: parts.first ?? length.rawValue,
                        sublabel: parts.count > 1 ? String(parts[1].dropLast()) : "",
                        isSelected: settings.transitionLength == length
                    ) {
                        settings.transitionLength = length
                    }
                }
            }
            Text("Only applies to Full DJ transitions. Controls how many beats before the track end the mix starts.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Compatibility Scores

    private var compatibilityCard: some View {
        SettingsCard(title: "Compatibility Display", icon: "chart.bar") {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Show compatibility scores")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text("BPM match, Camelot key, and score badge on Up Next card")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
                Spacer()
                Toggle("", isOn: $settings.showCompatibilityScores)
                    .toggleStyle(SpotifyToggleStyle())
                    .labelsHidden()
            }

            // Score legend
            if settings.showCompatibilityScores {
                HStack(spacing: 16) {
                    ScoreLegendDot(color: .spotifyGreen, label: "70–100 Great")
                    ScoreLegendDot(color: Color(red: 0.98, green: 0.76, blue: 0.18), label: "40–69 Decent")
                    ScoreLegendDot(color: Color(red: 0.9, green: 0.27, blue: 0.27), label: "0–39 Clash")
                }
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Energy Arc

    private var energyArcCard: some View {
        SettingsCard(title: "Session Energy Arc", icon: "waveform.path.ecg") {
            if djEngine.sessionEnergyArc.isEmpty {
                Text("No data yet — start playing to see your session's energy profile.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            } else {
                EnergyArcChart(points: djEngine.sessionEnergyArc)
                    .frame(height: 60)
            }
        }
    }

    // MARK: - How It Works

    private var howItWorksCard: some View {
        SettingsCard(title: "How It Works", icon: "info.circle") {
            VStack(alignment: .leading, spacing: 8) {
                HowItWorksRow(step: "1", text: "AutoDJ polls Spotify every second for track + position")
                HowItWorksRow(step: "2", text: "Fetches BPM, key, and energy via Spotify Audio Features")
                HowItWorksRow(step: "3", text: "Scores harmonic compatibility using the Camelot Wheel")
                HowItWorksRow(step: "4", text: "On a great match: 16-beat EQ blend with bass-swap technique")
                HowItWorksRow(step: "5", text: "On decent: 8-second crossfade. On clash: quick cut + silence")
                HowItWorksRow(step: "6", text: "Cue points skip intros automatically based on track energy")
            }
        }
    }

    // MARK: - Account

    private var accountCard: some View {
        SettingsCard(title: "Account", icon: "person.circle") {
            Button(action: {
                authManager.logout()
                dismiss()
            }) {
                Text("Disconnect Spotify")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Supporting Views

private struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct SelectionRow: View {
    let label: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.spotifyGreen : Color.white.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(Color.spotifyGreen)
                            .frame(width: 11, height: 11)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

private struct DurationChip: View {
    let label: String
    let sublabel: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                Text(sublabel)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .black.opacity(0.6) : .white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.spotifyGreen : Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

private struct ScoreLegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundColor(.white.opacity(0.5))
        }
    }
}

private struct HowItWorksRow: View {
    let step: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(step)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 18, height: 18)
                .background(Color.spotifyGreen)
                .clipShape(Circle())
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct EnergyArcChart: View {
    let points: [SessionEnergyPoint]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = points.count

            if count >= 2 {
                Path { path in
                    for (i, point) in points.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(count - 1)
                        let y = h * CGFloat(1 - point.energy)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [.spotifyGreen.opacity(0.4), .spotifyGreen],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}
