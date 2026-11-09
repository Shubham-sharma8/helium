#!/bin/zsh
set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

APP_NAME="Helium"
BUNDLE_ID="com.cogify.helium"
APP_VERSION="0.0.1"
APP_BUILD="1"

ARCHIVE_PATH="$WORKSPACE_DIR/build/${APP_NAME}-${APP_VERSION}.xcarchive"
DIRECT_ARCHIVE_PATH="$WORKSPACE_DIR/build/${APP_NAME}-DirectDistribution.xcarchive"
ARCHIVE_APP="$ARCHIVE_PATH/Products/Applications/${APP_NAME}.app"
ARCHIVE_CONTENTS="$ARCHIVE_APP/Contents"
ARCHIVE_DSYMS="$ARCHIVE_PATH/dSYMs"
PKG_PATH="$WORKSPACE_DIR/build/${APP_NAME}-${APP_VERSION}-AppStore.pkg"
DMG_PATH="$WORKSPACE_DIR/build/${APP_NAME}-${APP_VERSION}.dmg"

echo "==> [1/5] Building Release binaries for ${APP_NAME} v${APP_VERSION} (Build ${APP_BUILD})..."
cd "$WORKSPACE_DIR"
swift build -c release

RELEASE_BIN_DIR="$(swift build -c release --show-bin-path)"

echo "==> [2/5] Constructing Xcode Archive at: $ARCHIVE_PATH"
rm -rf "$ARCHIVE_PATH" "$PKG_PATH" "$DMG_PATH"
mkdir -p "$ARCHIVE_CONTENTS/MacOS"
mkdir -p "$ARCHIVE_CONTENTS/Resources"
mkdir -p "$ARCHIVE_CONTENTS/Helpers"
mkdir -p "$ARCHIVE_DSYMS"

# Copy Release executable into MacOS/Helium
cp "$RELEASE_BIN_DIR/Helium" "$ARCHIVE_CONTENTS/MacOS/Helium"
chmod +x "$ARCHIVE_CONTENTS/MacOS/Helium"

# Build invisible HeliumOpener.app (LSUIElement = true) inside Contents/Helpers/HeliumOpener.app
OPENER_APP="$ARCHIVE_CONTENTS/Helpers/HeliumOpener.app"
mkdir -p "$OPENER_APP/Contents/MacOS"
swiftc -O "$WORKSPACE_DIR/Sources/HeliumOpener/main.swift" -o "$OPENER_APP/Contents/MacOS/HeliumOpener"
cat > "$OPENER_APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>HeliumOpener</string>
    <key>CFBundleExecutable</key>
    <string>HeliumOpener</string>
    <key>CFBundleIdentifier</key>
    <string>com.cogify.helium.opener</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>HeliumOpener</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_BUILD}</string>
    <key>LSBackgroundOnly</key>
    <false/>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Helium Cloud File</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.item</string>
                <string>public.data</string>
                <string>public.content</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

# Generate dSYM bundle for App Store Connect crash symbolication
dsymutil "$ARCHIVE_CONTENTS/MacOS/Helium" -o "$ARCHIVE_DSYMS/${APP_NAME}.app.dSYM" 2>/dev/null || true

# Copy Resources (Credentials, Privacy Manifest, Asset Catalog, Icons, Help Book)
if [[ -f "$WORKSPACE_DIR/GoogleService-Info.plist" ]]; then
    cp "$WORKSPACE_DIR/GoogleService-Info.plist" "$ARCHIVE_CONTENTS/Resources/GoogleService-Info.plist"
fi
if [[ -f "$WORKSPACE_DIR/google-services.json" ]]; then
    cp "$WORKSPACE_DIR/google-services.json" "$ARCHIVE_CONTENTS/Resources/google-services.json"
fi
if [[ -f "$WORKSPACE_DIR/Resources/PrivacyInfo.xcprivacy" ]]; then
    cp "$WORKSPACE_DIR/Resources/PrivacyInfo.xcprivacy" "$ARCHIVE_CONTENTS/Resources/PrivacyInfo.xcprivacy"
fi
if [[ -f "$WORKSPACE_DIR/Resources/Assets.car" ]]; then
    cp "$WORKSPACE_DIR/Resources/Assets.car" "$ARCHIVE_CONTENTS/Resources/Assets.car"
