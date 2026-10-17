# TV Remote manual test checklist

Run these checks on the same private Wi-Fi network before release.

## Pairing and security

- Launch the Mac companion and verify that it publishes a six-digit pairing code.
- Confirm that an iPhone discovers the Mac without entering an IP address.
- Try an incorrect code; the iPhone must show an error and must not be able to send a command.
- Pair the iPhone, force-quit and reopen it, and verify it reconnects using its Keychain token.
- Pair the Chrome extension from its options page and verify reloading the extension reconnects it.
- Rotate the code on the Mac and confirm a new device cannot pair with the previous code.

## Chrome player controls

For both Hulu and Disney+, start a title and verify play/pause, mute, volume, 15-second seek, and fullscreen. Verify next/previous only when the respective service provides those actions.

- With no supported tab or no player loaded, press a remote command and verify the iPhone receives the unavailable state.
- With two supported tabs open, use the most recently active player and verify that it receives the command.
- Close the active streaming tab and verify the app does not report a successful command.

## Reconnection

- Toggle Wi-Fi off and on for the iPhone; wait for discovery and reconnect.
- Reload the streaming page and verify status updates resume.
- Stop and restart the Mac companion; verify the phone and extension reconnect without requiring a new pairing code.

## Chrome touchpad

- Grant TV Remote Accessibility permission in System Settings > Privacy & Security > Accessibility, then restart the Mac companion. The menu bar should report "Accessibility granted".
- With Chrome frontmost, verify: drag moves the Mac cursor (1.6x), tap clicks, the Drag toggle holds the mouse button while moving, the right strip scrolls, Back sends Cmd+[, and Type sends text into a focused search/address field.
- Switch to another app (Finder, Notes) and repeat a drag/tap: nothing must happen and the phone should show "only works while Chrome is frontmost".
- Revoke Accessibility permission and verify input is rejected with the permission message rather than silently failing.
- Note: device builds need a valid provisioning profile; simulator builds verify compilation only.

## Disney+ browse remote

- Reload the extension and Disney+ page, then verify visible Disney+ tiles appear on the phone.
- Verify Back, Home, directional focus, Select, and direct tile taps act on the browser tab.
- Open Disney+ search, enter a query on the phone, and confirm the search field and visible results update.
- With no Disney+ tab open, verify browse controls report the unavailable state rather than acting on another tab.
- Treat the phone grid as a reflection of the currently visible browser page, not a complete Disney+ catalog.
