# LayoutLight Security Best Practices Review

## Executive summary

LayoutLight is a local macOS menu-bar utility written in Swift/SwiftUI/AppKit. I found no critical, high, or medium-severity application vulnerabilities in the reviewed code: there are no runtime network clients/listeners, no server-side input surfaces, no embedded secrets, no dynamic code execution, and no subprocess execution in the app runtime. The main review focus areas are local privacy boundaries around Accessibility access, global event monitors, and defense-in-depth controls for the signed/notarized release path of a non-sandboxed app.

Scope note: the requested `security-best-practices` skill has reference material for Python, JavaScript/TypeScript, and Go only. There is no Swift/macOS-specific reference file in the skill, so this review applies the skill's general secure-coding guidance plus macOS/AppKit security judgment.

## Critical severity

No critical findings.

## High severity

No high-severity findings.

## Medium severity

No medium-severity findings.

## Low severity

### SBP-001: Release hardening is documented but not enforced automatically

The release checklist says official binaries should be signed, notarized, built with Hardened Runtime, and checked for absence of `get-task-allow` (`SECURITY.md:15`, `SECURITY.md:20`). The project enables Hardened Runtime for Debug and Release (`LayoutLight.xcodeproj/project.pbxproj:332`, `LayoutLight.xcodeproj/project.pbxproj:361`), builds the release artifact with Xcode signing disabled (`scripts/release.sh:60`), and then signs explicitly with `--options runtime` and `--entitlements LayoutLight/LayoutLight.entitlements` (`scripts/release.sh:69`, `scripts/release.sh:70`). The script only verifies the signature (`scripts/release.sh:72`) and does not fail the release if unexpected entitlements are present.

Current residual risk is low because the release path uses a deterministic entitlement file whose reviewed content is only `com.apple.security.app-sandbox=false` (`LayoutLight/LayoutLight.entitlements:5`). The recommended gate is defense-in-depth against future regressions: for a non-sandboxed Accessibility app, accidental release of a build with debug/development entitlements would materially increase post-compromise impact and user trust risk.

Recommended mitigation:
- Add explicit release gates after signing:
  - dump entitlements with `codesign --display --entitlements - "$APP"`,
  - fail if `com.apple.security.get-task-allow` is present,
  - fail if `com.apple.security.cs.disable-library-validation`, `com.apple.security.network.client`, `com.apple.security.network.server`, or other unexpected entitlements appear,
  - assert Hardened Runtime via `codesign -dvv "$APP"` and the `runtime` flag.
- Keep the expected entitlement set intentionally tiny. Today it is only `com.apple.security.app-sandbox=false` (`LayoutLight/LayoutLight.entitlements:5`).

### SBP-002: Debug builds may receive base signing entitlements that Release explicitly suppresses

The Release target sets `CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO` (`LayoutLight.xcodeproj/project.pbxproj:356`), but the Debug target does not have the same setting near its signing configuration (`LayoutLight.xcodeproj/project.pbxproj:327`). This does not affect the scripted release artifact because `release.sh` builds with `CODE_SIGNING_ALLOWED=NO` (`scripts/release.sh:60`) and then signs manually with the explicit entitlement file (`scripts/release.sh:69`, `scripts/release.sh:70`). The finding is limited to local Xcode Debug artifacts, which may differ from the reviewed release entitlement profile.

Recommended mitigation:
- Set `CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO` for Debug as well unless there is a concrete development reason not to.
- Add a lightweight test or CI script that verifies Debug and Release entitlements separately, while allowing intentional debug-only differences only when documented.

### SBP-003: Release script uses recursive `xattr -cr` on source and project directories

The release script clears extended attributes recursively from `LayoutLight` and `LayoutLight.xcodeproj` before building (`scripts/release.sh:55`). Clearing xattrs from the built app is common before signing (`scripts/release.sh:68`), but clearing them from source/project inputs can erase provenance or quarantine metadata on the release machine and makes local release preparation more stateful than necessary.

Recommended mitigation:
- Remove the source/project `xattr -cr` step if it is not required.
- If a specific xattr causes a known release failure, delete only that attribute and document why.
- Keep `xattr -cr "$APP"` on the build product if required for signing/notarization.

### SBP-004: Accessibility privacy invariants are manual rather than test-backed

