import Foundation
import AVFoundation
#if os(iOS)
import UIKit
import BackgroundTasks
#endif

/// Keeps the app alive in the background on iOS so polling and transitions
/// continue when the screen is locked or the user switches apps.
@MainActor
class BackgroundAudioManager: ObservableObject {
    static let shared = BackgroundAudioManager()

    private init() {
        setupNotifications()
    }

    // MARK: - Audio Session

    func configure() {
#if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: .mixWithOthers)
            try session.setActive(true)
            print("[Background] AVAudioSession configured for background playback")
        } catch {
            print("[Background] AVAudioSession error: \(error)")
        }
#endif
    }

    // MARK: - App Lifecycle Notifications

    private func setupNotifications() {
#if os(iOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleBackground()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleForeground()
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleAudioInterruption(notification)
            }
        }
#endif
    }

    private func handleBackground() {
        print("[Background] App entered background — polling continues")
        // AVAudioSession with .playback category keeps the app alive
        // TransitionEngine's silent player node maintains the session
    }

    private func handleForeground() {
        print("[Background] App returned to foreground")
        // Re-activate session if it was interrupted
#if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(true)
#endif
    }

    private func handleAudioInterruption(_ notification: Notification) {
#if os(iOS)
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            print("[Background] Audio interrupted")
        case .ended:
            if let optValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optValue)
                if options.contains(.shouldResume) {
                    try? AVAudioSession.sharedInstance().setActive(true)
                    print("[Background] Audio session resumed after interruption")
                }
            }
        @unknown default:
            break
        }
#endif
    }
}
