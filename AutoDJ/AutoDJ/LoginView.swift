import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: SpotifyAuthManager

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo + title
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.spotifyGreen)
                            .frame(width: 90, height: 90)
                        Image(systemName: "waveform.path")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(.black)
                    }
                    Text("AutoDJ")
                        .font(.system(size: 38, weight: .black, design: .default))
                        .foregroundColor(.white)
                    Text("Smooth crossfades for your Spotify")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Feature highlights
                VStack(alignment: .leading, spacing: 14) {
                    FeatureRow(icon: "arrow.triangle.2.circlepath",
                               text: "Automatic DJ crossfades")
                    FeatureRow(icon: "slider.horizontal.3",
                               text: "Adjustable crossfade duration")
                    FeatureRow(icon: "lock.shield",
                               text: "Secure PKCE login — no password stored")
                    FeatureRow(icon: "antenna.radiowaves.left.and.right",
                               text: "Works in the background")
                }
                .padding(.horizontal, 40)

                Spacer()

                // Login button
                VStack(spacing: 12) {
                    Button(action: { authManager.login() }) {
                        HStack {
                            if authManager.isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.black)
                                    .scaleEffect(0.8)
                                Text("Connecting…")
                            } else {
                                Image(systemName: "music.note")
                                Text("Connect with Spotify")
                            }
                        }
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.spotifyGreen)
                        .clipShape(Capsule())
                    }
                    .disabled(authManager.isAuthenticating)
                    .padding(.horizontal, 32)

                    if let err = authManager.authError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }

                Text("By connecting, you agree to Spotify's Terms of Service")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 32)
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.spotifyGreen)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
        }
    }
}
