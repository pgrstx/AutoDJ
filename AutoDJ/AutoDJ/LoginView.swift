import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: SpotifyAuthManager

    var body: some View {
        ZStack {
            Color.djBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(Color.spotifyGreen)
                            .frame(width: 96, height: 96)
                        Image(systemName: "waveform.path")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.black)
                    }
                    VStack(spacing: 8) {
                        Text("AutoDJ")
                            .font(.system(size: 40, weight: .black))
                            .foregroundColor(.white)
                        Text("Professional DJ crossfades\nfor your Spotify")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer().frame(height: 52)

                // Features
                VStack(alignment: .leading, spacing: 16) {
                    LoginFeatureRow(icon: "waveform",         text: "Beat-matched transitions")
                    LoginFeatureRow(icon: "music.note.list",  text: "Camelot harmonic key mixing")
                    LoginFeatureRow(icon: "dial.high",        text: "EQ swap & tempo matching")
                    LoginFeatureRow(icon: "bolt.fill",        text: "Energy arc awareness")
                    LoginFeatureRow(icon: "antenna.radiowaves.left.and.right",
                                                              text: "Runs in the background")
                }
                .padding(.horizontal, 48)

                Spacer()

                // CTA
                VStack(spacing: 14) {
                    Button(action: { authManager.login() }) {
                        HStack(spacing: 10) {
                            if authManager.isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.black)
                                    .scaleEffect(0.85)
                                Text("Connecting…")
                            } else {
                                Image(systemName: "music.note")
                                Text("Connect with Spotify")
                            }
                        }
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Color.spotifyGreen)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(authManager.isAuthenticating)
                    .padding(.horizontal, 32)

                    if let err = authManager.authError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }

                Text("Uses PKCE — no password stored")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.25))
                    .padding(.top, 16)
                    .padding(.bottom, 40)
            }
        }
    }
}

private struct LoginFeatureRow: View {
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
                .foregroundColor(.white.opacity(0.8))
        }
    }
}
