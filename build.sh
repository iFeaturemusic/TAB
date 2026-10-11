#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="TAB"
BUILD="build"
BUNDLE="$BUILD/$APP.app"

if ! xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1 && [ -d /Applications/Xcode.app ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
SDK="$(xcrun --sdk macosx --show-sdk-path)"

echo "Building $APP…"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp Resources/Info.plist "$BUNDLE/Contents/"
cp Resources/AppIcon.icns "$BUNDLE/Contents/Resources/"

for ARCH in arm64 x86_64; do
  xcrun swiftc Sources/*.swift \
    -O -swift-version 5 \
    -sdk "$SDK" \
    -target "$ARCH-apple-macos13.0" \
    -o "$BUILD/$APP-$ARCH"
done

lipo -create "$BUILD/$APP-arm64" "$BUILD/$APP-x86_64" -output "$BUNDLE/Contents/MacOS/$APP"
rm -f "$BUILD/$APP-arm64" "$BUILD/$APP-x86_64"
codesign --force --sign - "$BUNDLE" >/dev/null

echo "Done: $BUNDLE"

if [ "${1:-}" = "install" ]; then
  pkill -x "$APP" 2>/dev/null || true
  rm -rf "/Applications/$APP.app"
  cp -R "$BUNDLE" /Applications/
  open "/Applications/$APP.app"
  echo "Installed to /Applications/$APP.app"
fi
