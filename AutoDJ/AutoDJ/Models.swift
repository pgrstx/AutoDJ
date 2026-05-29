import Foundation
import SwiftUI

// MARK: - Spotify Track

struct SpotifyTrack: Identifiable, Equatable {
    let id: String
    let name: String
    let artist: String
    let albumName: String
    let albumArtURL: URL?
    let durationMs: Int

    var durationSec: Double { Double(durationMs) / 1000.0 }
}

// MARK: - Audio Features

struct AudioFeatures: Codable, Equatable {
    let tempo: Double         // BPM
    let key: Int              // 0–11
    let mode: Int             // 0=minor, 1=major
    let energy: Double        // 0.0–1.0
    let valence: Double       // 0.0–1.0
    let danceability: Double  // 0.0–1.0
    let loudness: Double      // dB
    let id: String

    /// Returns seconds per beat
    var secondsPerBeat: Double { 60.0 / tempo }
}

// MARK: - Playback State

struct PlaybackState: Equatable {
    let track: SpotifyTrack
    let progressMs: Int
    let isPlaying: Bool
    var audioFeatures: AudioFeatures?

    var progressFraction: Double {
        guard track.durationMs > 0 else { return 0 }
        return Double(progressMs) / Double(track.durationMs)
    }

    var remainingMs: Int { track.durationMs - progressMs }
    var remainingSec: Double { Double(remainingMs) / 1000.0 }
    var progressSec: Double { Double(progressMs) / 1000.0 }

    static func == (lhs: PlaybackState, rhs: PlaybackState) -> Bool {
        lhs.track.id == rhs.track.id &&
        lhs.progressMs == rhs.progressMs &&
        lhs.isPlaying == rhs.isPlaying
    }
}

// MARK: - Compatibility Score

struct CompatibilityScore {
    let bpmScore: Int          // 0–100
    let keyScore: Int          // 0–100
    let overall: Int           // 0–100
    let quality: TransitionQuality
    let energyNote: EnergyNote
    let currentCamelot: CamelotKey?
    let nextCamelot: CamelotKey?
    let bpmDifference: Double  // percentage
    let adjustedBPM: Double?   // if tempo-matched
}

// MARK: - Enums

enum TransitionQuality: Equatable {
    case great   // 70–100
    case decent  // 40–69
    case clash   // 0–39

    var label: String {
        switch self {
        case .great:  return "Great Match"
        case .decent: return "Decent Match"
        case .clash:  return "Key Clash"
        }
    }

    var color: Color {
        switch self {
        case .great:  return Color(red: 0.114, green: 0.725, blue: 0.329) // Spotify green
        case .decent: return Color(red: 0.98, green: 0.76, blue: 0.18)   // yellow
        case .clash:  return Color(red: 0.9, green: 0.27, blue: 0.27)    // red
        }
    }

    var badgeText: String {
        switch self {
        case .great:  return "✓"
        case .decent: return "~"
        case .clash:  return "✗"
        }
    }
}

enum EnergyNote: Equatable {
    case bigJump    // next > current + 0.3
    case bigDrop    // next < current - 0.3
    case smooth     // within ±0.15
    case moderate   // everything else

    var description: String {
        switch self {
        case .bigJump:  return "Energy spike — sharp transition"
        case .bigDrop:  return "Energy drop — slow fade out"
        case .smooth:   return "Smooth energy flow"
        case .moderate: return "Standard transition"
        }
    }
}

enum TransitionStyle: String, CaseIterable, Codable {
    case auto       = "Auto"
    case fullDJ     = "Always Full DJ"
    case crossfade  = "Always Crossfade"
    case quickCut   = "Always Quick Cut"
}

enum TransitionLength: String, CaseIterable, Codable {
    case short  = "Short (8 beats)"
    case medium = "Medium (16 beats)"
    case long   = "Long (32 beats)"

    var beats: Int {
        switch self {
        case .short:  return 8
        case .medium: return 16
        case .long:   return 32
        }
    }
}

// MARK: - Session Energy

struct SessionEnergyPoint {
    let timestamp: Date
    let trackID: String
    let energy: Double
}

// MARK: - App Settings

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var transitionStyle: TransitionStyle {
        didSet { save() }
    }
    @Published var transitionLength: TransitionLength {
        didSet { save() }
    }
    @Published var showCompatibilityScores: Bool {
        didSet { save() }
    }

    private init() {
        let defaults = UserDefaults.standard
        transitionStyle = TransitionStyle(rawValue: defaults.string(forKey: "transitionStyle") ?? "") ?? .auto
        transitionLength = TransitionLength(rawValue: defaults.string(forKey: "transitionLength") ?? "") ?? .medium
        showCompatibilityScores = defaults.bool(forKey: "showCompatibilityScores") == false
            ? true
            : defaults.bool(forKey: "showCompatibilityScores")
    }

    private func save() {
        UserDefaults.standard.set(transitionStyle.rawValue, forKey: "transitionStyle")
        UserDefaults.standard.set(transitionLength.rawValue, forKey: "transitionLength")
        UserDefaults.standard.set(showCompatibilityScores, forKey: "showCompatibilityScores")
    }
}
