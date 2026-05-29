import Foundation
import AVFoundation
import Combine

/// DJEngine monitors Spotify playback and triggers crossfade when a track
/// is within `crossfadeDuration` seconds of its end.
///
/// Because Spotify Web API doesn't expose audio streams, we use the
/// Spotify volume endpoint to fade out the current track and fade in
/// the next track simultaneously, creating the DJ crossfade effect.
@MainActor
class DJEngine: ObservableObject {
    static let shared = DJEngine()

    // MARK: - Settings

    @Published var isDJModeEnabled: Bool = false {
        didSet { isDJModeEnabled ? startEngine() : stopEngine() }
    }
    @Published var crossfadeDuration: Double = 8.0   // seconds

    // MARK: - State

    @Published var isFading = false
    @Published var currentVolume: Int = 100

    private var lastTrackID: String?
    private var fadeTask: Task<Void, Never>?
    private var monitorTask: Task<Void, Never>?
    private var fadingTrackID: String?

    private let apiManager = SpotifyAPIManager.shared

    private init() {}

    // MARK: - Engine Lifecycle

    func startEngine() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkAndFade()
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s tick
            }
        }
    }

    func stopEngine() {
        monitorTask?.cancel()
        fadeTask?.cancel()
        monitorTask = nil
        fadeTask = nil
        isFading = false
        fadingTrackID = nil
    }

    func stop() {
        isDJModeEnabled = false
        stopEngine()
    }

    // MARK: - Core Logic

    private func checkAndFade() async {
        guard isDJModeEnabled,
              let state = apiManager.playbackState,
              state.isPlaying else { return }

        let track = state.track

        // New track detected — reset fade state
        if track.id != lastTrackID {
            lastTrackID = track.id
            fadingTrackID = nil
            isFading = false
            fadeTask?.cancel()
            fadeTask = nil
            // Restore full volume on track change
            await restoreVolume()
        }

        // Already fading this track
        if fadingTrackID == track.id { return }

        // Check if we're within the crossfade window
        let remainingSec = Double(state.remainingMs) / 1000.0
        if remainingSec <= crossfadeDuration && remainingSec > 0 {
            fadingTrackID = track.id
            await performCrossfade(duration: min(remainingSec, crossfadeDuration))
        }
    }

    // MARK: - Crossfade

    private func performCrossfade(duration: Double) async {
        isFading = true
        defer { isFading = false }

        let steps = max(Int(duration * 10), 1) // 10 steps per second
        let stepDelay = UInt64((duration / Double(steps)) * 1_000_000_000)

        // Fade out current track volume 100 → 0
        for step in 0...steps {
            if Task.isCancelled { break }
            let volume = Int(Double(100) * (1.0 - Double(step) / Double(steps)))
            currentVolume = volume
            await apiManager.setVolume(volume)
            if step < steps {
                try? await Task.sleep(nanoseconds: stepDelay)
            }
        }

        // Skip to next track
        if !Task.isCancelled {
            await apiManager.skipToNext()
            // Brief pause to let Spotify register the skip
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        // Fade in new track 0 → 100
        if !Task.isCancelled {
            for step in 0...steps {
                if Task.isCancelled { break }
                let volume = Int(Double(100) * Double(step) / Double(steps))
                currentVolume = volume
                await apiManager.setVolume(volume)
                if step < steps {
                    try? await Task.sleep(nanoseconds: stepDelay)
                }
            }
        }

        if !Task.isCancelled {
            currentVolume = 100
            await apiManager.setVolume(100)
        }
    }

    private func restoreVolume() async {
        currentVolume = 100
        await apiManager.setVolume(100)
    }
}
