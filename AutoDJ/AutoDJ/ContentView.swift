import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: SpotifyAuthManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                PlayerView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: authManager.isAuthenticated)
    }
}
