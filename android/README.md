# PK Remote for Android

This directory contains the native Android phone app for PK Remote. It lives beside `ios/` and uses the iOS implementation as the product and protocol reference.

## Milestone 2: Google TV discovery

Implemented:

- Kotlin and Jetpack Compose Android application
- Material 3 light and dark themes
- Devices, Remote, and STB Mode bottom navigation
- Reusable D-pad, remote button, media, and number-pad components
- Compact STB layout with portal color controls and the verified default shortcuts
- Semantic `RemoteCommand` model and harmless local-only command handling
- `ViewModel` + `StateFlow` UI state
- Accessibility descriptions and visible Material pressed states
- Unit tests and a Compose navigation test
- Google TV discovery through Android `NsdManager`
- `_androidtvremote2._tcp` service filtering and stable service identity
- Fresh endpoint resolution before a TV is shown, so stale cached advertisements are ignored
- Searching, empty, failure, retry, refresh, found, and lost device states
- Lifecycle-aware discovery that stops when the Devices screen leaves the foreground
- Multicast reception support across the minimum Android version

Not implemented in this milestone:

- pairing or TLS
- Android Keystore identity management
- Remote v2 command transport
- shortcut editing or persistence
- keyboard transmission

The UI must not be interpreted as a working TV connection until those later milestones are implemented and physically validated.

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
- Android Keystore generation and recovery of the per-installation client identity
- TLS socket configuration for ports 6467 and 6466
- lifecycle-aware connection ownership and cancellation
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
