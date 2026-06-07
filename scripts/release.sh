#!/usr/bin/env bash
# Builds a signed + notarized DMG for public distribution.
#
# Prerequisites (one-time, see RELEASE_TODO.md):
#   - Apple Developer Program membership
#   - Developer ID Application certificate in Keychain
#   - notarytool keychain profile named AC_NOTARY (or override via $NOTARY_PROFILE)
#   - brew install create-dmg
#
# Usage:
#   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" ./scripts/release.sh
#   TEAM_ID="TEAMID" ./scripts/release.sh
#   ARCHS="x86_64" DMG_SUFFIX="-intel" BUILD_DIR="/private/tmp/LayoutLight-release-intel" ./scripts/release.sh
#
# Or edit DEVELOPER_ID default below.

set -euo pipefail

APP_NAME="LayoutLight"
DEVELOPER_ID="${DEVELOPER_ID:-}"
TEAM_ID="${TEAM_ID:-VKH47WM4KC}"
NOTARY_PROFILE="${NOTARY_PROFILE:-AC_NOTARY}"
BUILD_DIR="${BUILD_DIR:-/private/tmp/LayoutLight-release}"
OUTPUT_DIR="${OUTPUT_DIR:-build/release}"
ARCHS="${ARCHS:-}"
DMG_SUFFIX="${DMG_SUFFIX:-}"

if [[ -z "$DEVELOPER_ID" ]]; then
  DEVELOPER_ID=$(security find-identity -v -p codesigning \
    | sed -n "s/.*\"\(Developer ID Application: .*(\(${TEAM_ID}\))\)\".*/\1/p" \
    | head -n 1)

  if [[ -z "$DEVELOPER_ID" ]]; then
    echo "ERROR: DEVELOPER_ID is not set and no Developer ID Application identity was found for team $TEAM_ID." >&2
    echo "  Example:" >&2
    echo '  DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" ./scripts/release.sh' >&2
    exit 1
  fi
fi

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "ERROR: create-dmg not installed. Run: brew install create-dmg" >&2
  exit 1
fi

XCODEBUILD_ARCH_ARGS=()
if [[ -n "$ARCHS" ]]; then
  XCODEBUILD_ARCH_ARGS=(ARCHS="$ARCHS" ONLY_ACTIVE_ARCH=NO)
fi

cd "$(dirname "$0")/.."

rm -rf "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"
xattr -cr LayoutLight LayoutLight.xcodeproj
xcodebuild -project LayoutLight.xcodeproj \
  -scheme LayoutLight -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGNING_ALLOWED=NO \
  "${XCODEBUILD_ARCH_ARGS[@]}" \
  build

APP="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="$BUILD_DIR/$APP_NAME-$VERSION$DMG_SUFFIX.dmg"

xattr -cr "$APP"
codesign --force --deep --sign "$DEVELOPER_ID" --timestamp --options runtime \
  --entitlements LayoutLight/LayoutLight.entitlements \
  "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

rm -f "$DMG"
create-dmg \
  --volname "$APP_NAME $VERSION" \
  --window-size 500 320 --icon-size 100 \
  --icon "$APP_NAME.app" 130 150 \
  --app-drop-link 370 150 \
  "$DMG" "$APP"

codesign --force --sign "$DEVELOPER_ID" --timestamp "$DMG" || {
  echo "Retrying DMG codesign timestamp..." >&2
  codesign --force --sign "$DEVELOPER_ID" --timestamp "$DMG"
}
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl -a -vv -t install "$DMG"

OUTPUT_DMG="$OUTPUT_DIR/$(basename "$DMG")"
cp "$DMG" "$OUTPUT_DMG"

echo ""
echo "Ready: $OUTPUT_DMG"
