import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var apiManager: SpotifyAPIManager
    @EnvironmentObject var djEngine: DJEngine
    @State private var showSettings = false
    @State private var albumImage: PlatformImage? = nil
    @State private var lastAlbumURL: URL? = nil

    var body: some View {
        ZStack {
            // Blurred album art background
            backgroundLayer

            // Main content
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, safeTopPadding)

                Spacer()

                albumArtView
                    .padding(.horizontal, 32)

                Spacer(minLength: 24)

                trackInfoView
                    .padding(.horizontal, 28)

                progressBarView
                    .padding(.horizontal, 28)
                    .padding(.top, 20)

                djToggleView
                    .padding(.horizontal, 28)
                    .padding(.top, 32)

                Spacer(minLength: 40)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(djEngine)
        }
        .onChange(of: apiManager.playbackState?.track.albumArtURL) { url in
            Task { await loadAlbumImage(url: url) }
        }
        .onAppear {
            Task { await loadAlbumImage(url: apiManager.playbackState?.track.albumArtURL) }
        }
    }

    // MARK: - Subviews

    private var backgroundLayer: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.08).ignoresSafeArea()
            if let img = albumImage {
                PlatformImageView(image: img)
                    .scaledToFill()
                    .ignoresSafeArea()
                    .blur(radius: 60)
                    .opacity(0.45)
                    .clipped()
            }
            Color.black.opacity(0.55).ignoresSafeArea()
        }
    }

    private var topBar: some View {
        HStack {
            Text("AutoDJ")
                .font(.system(size: 20, weight: .black))
                .foregroundColor(.white)
            Spacer()
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    private var albumArtView: some View {
        Group {
            if let img = albumImage {
                PlatformImageView(image: img)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.2))
                    )
            }
        }
        .animation(.easeInOut(duration: 0.5), value: albumImage != nil)
    }

    private var trackInfoView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let state = apiManager.playbackState {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.track.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(state.track.artist)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                    Spacer()
                    if djEngine.isFading {
                        FadeIndicator()
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Not Playing")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Open Spotify and start playing")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
        }
    }

    private var progressBarView: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)
                    Capsule()
                        .fill(Color.spotifyGreen)
                        .frame(width: geo.size.width * (apiManager.playbackState?.progressFraction ?? 0),
                               height: 4)
                }
            }
            .frame(height: 4)

            HStack {
                Text(formatMs(apiManager.playbackState?.progressMs ?? 0))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(formatMs(apiManager.playbackState?.track.durationMs ?? 0))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .animation(.linear(duration: 0.5), value: apiManager.playbackState?.progressMs)
    }

    private var djToggleView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("DJ Mode")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Text(djEngine.isDJModeEnabled
                     ? "Crossfade \(Int(djEngine.crossfadeDuration))s · Active"
                     : "Crossfade off")
                    .font(.caption)
                    .foregroundColor(djEngine.isDJModeEnabled
                                     ? .spotifyGreen
                                     : .white.opacity(0.4))
            }
            Spacer()
            Toggle("", isOn: $djEngine.isDJModeEnabled)
                .toggleStyle(SpotifyToggleStyle())
                .labelsHidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private var safeTopPadding: CGFloat {
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

    private func loadAlbumImage(url: URL?) async {
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

// MARK: - Fade Indicator

private struct FadeIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(Color.spotifyGreen)
                    .frame(width: 3, height: animating ? 14 : 6)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

// MARK: - Custom Toggle

struct SpotifyToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(configuration.isOn ? Color.spotifyGreen : Color.white.opacity(0.2))
            .frame(width: 51, height: 31)
            .overlay(
                Circle()
                    .fill(.white)
                    .frame(width: 27, height: 27)
                    .offset(x: configuration.isOn ? 10 : -10)
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isOn)
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

// MARK: - Color Extension

extension Color {
    static let spotifyGreen = Color(red: 0.114, green: 0.725, blue: 0.329) // #1DB954
}
