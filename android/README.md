# PK Remote for Android

This directory contains the native Android phone app for PK Remote. It lives beside `ios/` and uses the iOS implementation as the product and protocol reference.

## Milestone 1: Compose UI foundation

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

Not implemented in this milestone:

- network discovery
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

Android-specific implementations required later:

- `NsdManager` service discovery and fresh endpoint resolution
- Android Keystore generation and recovery of the per-installation client identity
- TLS socket configuration for ports 6467 and 6466
- lifecycle-aware connection ownership and cancellation
- DataStore persistence for shortcuts and non-secret state

## Future permissions

Milestone 1 declares no network permissions. Discovery and transport milestones are expected to evaluate and narrowly add:

- `INTERNET`
- `ACCESS_NETWORK_STATE`
- `CHANGE_WIFI_MULTICAST_STATE`
- Android-version-specific nearby Wi-Fi permission handling if required by the chosen NSD implementation

The finished app must not depend on ADB.