Status: fixed by `scripts/privacy_api_check.sh`, which scans runtime code for networking, pasteboard, subprocess, keychain, socket, and AX text-value API patterns.

The code currently aligns with the stated privacy posture: it reads caret/window geometry and event metadata, not text content. Examples: caret tracking subscribes to focus/selection/value notifications (`LayoutLight/CaretIndicator.swift:369`) and reads selected range/bounds (`LayoutLight/CaretIndicator.swift:668`, `LayoutLight/CaretIndicator.swift:737`, `LayoutLight/CaretIndicator.swift:760`), while window tracking reads focused-window geometry (`LayoutLight/WindowIndicator/WindowFrameGeometry.swift:12`). The privacy statement says the app does not store, transmit, or intentionally log user text (`SECURITY.md:7`) and does not send mouse metadata over the network (`SECURITY.md:9`).

The remaining risk is process adoption: a future change could still introduce selected text capture, pasteboard access, or network APIs if the script is not run before merging/releasing.

Remaining mitigation:
- Run `scripts/privacy_api_check.sh` before commits or releases that touch runtime code; wire it into CI if CI returns to scope.
- Add focused tests around "geometry-only" behavior for Accessibility helpers where feasible.

### SBP-005: UserDefaults color payloads are decoded without numeric clamping

Status: fixed in `LayoutLight/SettingsModels/ColorRGBA.swift`; direct initialization and decoding now clamp components to `0...1` and replace non-finite values with safe fallbacks. Covered by `LayoutLightTests/LayoutLightTests.swift`.

`ColorRGBA` now sanitizes direct initialization and decoding before values reach `NSColor`/`SwiftUI.Color` (`LayoutLight/SettingsModels/ColorRGBA.swift:10`, `LayoutLight/SettingsModels/ColorRGBA.swift:21`, `LayoutLight/SettingsModels/ColorRGBA.swift:31`). `LanguageIndicatorSettingsStore` still decodes persisted `UserDefaults` data directly into settings (`LayoutLight/SettingsStores/LanguageIndicatorSettingsStore.swift:13`), but malformed color components are now clamped or replaced with safe fallbacks.

This is low severity because the attacker must already write to the same user's local preferences, but it is cheap hardening.

Remaining mitigation:
- Apply the same decode-time normalization pattern if new settings models accept numeric values from `UserDefaults`.

### SBP-006: `codesign --deep` can hide future nested-code signing mistakes

The release script signs the app with `codesign --force --deep` (`scripts/release.sh:69`). The current project has no package dependencies or nested frameworks, so this is not an immediate vulnerability. If nested code is added later, `--deep` can make release signing less explicit and may hide unexpected nested contents.

Recommended mitigation:
- Prefer explicit signing of nested code if the app later gains frameworks, helper tools, XPC services, or plugins.
- Add a release check that enumerates nested executable code and fails on unexpected entries.

## Positive observations

- Runtime code has no discovered network clients, listeners, analytics, remote update path, or subprocess execution.
- Hardened Runtime is enabled in the Xcode Debug and Release targets (`LayoutLight.xcodeproj/project.pbxproj:332`, `LayoutLight.xcodeproj/project.pbxproj:361`) and release signing also passes `--options runtime` (`scripts/release.sh:69`).
- Accessibility prompts are user-mediated via `AXIsProcessTrustedWithOptions` (`LayoutLight/CaretIndicator.swift:218`, `LayoutLight/WindowFrameIndicator.swift:376`).
- Caret and window indicator overlays ignore mouse/key focus where relevant (`LayoutLight/CaretIndicator.swift:17`, `LayoutLight/CaretIndicator.swift:20`), reducing accidental interaction capture.
- Global hotkeys validate shortcut keycodes before registration (`LayoutLight/HotKeySettings.swift:16`, `LayoutLight/HotKeyManager.swift:52`).

## Suggested fix order

1. Add release entitlement/runtime verification gates (`SBP-001`) if public distribution returns to scope.
2. Align Debug signing entitlement injection with Release (`SBP-002`) if local debug entitlement parity matters.
3. Remove or narrow source/project `xattr -cr` in the release script (`SBP-003`) if the release script stays in active use.
4. Revisit `codesign --deep` (`SBP-006`) only if nested frameworks, helpers, plugins, or XPC services are added.
