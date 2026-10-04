#!/usr/bin/env bash
set -euo pipefail

IDENTITY="-"
PROFILE="machungry-notary"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --identity) IDENTITY="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 64 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/MacHungry.app"
DMG="$BUILD/MacHungry.dmg"
cd "$ROOT"

for ARCH in arm64 x86_64; do
  swift build -c release --triple "$ARCH-apple-macosx14.0" --scratch-path ".build/$ARCH"
done

rm -rf "$APP" "$DMG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create \
  ".build/arm64/release/MacHungry" \
  ".build/x86_64/release/MacHungry" \
  -output "$APP/Contents/MacOS/MacHungry"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/Themes "$APP/Contents/Resources/Themes"

if [[ "$IDENTITY" == "-" ]]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
codesign --verify --strict "$APP"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname MacHungry -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

if [[ "$IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$IDENTITY" "$DMG"
  xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

echo "App: $APP"
echo "DMG: $DMG"
