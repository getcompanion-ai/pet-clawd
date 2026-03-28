#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/Clawd.app"
CONTENTS="$APP_DIR/Contents"
DMG_PATH="$BUILD_DIR/Clawd.dmg"

echo "Building release binary..."
cd "$ROOT"
swift build -c release

BINARY="$(swift build -c release --show-bin-path)/Clawd"
if [ ! -f "$BINARY" ]; then
    echo "Error: binary not found at $BINARY"
    exit 1
fi

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

cp "$BINARY" "$CONTENTS/MacOS/Clawd"

VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

cat > "$CONTENTS/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Clawd</string>
    <key>CFBundleDisplayName</key>
    <string>Clawd</string>
    <key>CFBundleIdentifier</key>
    <string>com.getcompanion.clawd</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>Clawd</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Clawd uses screen capture to provide context about what you're looking at when answering questions.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

RESOURCE_BUNDLE="$(swift build -c release --show-bin-path)/Clawd_Clawd.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$CONTENTS/Resources/"
fi

echo "Creating DMG..."
rm -f "$DMG_PATH"

DMG_STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_DIR" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "Clawd" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGING"

echo ""
echo "Done."
echo "  App: $APP_DIR"
echo "  DMG: $DMG_PATH"
