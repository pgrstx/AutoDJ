import SwiftUI

@main
struct AutoDJApp: App {
    @StateObject private var authManager = SpotifyAuthManager.shared
    @StateObject private var apiManager = SpotifyAPIManager.shared
    @StateObject private var djEngine = DJEngine.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(apiManager)
                .environmentObject(djEngine)
                .onOpenURL { url in
                    Task { @MainActor in
                        await authManager.handleCallback(url: url)
                    }
                }
                .preferredColorScheme(.dark)
        }
#if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 600)
#endif
    }
}
