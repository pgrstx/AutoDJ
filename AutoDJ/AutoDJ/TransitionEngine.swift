import Foundation
import AVFoundation

// MARK: - Transition Engine
//
// The TransitionEngine orchestrates DJ-style transitions between Spotify tracks.
//
// Architecture note:
// The Spotify Web API does not expose the raw audio stream, so AVAudioUnitEQ
// and AVAudioUnitTimePitch are used here for:
//   1. Maintaining an active AVAudioSession (background audio keepalive)
//   2. Providing the structural framework for EQ/pitch manipulation
//      if audio routing were available (e.g. via Spotify iOS SDK / AirPlay)
//
// What IS controlled via the Web API:
//   - Volume crossfade  → PUT /v1/me/player/volume
//   - Skip to next      → POST /v1/me/player/next
//   - Seek (cue points) → PUT /v1/me/player/seek

@MainActor
class TransitionEngine: ObservableObject {
    static let shared = TransitionEngine()

    // MARK: - AVFoundation Graph

    private let audioEngine   = AVAudioEngine()
    private let playerNode    = AVAudioPlayerNode()
    private let timePitchNode = AVAudioUnitTimePitch()
    private let eqNode        = AVAudioUnitEQ(numberOfBands: 3)

    // MARK: - State

    @Published var isTransitioning = false
    @Published var transitionProgress: Double = 0  // 0.0–1.0

    private var activeTransitionTask: Task<Void, Never>?
    private let api = SpotifyAPIManager.shared

    // MARK: - Setup

    func setupAudioEngine() {
        configureAudioSession()
        buildAudioGraph()
        configureEQBands()
        startEngine()
        scheduleSilentBuffer()
    }

