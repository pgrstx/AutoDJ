import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var apiManager:  SpotifyAPIManager
    @EnvironmentObject var djEngine:    DJEngine
    @EnvironmentObject var authManager: SpotifyAuthManager
    @EnvironmentObject var settings:    AppSettings

    @State private var showSettings  = false
    @State private var albumImage:   PlatformImage? = nil
    @State private var lastAlbumURL: URL? = nil

    private var currentEnergy: Double {
        apiManager.playbackState?.audioFeatures?.energy ?? 0.3
    }

    var body: some View {
        ZStack {
            backgroundLayer
            contentLayer
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(djEngine)
                .environmentObject(authManager)
                .environmentObject(settings)
        }
        .onChange(of: apiManager.playbackState?.track.albumArtURL) { url in
            Task { await loadImage(url) }
        }
        .onAppear {
            apiManager.startPolling()
            Task { await loadImage(apiManager.playbackState?.track.albumArtURL) }
        }
        .onDisappear {
            if !djEngine.isDJModeEnabled { apiManager.stopPolling() }
        }
    }

    // MARK: - Layers

    private var backgroundLayer: some View {
        ZStack {
            Color.djBlack.ignoresSafeArea()
            if let img = albumImage {
                PlatformImageView(image: img)
                    .scaledToFill()
                    .ignoresSafeArea()
                    .blur(radius: 80)
                    .opacity(0.5)
                    .clipped()
            }
            LinearGradient(
                colors: [Color.black.opacity(0.3), Color.djBlack.opacity(0.85), Color.djBlack],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var contentLayer: some View {
        VStack(spacing: 0) {
            topBar.padding(.horizontal, 20).padding(.top, topPadding)

            Spacer()

            // Album art with pulse ring
            albumArtSection
                .padding(.horizontal, 36)

            Spacer(minLength: 20)

            // Track info
            trackInfoSection
                .padding(.horizontal, 24)

            // Waveform energy indicator
            if let features = apiManager.playbackState?.audioFeatures {
                WaveformView(energy: features.energy)
                    .frame(height: 36)
                    .padding(.horizontal, 40)
                    .padding(.top, 12)
            }

            // Progress bar
            progressSection
                .padding(.horizontal, 24)
                .padding(.top, 14)

            // Up Next card
            if let next = apiManager.nextTrack {
                upNextCard(track: next)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
            }

            // DJ Mode toggle
            djToggle
                .padding(.horizontal, 20)
                .padding(.top, 14)

            Spacer(minLength: 28)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("AutoDJ")
                .font(.system(size: 20, weight: .black))
                .foregroundColor(.white)
            Spacer()
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 19))
                    .foregroundColor(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Album Art

    private var albumArtSection: some View {
        ZStack {
            if let img = albumImage {
                PlatformImageView(image: img)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.55), radius: 40, x: 0, y: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .overlay(
                        // Pulse ring overlay
                        PulseRingView(energy: currentEnergy)
                            .padding(-12)
                    )
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.07))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 56))
                            .foregroundColor(.white.opacity(0.18))
                    )
            }
        }
        .animation(.easeInOut(duration: 0.6), value: albumImage != nil)
    }

    // MARK: - Track Info

    private var trackInfoSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                if let state = apiManager.playbackState {
                    Text(state.track.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(state.track.artist)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)

                    if let features = state.audioFeatures {
                        HStack(spacing: 10) {
                            audioFeaturePill(
                                icon: "metronome",
                                text: "\(Int(features.tempo)) BPM"
                            )
                            if let camelot = CamelotWheel.camelotKey(spotifyKey: features.key, mode: features.mode) {
                                audioFeaturePill(
                                    icon: "music.quarternote.3",
                                    text: camelot.description
                                )
                            }
                        }
                        .padding(.top, 4)
                    }
                } else {
                    Text("Not Playing")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                    Text("Open Spotify and start a track")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            Spacer()

            if djEngine.isTransitioning {
                TransitionIndicator(progress: djEngine.transitionProgress)
            }
        }
    }

    private func audioFeaturePill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.white.opacity(0.55))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }

    // MARK: - Progress Bar

    private var progressSection: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12)).frame(height: 3)
                    Capsule()
                        .fill(Color.spotifyGreen)
                        .frame(
                            width: geo.size.width * CGFloat(apiManager.playbackState?.progressFraction ?? 0),
                            height: 3
                        )
                }
            }
            .frame(height: 3)

            HStack {
                Text(formatMs(apiManager.playbackState?.progressMs ?? 0))
                Spacer()
                Text(formatMs(apiManager.playbackState?.track.durationMs ?? 0))
            }
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.4))
        }
        .animation(.linear(duration: 0.8), value: apiManager.playbackState?.progressMs)
    }

    // MARK: - Up Next Card

    private func upNextCard(track: SpotifyTrack) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("UP NEXT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
                    .kerning(1.2)
                Text(track.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            if let score = djEngine.compatibilityScore, settings.showCompatibilityScores {
                VStack(spacing: 4) {
                    // Camelot key badge
                    if let nextCamelot = score.nextCamelot {
                        Text(nextCamelot.description)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    // BPM
                    if let nextFeatures = apiManager.nextTrackFeatures {
                        Text("\(Int(nextFeatures.tempo)) BPM")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }

                // Score badge
                ZStack {
                    Circle()
                        .fill(score.quality.color)
                        .frame(width: 44, height: 44)
                    VStack(spacing: 0) {
                        Text("\(score.overall)")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.white)
                        Text(score.quality.badgeText)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    djEngine.compatibilityScore.map { $0.quality.color.opacity(0.3) } ?? Color.clear,
                    lineWidth: 1
                )
        )
    }

    // MARK: - DJ Toggle

    private var djToggle: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("DJ Mode")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Group {
                    if djEngine.isDJModeEnabled {
                        if let score = djEngine.compatibilityScore {
                            Text(score.energyNote.description)
                                .foregroundColor(score.quality.color)
                        } else {
                            Text("Monitoring playback…")
                                .foregroundColor(.spotifyGreen)
                        }
                    } else {
                        Text("Tap to enable auto-crossfade")
                            .foregroundColor(.white.opacity(0.38))
                    }
                }
                .font(.caption)
                .lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: $djEngine.isDJModeEnabled)
                .toggleStyle(SpotifyToggleStyle())
                .labelsHidden()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private var topPadding: CGFloat {
#if os(iOS)
        return 12
#else
        return 20
#endif
    }

    private func formatMs(_ ms: Int) -> String {
        let total = ms / 1000
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func loadImage(_ url: URL?) async {
        guard let url, url != lastAlbumURL else { return }
        lastAlbumURL = url
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
#if os(iOS)
        albumImage = UIImage(data: data)
#else
        albumImage = NSImage(data: data)
#endif
    }
}

// MARK: - Transition Indicator

private struct TransitionIndicator: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 3)
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.spotifyGreen, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 36, height: 36)
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.spotifyGreen)
            }
            Text("MIX")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.spotifyGreen)
                .kerning(1)
        }
        .animation(.linear, value: progress)
    }
}

// MARK: - Spotify Toggle Style

struct SpotifyToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(configuration.isOn ? Color.spotifyGreen : Color.white.opacity(0.18))
            .frame(width: 52, height: 30)
            .overlay(
                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .offset(x: configuration.isOn ? 11 : -11)
                    .animation(.spring(response: 0.22, dampingFraction: 0.75), value: configuration.isOn)
            )
            .onTapGesture { configuration.isOn.toggle() }
    }
}

// MARK: - Platform Image

#if os(iOS)
typealias PlatformImage = UIImage
struct PlatformImageView: View {
    let image: UIImage
    var body: some View { Image(uiImage: image).resizable() }
}
#else
typealias PlatformImage = NSImage
struct PlatformImageView: View {
    let image: NSImage
    var body: some View { Image(nsImage: image).resizable() }
}
#endif

// MARK: - Color

extension Color {
    static let spotifyGreen = Color(red: 0.114, green: 0.725, blue: 0.329)
    static let djBlack      = Color(red: 0.07, green: 0.07, blue: 0.07)
}
