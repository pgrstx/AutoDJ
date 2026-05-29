import Foundation

// MARK: - Compatibility Engine

enum CompatibilityEngine {

    // MARK: - Full Score

    static func score(
        current: AudioFeatures,
        next: AudioFeatures
    ) -> CompatibilityScore {
        let bpmResult = bpmScore(current: current.tempo, next: next.tempo)
        let keyResult = keyScore(current: current, next: next)
        let energyNote = energyNote(currentEnergy: current.energy, nextEnergy: next.energy)

        // Weighted combination: BPM 40%, Key 40%, energy modifier 20%
        let energyBonus: Int = {
            switch energyNote {
            case .smooth:   return 15
            case .moderate: return 5
            case .bigJump, .bigDrop: return -5
            }
        }()

        let base = Int(Double(bpmResult.score) * 0.4 + Double(keyResult.score) * 0.4)
        let overall = max(0, min(100, base + energyBonus))

        let quality: TransitionQuality
        switch overall {
        case 70...100: quality = .great
        case 40...69:  quality = .decent
        default:       quality = .clash
        }

        return CompatibilityScore(
            bpmScore: bpmResult.score,
            keyScore: keyResult.score,
            overall: overall,
            quality: quality,
            energyNote: energyNote,
            currentCamelot: keyResult.currentCamelot,
            nextCamelot: keyResult.nextCamelot,
            bpmDifference: bpmResult.percentDiff,
            adjustedBPM: bpmResult.adjustedBPM
        )
    }

    // MARK: - BPM Scoring

    private struct BPMResult {
        let score: Int
        let percentDiff: Double
        let adjustedBPM: Double?  // the target BPM after tempo adjustment
    }

    private static func bpmScore(current: Double, next: Double) -> BPMResult {
        // Check half-time / double-time
        let candidates: [(bpm: Double, adjusted: Double)] = [
            (next, next),
            (next * 2, next),       // next is half-time
            (next / 2, next)        // next is double-time
        ]

        var bestScore = 0
        var bestDiff = Double.infinity
        var bestAdjusted: Double? = nil

        for candidate in candidates {
            let diff = abs(current - candidate.bpm) / current * 100
            let score: Int
            switch diff {
            case 0..<3:   score = 100
            case 3..<6:   score = 70
            case 6..<10:  score = 40
            default:      score = 20
            }
            if score > bestScore || (score == bestScore && diff < bestDiff) {
                bestScore = score
                bestDiff = diff
                bestAdjusted = candidate.adjusted != next ? candidate.bpm : nil
            }
        }

        return BPMResult(score: bestScore, percentDiff: bestDiff, adjustedBPM: bestAdjusted)
    }

    // MARK: - Key Scoring

    private struct KeyResult {
        let score: Int
        let currentCamelot: CamelotKey?
        let nextCamelot: CamelotKey?
    }

    private static func keyScore(current: AudioFeatures, next: AudioFeatures) -> KeyResult {
        let currentCamelot = CamelotWheel.camelotKey(spotifyKey: current.key, mode: current.mode)
        let nextCamelot = CamelotWheel.camelotKey(spotifyKey: next.key, mode: next.mode)

        guard let c = currentCamelot, let n = nextCamelot else {
            return KeyResult(score: 50, currentCamelot: currentCamelot, nextCamelot: nextCamelot)
        }

        let score = CamelotWheel.keyCompatibilityScore(from: c, to: n)
        return KeyResult(score: score, currentCamelot: c, nextCamelot: n)
    }

    // MARK: - Energy

    static func energyNote(currentEnergy: Double, nextEnergy: Double) -> EnergyNote {
        let diff = nextEnergy - currentEnergy
        if diff > 0.3  { return .bigJump }
        if diff < -0.3 { return .bigDrop }
        if abs(diff) < 0.15 { return .smooth }
        return .moderate
    }

    // MARK: - Cue Point

    /// Returns the cue-in position in milliseconds based on energy + danceability
    static func cueInPoint(for features: AudioFeatures, durationMs: Int) -> Int {
        let skipSeconds: Double
        switch features.energy {
        case 0.7...:    skipSeconds = 0    // High energy: drop straight in
        case 0.4..<0.7: skipSeconds = 15   // Medium energy: skip intro
        default:        skipSeconds = 30   // Low energy / slow build
        }
        let skipMs = Int(skipSeconds * 1000)
        return min(skipMs, durationMs / 3) // Never skip more than 1/3 of the track
    }

    // MARK: - Transition Beat Window

    /// Returns the number of seconds before track end to start the transition
    static func transitionWindowSeconds(
        bpm: Double,
        beats: Int,
        energyNote: EnergyNote
    ) -> Double {
        let baseSeconds = Double(beats) * (60.0 / bpm)

        // Adjust based on energy arc
        switch energyNote {
        case .bigJump:
            return baseSeconds * 0.5  // Shorter, sharper transition
        case .bigDrop:
            return baseSeconds * 1.5  // Longer, slower fade
        default:
            return baseSeconds
        }
    }

    // MARK: - Tempo Rate

    /// Returns the AVAudioUnitTimePitch rate needed to match tempos
    static func tempoRate(from currentBPM: Double, to targetBPM: Double) -> Float {
        guard currentBPM > 0 else { return 1.0 }
        let rate = Float(targetBPM / currentBPM)
        // Clamp to reasonable stretch range (±10%)
        return max(0.90, min(1.10, rate))
    }
}
