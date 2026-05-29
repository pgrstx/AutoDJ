import Foundation
import CryptoKit
import AuthenticationServices

@MainActor
class SpotifyAuthManager: NSObject, ObservableObject {
    static let shared = SpotifyAuthManager()

    private let clientID = "938db8f656ae49a38f49266e992dbacb"
    private let redirectURI = "mydjapp://callback"
    private let scopes = "user-read-playback-state user-modify-playback-state user-read-currently-playing"

    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var authError: String?

    private var codeVerifier = ""
    private var authSession: ASWebAuthenticationSession?

    private enum Keys {
        static let accessToken  = "spotify_access_token"
        static let refreshToken = "spotify_refresh_token"
        static let tokenExpiry  = "spotify_token_expiry"
    }

    var accessToken: String? {
        get { KeychainManager.load(forKey: Keys.accessToken) }
        set {
            if let v = newValue { KeychainManager.save(v, forKey: Keys.accessToken) }
            else { KeychainManager.delete(forKey: Keys.accessToken) }
        }
    }

    private var refreshToken: String? {
        get { KeychainManager.load(forKey: Keys.refreshToken) }
        set {
            if let v = newValue { KeychainManager.save(v, forKey: Keys.refreshToken) }
            else { KeychainManager.delete(forKey: Keys.refreshToken) }
        }
    }

    private var tokenExpiry: Date? {
        get {
            guard let s = KeychainManager.load(forKey: Keys.tokenExpiry),
                  let ts = Double(s) else { return nil }
            return Date(timeIntervalSince1970: ts)
        }
        set {
            if let v = newValue {
                KeychainManager.save("\(v.timeIntervalSince1970)", forKey: Keys.tokenExpiry)
            } else {
                KeychainManager.delete(forKey: Keys.tokenExpiry)
            }
        }
    }

    override init() {
        super.init()
        isAuthenticated = accessToken != nil
    }

    // MARK: - PKCE

    private func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func codeChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Login

    func login() {
        authError = nil
        codeVerifier = makeCodeVerifier()
        let challenge = codeChallenge(from: codeVerifier)

        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
        ]
        guard let url = comps.url else { return }

        isAuthenticating = true
        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "mydjapp"
        ) { [weak self] callbackURL, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isAuthenticating = false
                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin { return }
                guard let callbackURL else {
                    self.authError = error?.localizedDescription
                    return
                }
                await self.handleCallback(url: callbackURL)
            }
        }
        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = false
        authSession?.start()
    }

    func handleCallback(url: URL) async {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = comps.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            authError = "Invalid callback URL"
            return
        }
        await exchangeCode(code)
    }

    // MARK: - Token Exchange

    private func exchangeCode(_ code: String) async {
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = [
            "grant_type=authorization_code",
            "code=\(code)",
            "redirect_uri=\(redirectURI)",
            "client_id=\(clientID)",
            "code_verifier=\(codeVerifier)"
        ].joined(separator: "&").data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(TokenResponse.self, from: data)
            storeTokens(resp)
        } catch {
            authError = "Token exchange failed: \(error.localizedDescription)"
        }
    }

    func refreshAccessToken() async {
        guard let rt = refreshToken else { return }
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = [
            "grant_type=refresh_token",
            "refresh_token=\(rt)",
            "client_id=\(clientID)"
        ].joined(separator: "&").data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(TokenResponse.self, from: data)
            storeTokens(resp)
        } catch {
            print("Refresh failed: \(error)")
        }
    }

    /// Returns a valid (non-expired) access token, refreshing if needed.
    func validToken() async -> String? {
        if let expiry = tokenExpiry, expiry > Date().addingTimeInterval(60) {
            return accessToken
        }
        await refreshAccessToken()
        return accessToken
    }

    private func storeTokens(_ resp: TokenResponse) {
        accessToken = resp.access_token
        if let rt = resp.refresh_token { refreshToken = rt }
        tokenExpiry = Date().addingTimeInterval(Double(resp.expires_in))
        isAuthenticated = true
    }

    func logout() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        isAuthenticated = false
        SpotifyAPIManager.shared.reset()
        DJEngine.shared.stop()
    }
}

// MARK: - Presentation Context

extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
#if os(macOS)
        return NSApplication.shared.windows.first(where: \.isKeyWindow) ?? NSWindow()
#else
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? UIWindow()
#endif
    }
}

// MARK: - Models

private struct TokenResponse: Decodable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
}
