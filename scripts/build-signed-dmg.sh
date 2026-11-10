#!/bin/zsh
set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

APP_NAME="Helium"
BUNDLE_ID="com.cogify.helium"
APP_VERSION="0.0.2"
APP_BUILD="2"

# Detect Apple Developer signing identity automatically (or fall back to APPLE_SIGN_IDENTITY / ad-hoc)
DETECTED_IDENTITY="$(security find-identity -v -p codesigning | grep -E 'Developer ID Application|Apple Development|Apple Distribution' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
SIGN_IDENTITY="${APPLE_SIGN_IDENTITY:-${DETECTED_IDENTITY:--}}"

echo "==> [1/5] Building Release binaries for ${APP_NAME} v${APP_VERSION} (Build ${APP_BUILD})..."
cd "$WORKSPACE_DIR"
swift build -c release

RELEASE_BIN_DIR="$(swift build -c release --show-bin-path)"
STAGE_ROOT="/tmp/helium-dmg-stage-$$"
APP_BUNDLE="$STAGE_ROOT/${APP_NAME}.app"
CONTENTS="$APP_BUNDLE/Contents"

rm -rf "$STAGE_ROOT"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"
mkdir -p "$CONTENTS/Helpers"
mkdir -p "$CONTENTS/Library/LaunchDaemons"

# Copy Release binaries
cp "$RELEASE_BIN_DIR/Helium" "$CONTENTS/MacOS/Helium"
cp "$RELEASE_BIN_DIR/OrbitMountHelper" "$CONTENTS/MacOS/OrbitMountHelper"
cp "$RELEASE_BIN_DIR/OrbitFS" "$CONTENTS/Helpers/OrbitFS"
cp "$RELEASE_BIN_DIR/OrbitFinder" "$CONTENTS/Helpers/OrbitFinder"
chmod +x "$CONTENTS/MacOS/Helium" "$CONTENTS/MacOS/OrbitMountHelper" "$CONTENTS/Helpers/OrbitFS" "$CONTENTS/Helpers/OrbitFinder"

# Build invisible HeliumOpener.app helper
OPENER_APP="$CONTENTS/Helpers/HeliumOpener.app"
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

# Copy OAuth client configuration, PrivacyInfo, Assets.car, Icons, and Help Book
if [[ -f "$WORKSPACE_DIR/GoogleService-Info.plist" ]]; then
    cp "$WORKSPACE_DIR/GoogleService-Info.plist" "$CONTENTS/Resources/GoogleService-Info.plist"
elif [[ -f "$WORKSPACE_DIR/.local-credentials/GoogleService-Info.plist" ]]; then
    cp "$WORKSPACE_DIR/.local-credentials/GoogleService-Info.plist" "$CONTENTS/Resources/GoogleService-Info.plist"
fi
if [[ -f "$WORKSPACE_DIR/google-services.json" ]]; then
    cp "$WORKSPACE_DIR/google-services.json" "$CONTENTS/Resources/google-services.json"
elif [[ -f "$WORKSPACE_DIR/.local-credentials/google-services.json" ]]; then
    cp "$WORKSPACE_DIR/.local-credentials/google-services.json" "$CONTENTS/Resources/google-services.json"
fi
if [[ -f "$CONTENTS/Resources/GoogleService-Info.plist" ]]; then
    mkdir -p "$HOME/Library/Application Support/Helium"
    cp "$CONTENTS/Resources/GoogleService-Info.plist" "$HOME/Library/Application Support/Helium/GoogleService-Info.plist" 2>/dev/null || true
    if [[ -z "${HELIUM_REVERSED_CLIENT_ID:-}" ]]; then
        HELIUM_REVERSED_CLIENT_ID="$(/usr/libexec/PlistBuddy -c 'Print :REVERSED_CLIENT_ID' "$CONTENTS/Resources/GoogleService-Info.plist" 2>/dev/null || true)"
    fi
fi
if [[ -f "$CONTENTS/Resources/google-services.json" ]]; then
    mkdir -p "$HOME/Library/Application Support/Helium"
    cp "$CONTENTS/Resources/google-services.json" "$HOME/Library/Application Support/Helium/google-services.json" 2>/dev/null || true
fi

if [[ -f "$WORKSPACE_DIR/Resources/PrivacyInfo.xcprivacy" ]]; then
    cp "$WORKSPACE_DIR/Resources/PrivacyInfo.xcprivacy" "$CONTENTS/Resources/PrivacyInfo.xcprivacy"
fi
if [[ -f "$WORKSPACE_DIR/Resources/Assets.car" ]]; then
    cp "$WORKSPACE_DIR/Resources/Assets.car" "$CONTENTS/Resources/Assets.car"
fi
for ICON_FILE in "Orbit.icns" "Helium.icns" "AppIcon.icns" "HeliumIcon.png" "HeliumMascot.png" "MenuBarSmile.png"; do
    if [[ -f "$WORKSPACE_DIR/Resources/$ICON_FILE" ]]; then
        cp "$WORKSPACE_DIR/Resources/$ICON_FILE" "$CONTENTS/Resources/$ICON_FILE"
    fi
