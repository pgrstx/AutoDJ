import Foundation
import Combine

@MainActor
class SpotifyAPIManager: ObservableObject {
    static let shared = SpotifyAPIManager()

    @Published var playbackState: PlaybackState?
    @Published var nextTrack: SpotifyTrack?
    @Published var nextTrackFeatures: AudioFeatures?
    @Published var isPolling = false

    private var pollTask: Task<Void, Never>?
    private var lastFetchedFeaturesID = ""
    private var lastFetchedNextID = ""
    private let auth = SpotifyAuthManager.shared

    // MARK: - Polling

    func startPolling() {
        guard pollTask == nil else { return }
        isPolling = true
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchCurrentlyPlaying()
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
        nextTrack = nil
        nextTrackFeatures = nil
        lastFetchedFeaturesID = ""
        lastFetchedNextID = ""
    }

    // MARK: - Currently Playing

    func fetchCurrentlyPlaying() async {
        guard let token = await auth.validToken() else { return }
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing") else { return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { return }

            switch http.statusCode {
            case 204:
                playbackState = nil
                return
            case 401:
                await auth.refreshAccessToken()
                return
            case 200:
                break
            default:
                return
            }

            let raw = try JSONDecoder().decode(RawCurrentlyPlayingResponse.self, from: data)
            guard let item = raw.item, raw.currently_playing_type == "track" else {
                playbackState = nil
                return
            }

            let track = mapTrack(item)
            var state = PlaybackState(
                track: track,
                progressMs: raw.progress_ms ?? 0,
                isPlaying: raw.is_playing,
                audioFeatures: playbackState?.track.id == track.id
                    ? playbackState?.audioFeatures
                    : nil
            )

            // Fetch audio features when track changes
            if track.id != lastFetchedFeaturesID {
                lastFetchedFeaturesID = track.id
                if let features = await fetchAudioFeatures(for: track.id) {
                    state.audioFeatures = features
                }
                // Also fetch queue for next track
                await fetchQueue()
            }

            playbackState = state

        } catch {
            // Swallow polling errors gracefully
        }
    }

    // MARK: - Audio Features

    func fetchAudioFeatures(for trackID: String) async -> AudioFeatures? {
        guard let token = await auth.validToken() else { return nil }
        guard let url = URL(string: "https://api.spotify.com/v1/audio-features/\(trackID)") else { return nil }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(AudioFeatures.self, from: data)
        } catch {
            print("[API] Audio features fetch failed: \(error)")
            return nil
        }
    }

    // MARK: - Queue

    func fetchQueue() async {
        guard let token = await auth.validToken() else { return }
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/queue") else { return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }

            let raw = try JSONDecoder().decode(RawQueueResponse.self, from: data)
            guard let firstItem = raw.queue.first else {
                nextTrack = nil
                nextTrackFeatures = nil
                return
            }

            let track = mapTrack(firstItem)
            nextTrack = track

            // Fetch next track's audio features if new
            if track.id != lastFetchedNextID {
                lastFetchedNextID = track.id
                nextTrackFeatures = await fetchAudioFeatures(for: track.id)
            }
        } catch {
            print("[API] Queue fetch failed: \(error)")
        }
    }

    // MARK: - Playback Control

    func setVolume(_ percent: Int) async {
        guard let token = await auth.validToken() else { return }
        let clamped = max(0, min(100, percent))
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/volume?volume_percent=\(clamped)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
    }

    func skipToNext() async {
        guard let token = await auth.validToken() else { return }
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/next") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
    }

    /// Seek to a position in the current track (for cue-in points)
    func seek(toMs positionMs: Int) async {
        guard let token = await auth.validToken() else { return }
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/seek?position_ms=\(positionMs)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
    }

    // MARK: - Helpers

    private func mapTrack(_ item: RawTrackItem) -> SpotifyTrack {
        SpotifyTrack(
            id: item.id,
            name: item.name,
            artist: item.artists.map(\.name).joined(separator: ", "),
            albumName: item.album.name,
            albumArtURL: item.album.images.first.flatMap { URL(string: $0.url) },
            durationMs: item.duration_ms
        )
    }
}

// MARK: - Raw Decodable Models

private struct RawCurrentlyPlayingResponse: Decodable {
    let is_playing: Bool
    let progress_ms: Int?
    let item: RawTrackItem?
    let currently_playing_type: String
}

private struct RawQueueResponse: Decodable {
    let currently_playing: RawTrackItem?
    let queue: [RawTrackItem]
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
