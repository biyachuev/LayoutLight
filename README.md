# LayoutLight

LayoutLight is a small macOS menu-bar utility that makes the active keyboard layout visible without interrupting typing.

It can show the current layout near the text caret, around the focused window, along a screen edge, and as a compact flag overlay when the input source changes.

This is a personal macOS project. Source code is here; prebuilt DMGs will appear on the [Releases](../../releases) page once code signing is set up.

## Features

- **Status bar flag** — the current input source is shown in the menu bar.
- **Caret indicator** — a colored line, square, dot, or underline follows the text caret in supported applications.
- **Window / edge indicator** — highlight the focused window with a frame, or show a single edge line similar to ShowyEdge.
- **Language-aware colors** — use separate colors for English and Russian indicators.
- **Hotkeys**:
  - `⌃ ⌥ ⇧ ⌘ 1` switches to Russian.
  - `⌃ ⌥ ⇧ ⌘ 2` switches to English.
  - `⌃ ⇧ L` shows the current language overlay.
- **Auto overlay on switch** — briefly shows the current language when the system input source changes.
- **Launch at login** — optional startup through macOS Service Management.
- **Localized settings** — English and Russian UI.

## Build

Open `LayoutLight.xcodeproj` in Xcode 16+ and build the `LayoutLight` scheme.

LayoutLight currently requires macOS 15.5 or later.

Command-line debug build:

```sh
xcodebuild -project LayoutLight.xcodeproj -scheme LayoutLight -configuration Debug build
```

Command-line release build:

```sh
xcodebuild -project LayoutLight.xcodeproj -scheme LayoutLight -configuration Release build
```

Tested on Apple Silicon.

Because the project is intended to be built locally, macOS may ask for Accessibility permission for your locally signed copy of the app.

## Permissions

- **Caret and window indicators** require Accessibility access because macOS exposes caret and focused-window geometry through Accessibility APIs.
- **Hotkeys and input-source observation** use public macOS APIs and do not require extra permissions.
- LayoutLight does not use networking, analytics, or remote update code.

## How Caret Tracking Works

LayoutLight uses two Accessibility paths to find the caret position:

1. **Native Cocoa text fields** — `AXSelectedTextRange` + `AXBoundsForRange`.
2. **WebKit / Chromium content** — `AXSelectedTextMarkerRange` + `AXBoundsForTextMarkerRange`.

The indicator is event-driven: a per-app `AXObserver` fires on focus and selection changes, with a low-rate fallback poll for apps that do not emit all notifications.

## Known Limitations

| Application | Status | Reason |
|---|---|---|
| TextEdit, Notes, Mail, Pages, Xcode | Works | Native Accessibility text geometry |
| Safari URL bar and web inputs | Works | Native + text-marker geometry |
| Chrome, Edge, Arc | Works | Text-marker geometry |
| VS Code, Cursor | Requires `editor.accessibilitySupport: "on"` | Accessibility is disabled by default unless a screen reader is detected |
| Slack, Discord | Usually works | Modern Electron text-marker geometry |
| Microsoft Word | Partial | Office Accessibility support is incomplete |
| Sublime Text | Does not work | Custom rendering, no text bounds |
| Terminal.app, iTerm2, Warp | Does not work | Terminals do not expose text-range bounds |
| Figma, some JetBrains IDEs | Does not work | Custom rendering, no text bounds |

This is a macOS API limitation: there is no public API to globally recolor the native caret in every application.

## Security and Privacy

See [SECURITY.md](SECURITY.md).

## License

MIT License. See [LICENSE](LICENSE).