    private func configureAudioSession() {
#if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("[TransitionEngine] AVAudioSession setup failed: \(error)")
        }
#endif
    }

    private func buildAudioGraph() {
        audioEngine.attach(playerNode)
        audioEngine.attach(timePitchNode)
        audioEngine.attach(eqNode)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        audioEngine.connect(playerNode, to: timePitchNode, format: format)
        audioEngine.connect(timePitchNode, to: eqNode, format: format)
        audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: format)
    }

    private func configureEQBands() {
        // Band 0: Sub-bass / bass (80Hz, low shelf)
        eqNode.bands[0].filterType  = .lowShelf
        eqNode.bands[0].frequency   = 200.0
        eqNode.bands[0].gain        = 0.0
        eqNode.bands[0].bypass      = false

        // Band 1: Mid (1kHz, parametric)
        eqNode.bands[1].filterType  = .parametric
        eqNode.bands[1].frequency   = 1000.0
        eqNode.bands[1].bandwidth   = 1.0
        eqNode.bands[1].gain        = 0.0
        eqNode.bands[1].bypass      = false

        // Band 2: High (8kHz, high shelf)
        eqNode.bands[2].filterType  = .highShelf
        eqNode.bands[2].frequency   = 8000.0
        eqNode.bands[2].gain        = 0.0
        eqNode.bands[2].bypass      = false
    }

    private func startEngine() {
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("[TransitionEngine] Engine start failed: \(error)")
        }
    }

    /// Schedules a silent looping buffer to keep the audio session alive in background.
    private func scheduleSilentBuffer() {
        let sampleRate = 44100.0
        let frameCount = AVAudioFrameCount(sampleRate * 5) // 5-second silent buffer
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { return }
        buffer.frameLength = frameCount
        // Buffer is zero-initialized = silence
        playerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        playerNode.play()
    }

    // MARK: - Transition Execution

    func executeTransition(
        score: CompatibilityScore,
        currentFeatures: AudioFeatures,
        nextFeatures: AudioFeatures,
        style: TransitionStyle,
        length: TransitionLength
    ) async {
        guard !isTransitioning else { return }

        activeTransitionTask?.cancel()
        activeTransitionTask = Task { [weak self] in
            await self?.runTransition(
                score: score,
                currentFeatures: currentFeatures,
                nextFeatures: nextFeatures,
                style: style,
                length: length
            )
        }
    }

    private func runTransition(
        score: CompatibilityScore,
        currentFeatures: AudioFeatures,
        nextFeatures: AudioFeatures,
        style: TransitionStyle,
        length: TransitionLength
    ) async {
        isTransitioning = true
        transitionProgress = 0
        defer {
            isTransitioning = false
            transitionProgress = 0
        }

        // Resolve effective quality
        let effectiveQuality: TransitionQuality
        switch style {
        case .auto:      effectiveQuality = score.quality
        case .fullDJ:    effectiveQuality = .great
        case .crossfade: effectiveQuality = .decent
        case .quickCut:  effectiveQuality = .clash
        }

        switch effectiveQuality {
        case .great:
            await fullDJTransition(
                currentBPM: currentFeatures.tempo,
                nextFeatures: nextFeatures,
                beats: length.beats,
                energyNote: score.energyNote
            )
        case .decent:
            await standardCrossfade(
                durationSec: Double(min(length.beats, 8)) * currentFeatures.secondsPerBeat,
                nextFeatures: nextFeatures
            )
        case .clash:
            await quickCutTransition(nextFeatures: nextFeatures)
        }
    }

    // MARK: - Full DJ Transition (Score 70–100)

    private func fullDJTransition(
        currentBPM: Double,
        nextFeatures: AudioFeatures,
        beats: Int,
        energyNote: EnergyNote
    ) async {
        let window = CompatibilityEngine.transitionWindowSeconds(
            bpm: currentBPM,
            beats: beats,
            energyNote: energyNote
        )
        let steps = max(Int(window * 10), 10)
        let stepNs = UInt64((window / Double(steps)) * 1_000_000_000)

        // Set tempo-pitch rate on our audio engine node
        // (would affect any audio routed through our engine)
        let rate = CompatibilityEngine.tempoRate(from: currentBPM, to: nextFeatures.tempo)
        timePitchNode.rate = rate

        // Phase 1: Apply EQ — cut bass on outgoing (prevents dual bassline clash)
        cutBass(on: eqNode)

        // Phase 2: Fade out current track 100 → 0
        for step in 0...steps {
            if Task.isCancelled { return }
            let vol = Int(Double(100) * (1.0 - Double(step) / Double(steps)))
            await api.setVolume(vol)
            transitionProgress = Double(step) / Double(steps) * 0.5
            if step < steps { try? await Task.sleep(nanoseconds: stepNs) }
        }

        // Phase 3: Skip to next track
        if !Task.isCancelled {
            await api.skipToNext()
            try? await Task.sleep(nanoseconds: 400_000_000) // let Spotify register skip
        }

        // Phase 4: Seek to cue-in point
        if !Task.isCancelled,
           let nextTrack = SpotifyAPIManager.shared.nextTrack {
            let cueMs = CompatibilityEngine.cueInPoint(for: nextFeatures, durationMs: nextTrack.durationMs)
            if cueMs > 0 {
                await api.seek(toMs: cueMs)
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }

        // Phase 5: Restore bass EQ (incoming track has full bass now)
        restoreBass(on: eqNode)

        // Phase 6: Fade in new track 0 → 100
        for step in 0...steps {
            if Task.isCancelled { return }
            let vol = Int(Double(100) * Double(step) / Double(steps))
            await api.setVolume(vol)
            transitionProgress = 0.5 + Double(step) / Double(steps) * 0.5
            if step < steps { try? await Task.sleep(nanoseconds: stepNs) }
        }

        // Restore tempo-pitch
        timePitchNode.rate = 1.0
        await api.setVolume(100)
    }

    // MARK: - Standard Crossfade (Score 40–69)

    private func standardCrossfade(durationSec: Double, nextFeatures: AudioFeatures) async {
        let halfDur = max(durationSec / 2, 1.0)
        let steps = max(Int(halfDur * 10), 5)
        let stepNs = UInt64((halfDur / Double(steps)) * 1_000_000_000)

        // Fade out
        for step in 0...steps {
            if Task.isCancelled { return }
            let vol = Int(100 * (1.0 - Double(step) / Double(steps)))
            await api.setVolume(vol)
            transitionProgress = Double(step) / Double(steps) * 0.5
            if step < steps { try? await Task.sleep(nanoseconds: stepNs) }
        }

        if !Task.isCancelled {
            await api.skipToNext()
            try? await Task.sleep(nanoseconds: 300_000_000)
            // Cue point for medium energy tracks
            if let nextTrack = SpotifyAPIManager.shared.nextTrack {
                let cueMs = CompatibilityEngine.cueInPoint(for: nextFeatures, durationMs: nextTrack.durationMs)
                if cueMs > 0 { await api.seek(toMs: cueMs) }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }

        // Fade in
        for step in 0...steps {
            if Task.isCancelled { return }
            let vol = Int(100 * Double(step) / Double(steps))
            await api.setVolume(vol)
            transitionProgress = 0.5 + Double(step) / Double(steps) * 0.5
            if step < steps { try? await Task.sleep(nanoseconds: stepNs) }
        }

        await api.setVolume(100)
    }

    // MARK: - Quick Cut (Score 0–39)

    private func quickCutTransition(nextFeatures: AudioFeatures) async {
        // 2s fade out
        let fadeSteps = 20
        let stepNs: UInt64 = 100_000_000 // 100ms

        for step in 0...fadeSteps {
            if Task.isCancelled { return }
            let vol = Int(100 * (1.0 - Double(step) / Double(fadeSteps)))
            await api.setVolume(vol)
            transitionProgress = Double(step) / Double(fadeSteps) * 0.4
            try? await Task.sleep(nanoseconds: stepNs)
        }

        // 0.5s silence
        if !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await api.skipToNext()
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        // 1.5s fade in
        for step in 0...fadeSteps {
            if Task.isCancelled { return }
            let vol = Int(100 * Double(step) / Double(fadeSteps))
            await api.setVolume(vol)
            transitionProgress = 0.6 + Double(step) / Double(fadeSteps) * 0.4
            try? await Task.sleep(nanoseconds: UInt64(75_000_000))
        }

        await api.setVolume(100)
    }

    // MARK: - EQ Helpers

    /// Cut sub-bass on the outgoing track to prevent dual-bassline clash
    private func cutBass(on eq: AVAudioUnitEQ) {
        eq.bands[0].gain = -12.0 // Cut 12dB below 200Hz
    }

    private func restoreBass(on eq: AVAudioUnitEQ) {
        eq.bands[0].gain = 0.0
    }

    // MARK: - Stop

    func stop() {
        activeTransitionTask?.cancel()
        activeTransitionTask = nil
        isTransitioning = false
        timePitchNode.rate = 1.0
        restoreBass(on: eqNode)
    }
}
