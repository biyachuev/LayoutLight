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
#
# Or edit DEVELOPER_ID default below.

set -euo pipefail

APP_NAME="LayoutLight"
DEVELOPER_ID="${DEVELOPER_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-AC_NOTARY}"
BUILD_DIR="build/release"

if [[ -z "$DEVELOPER_ID" ]]; then
  echo "ERROR: DEVELOPER_ID is not set." >&2
  echo "  Example:" >&2
  echo '  DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" ./scripts/release.sh' >&2
  exit 1
fi

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "ERROR: create-dmg not installed. Run: brew install create-dmg" >&2
  exit 1
fi

cd "$(dirname "$0")/.."

rm -rf "$BUILD_DIR"
xattr -cr LayoutLight LayoutLight.xcodeproj
xcodebuild -project LayoutLight.xcodeproj \
  -scheme LayoutLight -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
  CODE_SIGN_STYLE=Manual \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
  build

APP="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

xattr -cr "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

rm -f "$DMG"
create-dmg \
  --volname "$APP_NAME $VERSION" \
  --window-size 500 320 --icon-size 100 \
  --icon "$APP_NAME.app" 130 150 \
  --app-drop-link 370 150 \
  "$DMG" "$APP"

codesign --force --sign "$DEVELOPER_ID" --timestamp "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl -a -vv -t install "$DMG"

echo ""
echo "Ready: $DMG"
