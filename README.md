# Apple TV Remote

Native macOS SwiftUI remote for Apple TV over the local network.

## Current scope

- Bonjour discovery of Apple TVs advertising Companion Link
- PIN pairing through the Apple TV screen
- Keychain-backed credentials through `ItsytvCore`
- Automatic Companion reconnects
- Arrow keys: Up, Down, Left, Right
- Return: Select
- Escape: Menu/Back
- On-screen controls for navigation, Home, Menu, and Play/Pause

The app does not install anything on the Apple TV and does not use system-wide input injection. Keyboard handling is limited to the app while its window is focused.

## Run

Open this folder in Xcode 16 or newer, select the `AppleTVRemote` executable scheme, and run it. On first launch, allow local-network access. Keep the Apple TV awake, choose it from the discovered device list, and enter the PIN shown on the TV.

The package can be parsed and its dependencies resolved with Swift Package Manager. A full Xcode installation is required to compile the SwiftUI macOS executable because the Command Line Tools installation does not include SwiftUI's macro plugin.

## Protocol dependency

The app uses the MIT-licensed [`itsytv-core`](https://github.com/nickustinov/itsytv-core) Swift package for Companion Protocol discovery, pairing, encrypted sessions, and button commands.
