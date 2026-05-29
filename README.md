# AutoDJ

A SwiftUI multiplatform app (iOS 16+ / macOS 13+) that adds smooth DJ-style crossfade transitions to whatever you're already playing on Spotify.

## What it does

AutoDJ sits on top of your Spotify playback and automatically crossfades between tracks — no playlist management, no song picking. It just makes every transition buttery smooth.

- **Automatic crossfades** — detects when a track is ending and fades to the next one
- **Adjustable duration** — choose 3s, 5s, 8s, or 10s crossfade windows
- **DJ Mode toggle** — flip it on/off at any time
- **Background operation** — works while your phone is locked or you're using other apps
- **Live track info** — album art, track name, artist, progress bar

## Setup

### Spotify Developer Dashboard

1. Go to [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard)
2. Create an app (or use your existing one)
3. Add `mydjapp://callback` to the **Redirect URIs**
4. The Client ID is already embedded in the app

### Building

1. Open `AutoDJ/AutoDJ.xcodeproj` in Xcode 15+
2. Select your team in Signing & Capabilities
3. Run on iOS Simulator, device, or Mac

## Architecture

| File | Purpose |
|------|---------|
| `SpotifyAuthManager` | PKCE OAuth flow, token storage in Keychain, auto-refresh |
| `SpotifyAPIManager` | 1-second polling of `/v1/me/player`, volume control, skip |
| `DJEngine` | Monitors remaining time, triggers fade-out → skip → fade-in |
| `KeychainManager` | Secure token persistence |
| `PlayerView` | Main UI — album art, track info, progress bar, DJ toggle |
| `SettingsView` | Crossfade duration picker, account disconnect |

## How the crossfade works

1. `SpotifyAPIManager` polls Spotify every second for current track + progress
2. `DJEngine` checks if `remaining_time <= crossfade_duration`
3. When triggered: fade Spotify volume 100→0 over N seconds, then `POST /next`, then fade 0→100
4. New track detected → reset state, restore volume

## Tech stack

- SwiftUI (multiplatform)
- `AuthenticationServices` (ASWebAuthenticationSession for OAuth)
- Spotify Web API (REST, PKCE — no client secret)
- Keychain Services
- AVFoundation-ready architecture
