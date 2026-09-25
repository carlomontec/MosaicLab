#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Building MosaicLabApp in release mode..."
cd "$PACKAGE_DIR"
swift build -c release

APP_NAME="MosaicLab.app"
APP_DIR="$PACKAGE_DIR/build/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Preparing $APP_NAME bundle structure..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
echo "==> Copying binary..."
cp "$PACKAGE_DIR/.build/release/MosaicLabApp" "$MACOS_DIR/MosaicLab"
chmod +x "$MACOS_DIR/MosaicLab"

# Copy Icon if available
ICON_SRC="$PACKAGE_DIR/docs/AppIcon.icns"
if [ -f "$ICON_SRC" ]; then
    echo "==> Copying Application Icon..."
    cp "$ICON_SRC" "$RESOURCES_DIR/AppIcon.icns"
fi

# Write Info.plist
echo "==> Generating Info.plist..."
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MosaicLab</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.carlomontec.mosaiclab</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MosaicLab</string>
    <key>CFBundleDisplayName</key>
    <string>MosaicLab</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>MosaicLab needs access to your Photos library to use your pictures as mosaic tiles.</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>MosaicLab Project</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Owner</string>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>mosaiclab</string>
            </array>
            <key>CFBundleTypeIconFile</key>
            <string>AppIcon</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>com.carlomontec.mosaiclab.project</string>
            </array>
        </dict>
    </array>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.carlomontec.mosaiclab.project</string>
            <key>UTTypeDescription</key>
            <string>MosaicLab Project</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.data</string>
                <string>public.content</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>mosaiclab</string>
                </array>
            </dict>
        </dict>
    </array>
</dict>
</plist>
EOF

# Ad-hoc code signing for local execution without gatekeeper hurdles
echo "==> Signing application bundle (ad-hoc)..."
codesign --force --deep --sign - "$APP_DIR"

# Copy to package root for convenience
rm -rf "$PACKAGE_DIR/MosaicLab.app"
cp -R "$APP_DIR" "$PACKAGE_DIR/MosaicLab.app"

echo "==> Successfully created $APP_NAME!"
echo "    Location: $PACKAGE_DIR/MosaicLab.app"
echo "    You can launch it via: open \"$PACKAGE_DIR/MosaicLab.app\""
