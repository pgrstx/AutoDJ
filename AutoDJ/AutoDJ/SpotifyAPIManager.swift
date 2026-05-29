import Foundation
import Combine

// MARK: - Data Models

struct SpotifyTrack: Equatable {
    let id: String
    let name: String
    let artist: String
    let albumName: String
    let albumArtURL: URL?
    let durationMs: Int
}

struct PlaybackState {
    let track: SpotifyTrack
    let progressMs: Int
    let isPlaying: Bool

    var progressFraction: Double {
        guard track.durationMs > 0 else { return 0 }
        return Double(progressMs) / Double(track.durationMs)
    }

    var remainingMs: Int {
        track.durationMs - progressMs
    }
}

// MARK: - Manager

@MainActor
class SpotifyAPIManager: ObservableObject {
    static let shared = SpotifyAPIManager()

    @Published var playbackState: PlaybackState?
    @Published var isPolling = false

    private var pollTask: Task<Void, Never>?
    private let authManager = SpotifyAuthManager.shared

    func startPolling() {
        guard pollTask == nil else { return }
        isPolling = true
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchPlaybackState()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        isPolling = false
    }

    func reset() {
        stopPolling()
        playbackState = nil
    }

    // MARK: - Fetch

    func fetchPlaybackState() async {
        guard let token = await authManager.validToken() else { return }
        var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { return }

            if http.statusCode == 204 {
                // Nothing playing
                playbackState = nil
                return
            }
            if http.statusCode == 401 {
                await authManager.refreshAccessToken()
                return
            }
            guard http.statusCode == 200 else { return }

            let raw = try JSONDecoder().decode(RawPlaybackResponse.self, from: data)
            guard let item = raw.item else {
                playbackState = nil
                return
            }

            let track = SpotifyTrack(
                id: item.id,
                name: item.name,
                artist: item.artists.map(\.name).joined(separator: ", "),
                albumName: item.album.name,
                albumArtURL: item.album.images.first.flatMap { URL(string: $0.url) },
                durationMs: item.duration_ms
            )
            playbackState = PlaybackState(
                track: track,
                progressMs: raw.progress_ms ?? 0,
                isPlaying: raw.is_playing
            )
        } catch {
            // Silently ignore network errors during polling
        }
    }

    // MARK: - Playback Control

    func setVolume(_ percent: Int) async {
        guard let token = await authManager.validToken() else { return }
        let clamped = max(0, min(100, percent))
        var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/volume?volume_percent=\(clamped)")!)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
    }

    func skipToNext() async {
        guard let token = await authManager.validToken() else { return }
        var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/next")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
    }
}

// MARK: - Raw Decodable Models

private struct RawPlaybackResponse: Decodable {
    let is_playing: Bool
    let progress_ms: Int?
    let item: RawTrackItem?
}

private struct RawTrackItem: Decodable {
    let id: String
    let name: String
    let duration_ms: Int
    let artists: [RawArtist]
    let album: RawAlbum
}

private struct RawArtist: Decodable {
    let name: String
}

private struct RawAlbum: Decodable {
    let name: String
    let images: [RawImage]
}

private struct RawImage: Decodable {
    let url: String
    let width: Int?
    let height: Int?
}