done
if [[ -d "$WORKSPACE_DIR/Resources/Helium.help" ]]; then
    cp -R "$WORKSPACE_DIR/Resources/Helium.help" "$CONTENTS/Resources/Helium.help"
fi

# Main App Info.plist
cat > "$CONTENTS/Info.plist" <<EOF
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

cat > "$CONTENTS/Library/LaunchDaemons/com.cogify.helium.MountHelper.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.cogify.helium.MountHelper</string>
    <key>BundleProgram</key>
    <string>Contents/MacOS/OrbitMountHelper</string>
    <key>MachServices</key>
    <dict>
        <key>com.cogify.helium.MountHelper</key>
        <true/>
    </dict>
</dict>
</plist>
EOF

echo "==> [2/5] Signing nested helpers and Helium.app with identity: $SIGN_IDENTITY"
xattr -cr "$APP_BUNDLE"
for HELPER_BIN in "$CONTENTS/Helpers/OrbitFS" "$CONTENTS/Helpers/OrbitFinder" "$CONTENTS/MacOS/OrbitMountHelper" "$OPENER_APP"; do
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$HELPER_BIN"
done

codesign --force --deep --options runtime \
    --entitlements "$WORKSPACE_DIR/Config/Helium-Direct.entitlements" \
    --sign "$SIGN_IDENTITY" \
    "$APP_BUNDLE"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

# Copy signed Release app to build/Helium.app and /Applications/Helium.app
mkdir -p "$WORKSPACE_DIR/build" "$WORKSPACE_DIR/dist"
rm -rf "$WORKSPACE_DIR/build/Helium.app" "/Applications/Helium.app"
cp -R "$APP_BUNDLE" "$WORKSPACE_DIR/build/Helium.app"
cp -R "$APP_BUNDLE" "/Applications/Helium.app"

echo "==> [3/5] Preserving custom Drag-and-Drop DMG layout (.background & .DS_Store)..."
ln -s /Applications "$STAGE_ROOT/Applications"

if [[ -f "$WORKSPACE_DIR/dist/Helium-macOS-Installer.dmg" ]]; then
    OLD_MNT="/tmp/helium-prev-dmg-$$"
    if hdiutil attach "$WORKSPACE_DIR/dist/Helium-macOS-Installer.dmg" -mountpoint "$OLD_MNT" -nobrowse -readonly >/dev/null 2>&1; then
        [[ -d "$OLD_MNT/.background" ]] && cp -R "$OLD_MNT/.background" "$STAGE_ROOT/.background"
        [[ -f "$OLD_MNT/.background.tiff" ]] && cp "$OLD_MNT/.background.tiff" "$STAGE_ROOT/.background.tiff"
        [[ -f "$OLD_MNT/.DS_Store" ]] && cp "$OLD_MNT/.DS_Store" "$STAGE_ROOT/.DS_Store"
        hdiutil detach "$OLD_MNT" -force >/dev/null 2>&1 || true
    fi
elif [[ -f "$WORKSPACE_DIR/dist/marketing-images/00-dmg-background.png" ]]; then
    mkdir -p "$STAGE_ROOT/.background"
    cp "$WORKSPACE_DIR/dist/marketing-images/00-dmg-background.png" "$STAGE_ROOT/.background/background.png"
fi

echo "==> [4/5] Building compressed UDZO Disk Image (.dmg)..."
OUT_DMG_DIST="$WORKSPACE_DIR/dist/Helium-macOS-Installer.dmg"
OUT_DMG_BUILD="$WORKSPACE_DIR/build/Helium-${APP_VERSION}.dmg"
OUT_DMG_ROOT="$WORKSPACE_DIR/Helium.dmg"

rm -f "$OUT_DMG_DIST" "$OUT_DMG_BUILD" "$OUT_DMG_ROOT"
hdiutil create -volname "Helium" \
    -srcfolder "$STAGE_ROOT" \
    -ov -format UDZO \
    "$OUT_DMG_DIST" >/dev/null

echo "==> [5/5] Code-signing DMG container with identity: $SIGN_IDENTITY"
codesign --force --sign "$SIGN_IDENTITY" "$OUT_DMG_DIST"
codesign --verify --verbose=2 "$OUT_DMG_DIST"

cp "$OUT_DMG_DIST" "$OUT_DMG_BUILD"
cp "$OUT_DMG_DIST" "$OUT_DMG_ROOT"
rm -rf "$STAGE_ROOT"

echo ""
echo "=================================================================="
echo "  Apple Developer Signed DMG Ready for Web Update!"
echo "=================================================================="
echo "  • Signing Identity : $SIGN_IDENTITY"
echo "  • Version          : Helium v${APP_VERSION} (Build ${APP_BUILD})"
echo "  • Web Update DMG   : $OUT_DMG_DIST"
echo "  • Root Copy        : $OUT_DMG_ROOT"
echo "  • Build Copy       : $OUT_DMG_BUILD"
echo "=================================================================="
