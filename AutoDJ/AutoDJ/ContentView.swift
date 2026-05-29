import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: SpotifyAuthManager
    @EnvironmentObject var apiManager: SpotifyAPIManager
    @EnvironmentObject var djEngine: DJEngine

    var body: some View {
        ZStack {
            if authManager.isAuthenticated {
                PlayerView()
                    .onAppear { apiManager.startPolling() }
                    .onDisappear { apiManager.stopPolling() }
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: authManager.isAuthenticated)
    }
}
