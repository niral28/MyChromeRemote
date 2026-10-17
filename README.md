# TV Remote

TV Remote is a local-network remote for an iPhone, a Mac connected to a TV, and Hulu or Disney+ open in Chrome.

## What is included

- `Sources/TVRemoteMac`: a macOS menu-bar app that advertises `_tvremote._tcp` over Bonjour, pairs devices, and securely stores device tokens in Keychain.
- `Apps/TVRemoteiOS`: SwiftUI iPhone target source that discovers the Mac, pairs, and displays a couch-friendly remote.
- `ChromeExtension`: a Manifest V3 extension that bridges the Mac app to Hulu and Disney+ player elements.
- `Sources/TVRemoteProtocol`: the shared, versionable JSON command protocol.

## Run the Mac companion

Open `TVRemote.xcworkspace` in Xcode or run:

```sh
swift run TVRemoteMac
```

Allow incoming local-network connections if macOS asks. The menu bar item shows the six-digit pairing code.

## Install the Chrome bridge

1. Open `chrome://extensions`, enable **Developer mode**, then choose **Load unpacked**.
2. Select the `ChromeExtension` folder.
3. Open the extension's **Details** page, select **Extension options**, and enter the pairing code shown by the Mac companion.
4. Keep Hulu or Disney+ open in the active Chrome window.

## Build the iPhone app

Create an iOS App target in Xcode (iOS 17+) and add the four Swift files and `Info.plist` in `Apps/TVRemoteiOS`.
Add `TVRemoteProtocol` as a local Swift package dependency. Enable the Local Network capability and set `NSLocalNetworkUsageDescription` plus `NSBonjourServices` with `_tvremote._tcp`.

Pair the iPhone with the same six-digit code while it is on the same Wi-Fi network as the Mac.

## Touchpad mode

The iPhone app includes a touchpad that controls the real Mac cursor, so it works with any Hulu/Disney+ page layout:

1. Enable TV Remote in System Settings > Privacy & Security > Accessibility on the Mac, then restart the companion (or use "Grant Accessibility Permission…" in its menu).
2. Keep Google Chrome as the frontmost app on the Mac. Input is rejected with an explanatory message when any other app is frontmost.
3. On the phone: drag to move (tap = click), toggle Drag to hold the mouse button while moving, use the right-hand strip to scroll, Back for browser back, and Type to send text (optionally + Enter) to the focused field.

## Limits

The bridge controls the normal web player only; it does not bypass DRM. Fullscreen may require a one-time interaction with Chrome because browsers can reject programmatic fullscreen requests. Hulu and Disney+ can change their page markup, so their player adapters should be regression-tested after site updates.
