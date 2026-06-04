# Security

LayoutLight is a local macOS menu-bar utility. It does not use networking, analytics, or remote update code. Settings are stored locally in `UserDefaults`.

## Accessibility

Caret and window indicators use macOS Accessibility APIs to read UI geometry from the focused application. LayoutLight uses this access to locate the caret or focused window; it does not store, transmit, or intentionally log user text.

The window indicator also observes global mouse movement/click/drag metadata to hide or refresh the overlay while the user interacts with windows and the menu bar. It does not capture keyboard input, mouse coordinates are not stored, and no observed data is sent over the network.

LayoutLight is not sandboxed because Accessibility APIs require running outside the App Sandbox.

## Binary Distribution Checklist

This project is published as source code and does not provide official binaries. If you choose to distribute a binary build, verify it before sharing:

- Build with Hardened Runtime enabled.
- Sign with a Developer ID certificate.
- Notarize the app.
- Verify `get-task-allow` is absent from release entitlements.
- Verify the expected entitlements:

```sh
codesign --display --entitlements - LayoutLight.app
codesign -dvv LayoutLight.app
```

In `codesign -dvv`, confirm the runtime flag is present:

```text
flags=0x10000(runtime)
```
