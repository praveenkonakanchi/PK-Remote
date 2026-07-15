# PK Remote for Android

This directory contains the native Android phone app for PK Remote. It lives beside `ios/` and uses the iOS implementation as the product and protocol reference.

## Milestone 3: secure Google TV connectivity

Implemented:

- Kotlin and Jetpack Compose Android application
- Material 3 light and dark themes
- Devices, Remote, and STB Mode bottom navigation
- Reusable D-pad, remote button, media, and number-pad components
- Compact STB layout with portal color controls and the verified default shortcuts
- Semantic `RemoteCommand` model and authenticated Remote v2 command handling
- `ViewModel` + `StateFlow` UI state
- Accessibility descriptions and visible Material pressed states
- Unit tests and a Compose navigation test
- Google TV discovery through Android `NsdManager`
- `_androidtvremote2._tcp` service filtering and stable service identity
- Fresh endpoint resolution before a TV is shown, so stale cached advertisements are ignored
- Searching, empty, failure, retry, refresh, found, and lost device states
- Lifecycle-aware discovery that stops when the Devices screen leaves the foreground
- Multicast reception support across the minimum Android version
- Per-installation, non-exportable RSA client identity stored in Android Keystore
- Secure Google TV pairing on port 6467 with the six-character code shown on the TV
- Persistent per-device TV certificate fingerprints and paired-state restoration
- Device details with Pair Again and Forget Pairing recovery actions
- Mutual-TLS Remote v2 connections on port 6466 with exact TV certificate pinning
- Protobuf framing, ping responses, IME counters, reconnect handling, and stale-pairing recovery
- Directional, home, back, power, volume, number, media, Quick Settings, and STB color-key commands
- Remote v2 app launching for compatible TV apps
- Native Android keyboard entry transmitted to the focused TV text field
- Screen-local errors with automatic dismissal

Not implemented in this milestone:

- shortcut editing, replacement, removal, and persistence
- the complete verified-app picker and advanced custom-shortcut editor
- release polish and expanded device compatibility testing

## Build

Android Studio 2026.1 includes a compatible JDK. From the repository root:

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
./android/gradlew -p android :app:assembleDebug
./android/gradlew -p android :app:testDebugUnitTest
```

The project currently uses:

- Android Gradle Plugin 9.2.1
- Gradle 9.4.1
- AGP built-in Kotlin 2.2.10
- Compose BOM 2026.06.01
- compile SDK 36.1, target SDK 36, minimum SDK 26

Core 1.18 and Lifecycle 2.10 are intentionally pinned because newer releases require compile SDK 37, which is not needed for this milestone.

## Planned architecture

```text
Compose screens
    ↓ semantic user intent
ViewModel + StateFlow
    ↓ interfaces
Discovery | Pairing | Remote transport | Shortcut persistence
    ↓ Android adapters
NsdManager | Android Keystore | TLS sockets | DataStore
```

Conceptually portable from iOS:

- semantic command model and Android TV key mappings
- protobuf framing and message sequencing
- pairing state machine and stale-pairing recovery
- shortcut catalog, duplicate prevention, and eight-item limit
- TV certificate fingerprint verification

Android-specific implementations:

- `NsdManager` service discovery and fresh endpoint resolution (implemented)
- Android Keystore generation and recovery of the per-installation client identity (implemented)
- TLS socket configuration for ports 6467 and 6466 (implemented)
- lifecycle-aware connection ownership and cancellation (implemented)
- DataStore persistence for shortcuts and non-secret state

## Permissions

Discovery narrowly declares:

- `INTERNET`
- `CHANGE_WIFI_MULTICAST_STATE`

The current target-SDK-36 `NsdManager` path does not require location or Nearby Devices runtime permission. Android 17/API 37 introduces mandatory local-network protections; that migration must use the Android system picker or explicitly request `ACCESS_LOCAL_NETWORK` when the target SDK is raised.

The finished app must not depend on ADB.

## Discovery validation

Validate local-network discovery on a physical Android phone connected to the same Wi-Fi network as the TV. The Android Emulator normally uses the virtual `AndroidWifi` NAT network; mDNS advertisements from the host LAN may be missing, stale, or only partially forwarded there.

Useful debug messages use the `PKRemoteDiscovery` Logcat tag and report when a service is found, resolved, lost, or cannot be resolved. A TV is added to the UI only after its current host and Remote v2 service port resolve successfully.

## Connectivity validation

The connectivity milestone was validated on a physical Motorola Android phone and a physical Google TV. Validation covered discovery, initial secure pairing, authenticated Remote v2 commands, volume and media controls, STB portal color keys, compatible app launching, and keyboard text entry.

The Android Keystore identity remains non-exportable. Its authorization includes the raw RSA operation required by the device's Conscrypt TLS provider while retaining the signing capabilities used by mutual TLS.
