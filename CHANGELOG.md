# Changelog

All notable changes to LayoutLight are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.2] - 2026-07-23

### Fixed
- Keep the window-edge indicator aligned with the main Chrome window when Chromium exposes auxiliary layer-0 surfaces before it.
- Hide indicators while macOS Secure Event Input is active so App Store and other protected password dialogs remain unobstructed.
- Hide the window indicator while an application-owned popover or menu covers the indicated edge.

### Added
- Public GitHub release pipeline: signed + notarized DMG via `scripts/release.sh`.

## [1.0] - 2026-06-04

### Added
- Menu-bar flag showing the active input source.
- **Caret indicator** — colored line, square, dot, or underline following the text caret
  in supported applications (TextEdit, Notes, Mail, Pages, Xcode, Safari, Chrome, Edge, Arc, Slack, Discord, ...).
  Uses two Accessibility paths:
  - `AXSelectedTextRange` + `AXBoundsForRange` for native Cocoa text fields.
  - `AXSelectedTextMarkerRange` + `AXBoundsForTextMarkerRange` for WebKit / Chromium content.
- **Window / edge indicator** — highlight the focused window with a frame, or show a single edge line (ShowyEdge-like).
- **Language-aware colors** — separate colors for English and Russian indicators.
- **Hotkeys:**
  - `⌃⌥⇧⌘1` — switch to Russian
  - `⌃⌥⇧⌘2` — switch to English
  - `⌃⇧L` — show current language overlay
- **Auto overlay on switch** — briefly shows the current language when the system input source changes.
- **Launch at login** through macOS Service Management.
- **Localized settings** — English and Russian UI.
- Event-driven Accessibility observer (`AXObserver`) with low-rate fallback poll for apps that don't emit all notifications.

[Unreleased]: https://github.com/biyachuev/LayoutLight/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/biyachuev/LayoutLight/compare/v1.0.1...v1.0.2
[1.0]: https://github.com/biyachuev/LayoutLight/releases/tag/v1.0
