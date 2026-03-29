#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/Clawd.app"
CONTENTS="$APP_DIR/Contents"
DMG_PATH="$BUILD_DIR/Clawd.dmg"

SIGN_IDENTITY="Developer ID Application: Companion, Inc. (5LYD7HDS6X)"
TEAM_ID="5LYD7HDS6X"
BUNDLE_ID="com.getcompanion.clawd"

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
    <string>${BUNDLE_ID}</string>
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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/getcompanion-ai/pet-clawd/main/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>p/STOfduNWVMNYn1sjYX3pbM5PnywVU/8WrGUJjpoAI=</string>
</dict>
</plist>
PLIST

cat > "$BUILD_DIR/Clawd.entitlements" << ENTITLEMENTS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
ENTITLEMENTS

RESOURCE_BUNDLE="$(swift build -c release --show-bin-path)/Clawd_Clawd.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$CONTENTS/Resources/"
fi

echo "Embedding Sparkle framework..."
mkdir -p "$CONTENTS/Frameworks"
SPARKLE_PATH="$(find "$ROOT/.build/artifacts" -name "Sparkle.framework" -type d | head -1)"
if [ -n "$SPARKLE_PATH" ] && [ -d "$SPARKLE_PATH" ]; then
    cp -R "$SPARKLE_PATH" "$CONTENTS/Frameworks/"
fi

echo "Generating app icon..."
python3 "$ROOT/scripts/gen-icon.py"
ICNS="$BUILD_DIR/Clawd.icns"
if [ -f "$ICNS" ]; then
    cp "$ICNS" "$CONTENTS/Resources/AppIcon.icns"
fi

echo "Signing with Developer ID..."
if [ -d "$CONTENTS/Frameworks/Sparkle.framework" ]; then
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$CONTENTS/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc"
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$CONTENTS/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc"
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$CONTENTS/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$CONTENTS/Frameworks/Sparkle.framework/Versions/B/Updater.app"
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$CONTENTS/Frameworks/Sparkle.framework"
fi
codesign --force --options runtime --entitlements "$BUILD_DIR/Clawd.entitlements" --sign "$SIGN_IDENTITY" "$APP_DIR"

echo "Verifying signature..."
codesign --verify --deep --strict "$APP_DIR"
spctl --assess --type execute --verbose "$APP_DIR" || true

echo "Notarizing..."
ZIP_FOR_NOTARIZE="$BUILD_DIR/Clawd-notarize.zip"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_FOR_NOTARIZE"
xcrun notarytool submit "$ZIP_FOR_NOTARIZE" \
    --team-id "$TEAM_ID" \
    --wait \
    --apple-id "advait@companion.ai" \
    --keychain-profile "notarytool-clawd" 2>&1 || {
    echo ""
    echo "If notarization fails with auth error, run this once to store credentials:"
    echo "  xcrun notarytool store-credentials notarytool-clawd --apple-id advait@companion.ai --team-id $TEAM_ID"
    echo ""
    echo "Then re-run this script."
    rm -f "$ZIP_FOR_NOTARIZE"
    exit 1
}
rm -f "$ZIP_FOR_NOTARIZE"

echo "Stapling notarization ticket..."
xcrun stapler staple "$APP_DIR"

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
