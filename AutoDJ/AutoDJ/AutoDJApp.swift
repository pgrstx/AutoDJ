import SwiftUI

@main
struct AutoDJApp: App {
    @StateObject private var authManager   = SpotifyAuthManager.shared
    @StateObject private var apiManager    = SpotifyAPIManager.shared
    @StateObject private var djEngine      = DJEngine.shared
    @StateObject private var settings      = AppSettings.shared
    @StateObject private var bgManager     = BackgroundAudioManager.shared

    init() {
        BackgroundAudioManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(apiManager)
                .environmentObject(djEngine)
                .environmentObject(settings)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    Task { @MainActor in
                        await authManager.handleCallback(url: url)
                    }
                }
        }
#if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 420, height: 700)
#endif
    }
}
