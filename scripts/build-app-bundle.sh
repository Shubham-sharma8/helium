#!/bin/zsh
set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

APP_VERSION="0.0.3"
APP_BUILD="3"
DETECTED_IDENTITY="$(security find-identity -v -p codesigning | grep -E 'Developer ID Application|Apple Development|Apple Distribution' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
SIGN_IDENTITY="${APPLE_SIGN_IDENTITY:-${DETECTED_IDENTITY:--}}"

echo "==> Building all Helium v${APP_VERSION} (Build ${APP_BUILD}) targets (HeliumApp, OrbitFS, OrbitFinder, OrbitMountHelper)..."
cd "$WORKSPACE_DIR"
swift build

# Unregister any legacy FinderSync / FSKit appex plugins that caused macOS pkd/pluginkit to repeatedly prompt for "access data from other apps"
killall OrbitFinder 2>/dev/null || true
killall OrbitFS 2>/dev/null || true
if [[ -d "/Applications/Helium.app/Contents/PlugIns/OrbitFinder.appex" ]]; then
    pluginkit -r "/Applications/Helium.app/Contents/PlugIns/OrbitFinder.appex" 2>/dev/null || true
fi
if [[ -d "/Applications/Helium.app/Contents/Extensions/OrbitFS.appex" ]]; then
    pluginkit -r "/Applications/Helium.app/Contents/Extensions/OrbitFS.appex" 2>/dev/null || true
fi

# One-time migration from legacy Group Container / HeliumShared into ~/Library/Application Support/Helium
# so Helium.app never accesses ~/Library/Group Containers at runtime (eliminating macOS Sequoia TCC prompts).
HELIUM_SUPPORT_DIR="$HOME/Library/Application Support/Helium"
mkdir -p "$HELIUM_SUPPORT_DIR"
for LEGACY_DIR in "$HOME/Library/Group Containers/group.com.cogify.helium" "$HOME/Library/Application Support/HeliumShared"; do
    if [[ -d "$LEGACY_DIR" ]]; then
        for ITEM in ".helium-secrets.json" "google-accounts.json" "pool-manifests.json" "keep-list.json"; do
            if [[ -e "$LEGACY_DIR/$ITEM" && ! -e "$HELIUM_SUPPORT_DIR/$ITEM" ]]; then
                cp -R "$LEGACY_DIR/$ITEM" "$HELIUM_SUPPORT_DIR/$ITEM" 2>/dev/null || true
            fi
        done
    fi
done

# Unmount any legacy 127.0.0.1 NFS mount so Finder Sidebar shows "Helium" (never "127.0.0.1")
if mount | grep "/Volumes/Helium" | grep -q "nfs"; then
    umount -f "/Volumes/Helium" 2>/dev/null || true
fi
rm -rf "$HELIUM_SUPPORT_DIR"/*.sparsebundle(N) "$HOME/Library/Group Containers/group.com.cogify.helium"/*.sparsebundle(N) 2>/dev/null || true

BIN_DIR="$(swift build --show-bin-path)"
APP_BUNDLE="$WORKSPACE_DIR/build/Helium.app"
LEGACY_APP_BUNDLE="$WORKSPACE_DIR/build/Helium.app"
CONTENTS="$APP_BUNDLE/Contents"

rm -rf "$APP_BUNDLE" "$LEGACY_APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"
mkdir -p "$CONTENTS/Helpers"
mkdir -p "$CONTENTS/Library/LaunchDaemons"

# Copy binaries (keep helper Daemons/Tools in MacOS & Helpers rather than PlugIns so pkd does not respawn ad-hoc appex bundles)
cp "$BIN_DIR/Helium" "$CONTENTS/MacOS/Helium"
cp "$BIN_DIR/OrbitMountHelper" "$CONTENTS/MacOS/OrbitMountHelper"
cp "$BIN_DIR/OrbitFS" "$CONTENTS/Helpers/OrbitFS"
cp "$BIN_DIR/OrbitFinder" "$CONTENTS/Helpers/OrbitFinder"

# Build invisible HeliumOpener.app (LSUIElement = true) inside Contents/Helpers/HeliumOpener.app
# so double-clicking a 0-B-on-disk sparse file in /Volumes/Helium opens it in Preview / QuickTime / DiskImageMounter without opening the Helium app window!
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

# Copy Firebase / Google Cloud credentials, Privacy Manifest, and Helium Visual Assets + Icons + Help Book
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
    cp "$CONTENTS/Resources/GoogleService-Info.plist" "$HELIUM_SUPPORT_DIR/GoogleService-Info.plist" 2>/dev/null || true
    if [[ -z "${HELIUM_REVERSED_CLIENT_ID:-}" ]]; then
        HELIUM_REVERSED_CLIENT_ID="$(/usr/libexec/PlistBuddy -c 'Print :REVERSED_CLIENT_ID' "$CONTENTS/Resources/GoogleService-Info.plist" 2>/dev/null || true)"
    fi
fi
if [[ -f "$CONTENTS/Resources/google-services.json" ]]; then
    cp "$CONTENTS/Resources/google-services.json" "$HELIUM_SUPPORT_DIR/google-services.json" 2>/dev/null || true
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

# Main App Info.plist (App Store & Direct Distribution compliant)
cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Helium</string>
    <key>CFBundleExecutable</key>
    <string>Helium</string>
    <key>CFBundleHelpBookFolder</key>
    <string>Helium.help</string>
    <key>CFBundleHelpBookName</key>
    <string>Helium Help</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.cogify.helium</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Helium</string>
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

# LaunchDaemon plist for OrbitMountHelper
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

if [[ -f "$WORKSPACE_DIR/Config/Helium-Direct.entitlements" ]]; then
    codesign --force --deep --entitlements "$WORKSPACE_DIR/Config/Helium-Direct.entitlements" --sign "$SIGN_IDENTITY" "$APP_BUNDLE" >/dev/null 2>&1 || true
else
    codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE" >/dev/null 2>&1 || true
fi

rm -rf "/Applications/Helium.app" "/Applications/Helium.app" 2>/dev/null || true
cp -R "$APP_BUNDLE" "/Applications/Helium.app" 2>/dev/null || true
xattr -cr "$APP_BUNDLE" "/Applications/Helium.app" "$HOME/Helium" 2>/dev/null || true
touch "/Applications/Helium.app" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/Helium.app" >/dev/null 2>&1 || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/Helium.app/Contents/Helpers/HeliumOpener.app" >/dev/null 2>&1 || true
echo "==> Packaged Helium.app v${APP_VERSION} (Build ${APP_BUILD}) at: $APP_BUNDLE (and installed to /Applications/Helium.app)"
