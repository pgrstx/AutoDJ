import Foundation
import Combine

/// DJEngine is the central orchestrator.
/// It watches Spotify playback, scores each upcoming transition,
/// and fires the TransitionEngine at the right beat-aligned moment.
@MainActor
class DJEngine: ObservableObject {
    static let shared = DJEngine()

    // MARK: - Published State

    @Published var isDJModeEnabled: Bool = false {
        didSet { isDJModeEnabled ? startEngine() : stopEngine() }
    }
    @Published var compatibilityScore: CompatibilityScore?
    @Published var sessionEnergyArc: [SessionEnergyPoint] = []
    @Published var currentVolume: Int = 100

    // MARK: - Settings (delegated to AppSettings)
    private let settings = AppSettings.shared

    // MARK: - Internal State

    private var monitorTask: Task<Void, Never>?
    private var lastTrackID = ""
    private var activeTransitionTrackID = ""
    private var transitionFired = false

    private let api          = SpotifyAPIManager.shared
    private let transitions  = TransitionEngine.shared

    private init() {}

    // MARK: - Lifecycle

    func startEngine() {
        transitions.setupAudioEngine()
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    func stopEngine() {
        monitorTask?.cancel()
        monitorTask = nil
        transitions.stop()
    }

    func stop() {
        isDJModeEnabled = false
        stopEngine()
    }

    // MARK: - Main Tick

    private func tick() async {
        guard let state = api.playbackState, state.isPlaying else { return }
        let track = state.track

        // New track detected
        if track.id != lastTrackID {
            lastTrackID = track.id
            transitionFired = false
            activeTransitionTrackID = ""
            currentVolume = 100

            // Record energy arc point
            if let features = state.audioFeatures {
                let point = SessionEnergyPoint(
                    timestamp: Date(),
                    trackID: track.id,
                    energy: features.energy
                )
                sessionEnergyArc.append(point)
                if sessionEnergyArc.count > 50 { sessionEnergyArc.removeFirst() }
            }

            // Re-score with new next track
            updateCompatibilityScore()
        }

        guard isDJModeEnabled,
              !transitionFired,
              activeTransitionTrackID != track.id
        else { return }

        guard let currentFeatures = state.audioFeatures,
              let nextFeatures = api.nextTrackFeatures
        else { return }

        // Calculate beat-aligned transition window
        let beats = settings.transitionLength.beats
        let energyN = CompatibilityEngine.energyNote(
            currentEnergy: currentFeatures.energy,
            nextEnergy: nextFeatures.energy
        )
        let windowSec = CompatibilityEngine.transitionWindowSeconds(
            bpm: currentFeatures.tempo,
            beats: beats,
            energyNote: energyN
        )

        // Fire when within the transition window
        if state.remainingSec <= windowSec && state.remainingSec > 0.5 {
            transitionFired = true
            activeTransitionTrackID = track.id

            guard let score = compatibilityScore else { return }

            await transitions.executeTransition(
                score: score,
                currentFeatures: currentFeatures,
                nextFeatures: nextFeatures,
                style: settings.transitionStyle,
                length: settings.transitionLength
            )
        }
    }

    // MARK: - Compatibility Score Update

    func updateCompatibilityScore() {
        guard let currentFeatures = api.playbackState?.audioFeatures,
              let nextFeatures = api.nextTrackFeatures
        else {
            compatibilityScore = nil
            return
        }
        compatibilityScore = CompatibilityEngine.score(
            current: currentFeatures,
            next: nextFeatures
        )
    }

    // MARK: - Convenience

    var isTransitioning: Bool { transitions.isTransitioning }
    var transitionProgress: Double { transitions.transitionProgress }
}
