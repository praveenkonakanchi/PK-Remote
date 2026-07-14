# PK Remote

PK Remote is an open-source Google TV and Android TV remote for iPhone, built with SwiftUI.

The project is currently in its first UI milestone: it provides a polished, static remote interface with local-only controls. Device discovery, pairing, and command transmission are planned but are not implemented yet.

## Current Features

- Devices, Remote, and STB Mode navigation
- Placeholder Google TV device named **PKD**
- Directional pad with select, home, back, and power controls
- Volume, mute, number-pad, and media controls
- STB Mode shortcuts for Search, View, Sort, and Favorites
- Semantic remote commands with harmless local actions
- Accessibility labels and SwiftUI previews
- Native light and dark appearance support
- No third-party dependencies

## Screenshots

Screenshots are coming soon.

## Roadmap

- [x] Static remote interface
- [x] Reusable remote-control components
- [x] Accessible light and dark UI
- [ ] Google TV and Android TV discovery with Bonjour (mDNS)
- [ ] Secure pairing with an on-screen pairing code
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
- Swift Concurrency *(planned for device communication)*
- Network framework *(planned)*
- Bonjour / mDNS *(planned)*
- Google TV Remote Protocol *(planned)*

## Project Structure

```text
PK Remote/
├── Components/       Reusable remote-control views
├── Features/         Devices, Remote, and STB Mode screens
├── Models/           Semantic remote command types
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

The buttons currently update local UI state only. The app does not discover, pair with, or control a physical TV yet.

## Contributing

Contributions are welcome. Please open an issue to discuss significant changes, keep pull requests focused, and include relevant build or test results.

When contributing connectivity features, do not commit pairing secrets, certificates, or other credentials.

## License

This project is intended to be distributed under the MIT License. A license file will be added before the first release.
