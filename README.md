# PK Remote

PK Remote is an open-source Google TV and Android TV remote for iPhone, built with SwiftUI.

The project currently provides a polished remote interface, discovers compatible TVs on the local network, and securely pairs with Google TV devices. Remote command transmission is planned but is not implemented yet.

## Current Features

- Devices, Remote, and STB Mode navigation
- Google TV and Android TV discovery with Bonjour (mDNS)
- Device searching, empty, error, refresh, and selection states
- Secure Google TV pairing with a six-character on-screen code
- Per-installation RSA client identity stored in the device-only Keychain
- Paired TV certificate fingerprint stored for future connection verification
- Directional pad with select, home, back, and power controls
- Volume, mute, number-pad, and media controls
- STB Mode shortcuts for Search, View, Sort, and Favorites
- Semantic remote commands with harmless local actions
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
- [ ] Google TV Remote Protocol integration
- [ ] Remote command transmission
- [ ] Keyboard input
- [ ] Voice search
- [ ] Multiple-TV support
- [ ] Device and favorites persistence
- [ ] App Store release

## Tech Stack

- Swift
- SwiftUI
- Xcode
- Swift Concurrency
- Network framework
- Bonjour / mDNS
- Google TV pairing protocol
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
3. Select an iPhone simulator or a development device.
4. Build and run the `PK Remote` scheme.

Remote buttons currently update local UI state only. Device discovery and secure pairing work on a local network; remote command transmission is the next protocol milestone.

## Contributing

Contributions are welcome. Please open an issue to discuss significant changes, keep pull requests focused, and include relevant build or test results.

When contributing connectivity features, do not commit pairing secrets, certificates, or other credentials.

## License

This project is intended to be distributed under the MIT License. A license file will be added before the first release.
