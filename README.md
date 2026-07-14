# PK Remote

PK Remote is an open-source Google TV and Android TV remote for iPhone, built with SwiftUI. The MVP discovers TVs on the local network, pairs securely using the code shown on the TV, and provides responsive remote, keyboard, media, and STB portal controls.

## Current Features

- Devices, Remote, and STB Mode navigation
- Google TV and Android TV discovery with Bonjour (mDNS)
- Device searching, empty, error, refresh, and selection states
- Secure Google TV pairing with a six-character on-screen code
- Per-installation RSA client identity stored in the device-only Keychain
- Paired TV certificate fingerprint stored for future connection verification
- Persistent per-device pairing state across app launches
- Authenticated Google TV Remote Protocol command connection
- Directional pad with select, home, back, and power controls
- Volume, mute, number-pad, and media controls
- Keyboard text entry for focused TV fields
- STB Mode with Back, Keyboard, Settings, View, Sort, Favorites, Find, and media controls
- Correct Android TV programmable color-key mappings for STB portals
- Accessibility labels and SwiftUI previews
- Native light and dark appearance support
- Apple `swift-certificates` for X.509 certificate generation

## Screenshots

Screenshots are coming soon.

## Roadmap

- [x] Static remote interface
- [x] Reusable remote-control components
- [x] Accessible light and dark UI
- [x] Google TV and Android TV discovery with Bonjour (mDNS)
- [x] Secure pairing with an on-screen pairing code
- [x] Google TV Remote Protocol integration
- [x] Remote command transmission
- [x] Keyboard input
- [x] STB portal color-key controls
- [ ] Voice search
- [ ] Expanded real-device compatibility testing
- [ ] Automated UI tests
- [ ] App Store metadata, screenshots, and privacy details
- [ ] App Store release

## Tech Stack

- Swift
- SwiftUI
- Xcode
- Swift Concurrency
- Network framework
- Bonjour / mDNS
- Google TV pairing and remote protocols
- Security and Keychain services
- Apple `swift-certificates`

## Project Structure

```text
PK Remote/
├── App/              Shared application state
├── Components/       Reusable remote-control views
├── Features/         Devices, Remote, and STB Mode screens
├── Models/           Semantic remote command types
├── Services/         Discovery, pairing, identity, and protocol services
├── Assets.xcassets/  App icons, colors, and image assets
├── ContentView.swift App navigation shell
└── PK_RemoteApp.swift
```

## Getting Started

1. Clone the repository:

   ```bash
   git clone https://github.com/praveenkonakanchi/PK-Remote.git
   ```

2. Open `PK Remote.xcodeproj` in Xcode.
3. Select the **PK Remote** target, open **Signing & Capabilities**, and choose your development team.
4. Connect an iPhone, enable Developer Mode if prompted, and select it as the run destination.
5. Build and run the `PK Remote` scheme.
6. Keep the iPhone and TV on the same local network, select the discovered TV, and enter the six-character code shown on the TV.

The iOS Simulator can be used to review the interface and run tests, but discovery, pairing, and remote commands should be validated on a physical iPhone and compatible TV.

## Installing on a Personal iPhone

- **Free Apple Account:** Xcode can install the app using a Personal Team. The provisioning profile expires after seven days, so the app must be rebuilt and reinstalled periodically.
- **Apple Developer Program:** Use Xcode development or Ad Hoc distribution for registered devices, or upload an archive to TestFlight for beta use.
- **App Store:** For a permanent public installation, create the app record in App Store Connect, archive and upload a release build, complete the required metadata and privacy disclosures, then submit it for App Review.

For everyday use during development, connecting the iPhone to Xcode and pressing Run is the simplest option. Reinstalling the app with the same bundle identifier preserves its app container and Keychain identity in normal update scenarios, so the TV should remain paired.

## MVP Limitations

- Tested primarily against a real Google TV device; behavior may vary across manufacturers and Android TV versions.
- Voice input is not implemented.
- The iPhone and TV must be reachable on the same local network.
- This is not yet an App Store release build.

## Contributing

Contributions are welcome. Please open an issue to discuss significant changes, keep pull requests focused, and include relevant build or test results.

When contributing connectivity features, do not commit pairing secrets, certificates, or other credentials.

## License

PK Remote is available under the [MIT License](LICENSE).
