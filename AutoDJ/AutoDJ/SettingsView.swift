import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var djEngine: DJEngine
    @EnvironmentObject var authManager: SpotifyAuthManager
    @Environment(\.dismiss) private var dismiss

    private let durationOptions: [Double] = [3, 5, 8, 10]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.1, green: 0.1, blue: 0.1).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // Crossfade Duration
                        SettingsCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Crossfade Duration", systemImage: "waveform.path")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)

                                HStack(spacing: 10) {
                                    ForEach(durationOptions, id: \.self) { option in
                                        DurationChip(
                                            label: "\(Int(option))s",
                                            isSelected: djEngine.crossfadeDuration == option
                                        ) {
                                            djEngine.crossfadeDuration = option
                                        }
                                    }
                                }

                                Text("Crossfade starts \(Int(djEngine.crossfadeDuration)) seconds before the end of each track.")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.45))
                            }
                        }

                        // DJ Mode
                        SettingsCard {
                            HStack {
                                Label("DJ Mode", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                Toggle("", isOn: $djEngine.isDJModeEnabled)
                                    .toggleStyle(SpotifyToggleStyle())
                                    .labelsHidden()
                            }

                            if djEngine.isDJModeEnabled {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.spotifyGreen)
                                        .frame(width: 8, height: 8)
                                    Text("Active — monitoring your Spotify playback")
                                        .font(.caption)
                                        .foregroundColor(.spotifyGreen)
                                }
                                .transition(.opacity)
                            }
                        }

                        // Volume Status
                        SettingsCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Current Volume", systemImage: "speaker.wave.2")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)

                                HStack {
                                    Image(systemName: "speaker.fill")
                                        .foregroundColor(.white.opacity(0.4))
                                        .font(.caption)
                                    ProgressView(value: Double(djEngine.currentVolume), total: 100)
                                        .tint(.spotifyGreen)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Capsule())
                                    Image(systemName: "speaker.wave.3.fill")
                                        .foregroundColor(.white.opacity(0.4))
                                        .font(.caption)
                                }
                                Text("\(djEngine.currentVolume)%")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }

                        // How it works
                        SettingsCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("How It Works", systemImage: "info.circle")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)

                                VStack(alignment: .leading, spacing: 6) {
                                    InfoRow(text: "AutoDJ polls Spotify every second to track playback progress.")
                                    InfoRow(text: "When a track is \(Int(djEngine.crossfadeDuration))s from ending, it fades Spotify's volume to 0 and skips to the next track.")
                                    InfoRow(text: "The new track fades back in to full volume — creating a smooth blend.")
                                    InfoRow(text: "Works with any Spotify content: playlists, radio, autoplay.")
                                }
                            }
                        }

                        // Account
                        SettingsCard {
                            VStack(spacing: 12) {
                                Label("Account", systemImage: "person.circle")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Button(action: {
                                    authManager.logout()
                                    dismiss()
                                }) {
                                    Text("Disconnect Spotify")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.red.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text("AutoDJ v1.0")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.25))
                            .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.spotifyGreen)
                        .fontWeight(.semibold)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Supporting Views

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct DurationChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.spotifyGreen : Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

private struct InfoRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.spotifyGreen)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
