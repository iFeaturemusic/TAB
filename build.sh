#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="TAB"
BUILD="build"
BUNDLE="$BUILD/$APP.app"
MODE="${1:-plain}"
[ "$MODE" = "install" ] && MODE="plain" && set -- plain install

if ! xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1 && [ -d /Applications/Xcode.app ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

generate() {
  if command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate --quiet
  elif [ ! -d "$APP.xcodeproj" ]; then
    echo "Install XcodeGen first: brew install xcodegen"
    exit 1
  fi
}

install_mac() {
  pkill -x "$APP" 2>/dev/null || true
  for _ in $(seq 1 50); do pgrep -x "$APP" >/dev/null || break; sleep 0.1; done
  rm -rf "/Applications/$APP.app"
  cp -R "$BUNDLE" /Applications/
  sleep 0.5
  open "/Applications/$APP.app"
  echo "Installed to /Applications/$APP.app"
}

case "$MODE" in
  plain)
    SDK="$(xcrun --sdk macosx --show-sdk-path)"
    echo "Building ${APP}..."
    rm -rf "$BUNDLE"
    mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
    cp Resources/Info.plist "$BUNDLE/Contents/"
    cp Resources/AppIcon.icns "$BUNDLE/Contents/Resources/"
    for ARCH in arm64 x86_64; do
      xcrun swiftc Sources/*.swift Shared/*.swift \
        -O -swift-version 5 \
        -sdk "$SDK" \
        -target "$ARCH-apple-macos13.0" \
        -o "$BUILD/$APP-$ARCH"
    done
    lipo -create "$BUILD/$APP-arm64" "$BUILD/$APP-x86_64" -output "$BUNDLE/Contents/MacOS/$APP"
    rm -f "$BUILD/$APP-arm64" "$BUILD/$APP-x86_64"
    codesign --force --sign - "$BUNDLE" >/dev/null
    echo "Done: $BUNDLE"
    [ "${2:-}" = "install" ] && install_mac
    ;;

  signed)
    generate
    echo "Building ${APP} with iCloud..."
    xcodebuild -project "$APP.xcodeproj" -scheme TAB -configuration Release \
      -derivedDataPath "$BUILD/DerivedData" -allowProvisioningUpdates -allowProvisioningDeviceRegistration -quiet build
    rm -rf "$BUNDLE"
    cp -R "$BUILD/DerivedData/Build/Products/Release/$APP.app" "$BUNDLE"
    echo "Done: $BUNDLE"
    [ "${2:-}" = "install" ] && install_mac
    ;;

  phone)
    generate
    DEVICE="$(xcrun devicectl list devices 2>/dev/null | awk '/available \(paired\)/ && /iPhone/ {print $3; exit}')"
    if [ -z "$DEVICE" ]; then
      echo "Connect your iPhone and unlock it first."
      exit 1
    fi
    echo "Building TAB for iPhone..."
    xcodebuild -project "$APP.xcodeproj" -scheme TABPhone -configuration Release \
      -destination "generic/platform=iOS" -derivedDataPath "$BUILD/DerivedData" \
      -allowProvisioningUpdates -allowProvisioningDeviceRegistration -quiet build
    PHONE_APP="$BUILD/DerivedData/Build/Products/Release-iphoneos/$APP.app"
    xcrun devicectl device install app --device "$DEVICE" "$PHONE_APP"
    xcrun devicectl device process launch --device "$DEVICE" com.ifeature.TAB.mobile >/dev/null 2>&1 || true
    echo "Installed on your iPhone"
    ;;

  *)
    echo "Usage: ./build.sh [install] | signed [install] | phone"
    exit 1
    ;;
esac