fi
for ICON_FILE in "Orbit.icns" "Helium.icns" "AppIcon.icns" "HeliumIcon.png" "HeliumMascot.png" "MenuBarSmile.png"; do
    if [[ -f "$WORKSPACE_DIR/Resources/$ICON_FILE" ]]; then
        cp "$WORKSPACE_DIR/Resources/$ICON_FILE" "$ARCHIVE_CONTENTS/Resources/$ICON_FILE"
    fi
done
if [[ -d "$WORKSPACE_DIR/Resources/Helium.help" ]]; then
    cp -R "$WORKSPACE_DIR/Resources/Helium.help" "$ARCHIVE_CONTENTS/Resources/Helium.help"
fi

# App Store compliant Info.plist
cat > "$ARCHIVE_CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleHelpBookFolder</key>
    <string>Helium.help</string>
    <key>CFBundleHelpBookName</key>
    <string>Helium Help</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_BUILD}</string>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.4</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Helium — Made with ❤️ by cogify.me (connect@cogify.me)</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.cogify.helium.oauth</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>helium</string>
                <string>${HELIUM_REVERSED_CLIENT_ID:-com.googleusercontent.apps.YOUR_GOOGLE_CLIENT_ID}</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

# Write Xcode Archive metadata Info.plist so Xcode Organizer recognizes the .xcarchive
CREATION_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
cat > "$ARCHIVE_PATH/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>ApplicationProperties</key>
    <dict>
        <key>ApplicationPath</key>
        <string>Applications/${APP_NAME}.app</string>
        <key>CFBundleIdentifier</key>
        <string>${BUNDLE_ID}</string>
        <key>CFBundleShortVersionString</key>
        <string>${APP_VERSION}</string>
        <key>CFBundleVersion</key>
        <string>${APP_BUILD}</string>
        <key>IconPaths</key>
        <array>
            <string>Applications/${APP_NAME}.app/Contents/Resources/AppIcon.icns</string>
            <string>Applications/${APP_NAME}.app/Contents/Resources/Helium.icns</string>
            <string>Applications/${APP_NAME}.app/Contents/Resources/Orbit.icns</string>
        </array>
    </dict>
    <key>ArchiveVersion</key>
    <integer>2</integer>
    <key>CreationDate</key>
    <date>${CREATION_DATE}</date>
    <key>Name</key>
    <string>${APP_NAME}</string>
    <key>SchemeName</key>
    <string>${APP_NAME}</string>
</dict>
</plist>
EOF

echo "==> [3/5] Signing Archive with Mac App Store entitlements (Config/Helium-AppStore.entitlements)..."
SIGN_IDENTITY="${APPLE_SIGN_IDENTITY:--}"
codesign --force --deep --options runtime \
    --entitlements "$WORKSPACE_DIR/Config/Helium-AppStore.entitlements" \
    --sign "$SIGN_IDENTITY" \
    "$ARCHIVE_APP"

# Also prepare Direct Distribution (Developer ID / Apple Notarization) .xcarchive with Hardened Runtime
rm -rf "$DIRECT_ARCHIVE_PATH"
cp -R "$ARCHIVE_PATH" "$DIRECT_ARCHIVE_PATH"
codesign --force --deep --options runtime \
    --entitlements "$WORKSPACE_DIR/Config/Helium-Direct.entitlements" \
    --sign "$SIGN_IDENTITY" \
    "$DIRECT_ARCHIVE_PATH/Products/Applications/${APP_NAME}.app"

echo "==> [4/5] Building Mac App Store Installer Package (.pkg): $PKG_PATH"
productbuild --component "$ARCHIVE_APP" /Applications "$PKG_PATH" >/dev/null 2>&1 || true

echo "==> [5/5] Building Direct Distribution Disk Image (.dmg): $DMG_PATH"
DMG_STAGING="$WORKSPACE_DIR/build/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$DIRECT_ARCHIVE_PATH/Products/Applications/${APP_NAME}.app" "$DMG_STAGING/${APP_NAME}.app"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "${APP_NAME} ${APP_VERSION}" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_PATH" >/dev/null 2>&1 || true
rm -rf "$DMG_STAGING"

echo ""
echo "=================================================================="
echo "  Helium v${APP_VERSION} (Build ${APP_BUILD}) Archives Ready!"
echo "=================================================================="
echo "  • Xcode Project             : $WORKSPACE_DIR/Helium.xcodeproj"
echo "  • Direct Dist Archive       : $DIRECT_ARCHIVE_PATH"
echo "  • App Store Archive         : $ARCHIVE_PATH"
echo "  • App Store Package (.pkg)  : $PKG_PATH"
echo "  • Direct Dist DMG (.dmg)    : $DMG_PATH"
echo "=================================================================="
