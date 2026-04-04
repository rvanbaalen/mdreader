#!/bin/bash
set -e

APP_NAME="mdreader"
BUNDLE="$APP_NAME.app"
CONFIG="${1:-release}"

# Version — updated automatically by release-please
VERSION="1.5.0" # x-release-please-version
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo "0")

echo "Building $APP_NAME $VERSION ($COMMIT) [$CONFIG]..."

# Build web UI
if [ -d "web" ] && [ -f "web/package.json" ]; then
    echo "Building web UI..."
    cd web
    npm ci --silent 2>/dev/null || npm install --silent
    npx vite build 2>&1 | tail -3
    cd ..
fi

swift build -c "$CONFIG" --disable-sandbox 2>&1 | tail -3

BUILD_DIR=$(swift build -c "$CONFIG" --show-bin-path 2>/dev/null)

echo "Assembling $BUNDLE..."
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$BUNDLE/Contents/MacOS/$APP_NAME"

# Copy resource bundle (contains CSS, JS, fonts)
if [ -d "$BUILD_DIR/mdreader_mdreader.bundle" ]; then
    cp -R "$BUILD_DIR/mdreader_mdreader.bundle" "$BUNDLE/Contents/Resources/mdreader_mdreader.bundle"
fi

# Write build info into the resource bundle
echo "$COMMIT" > "$BUNDLE/Contents/Resources/mdreader_mdreader.bundle/Resources/build-info.txt"

# Copy Vite dist into the resource bundle
if [ -d "web/dist" ]; then
    cp -R web/dist "$BUNDLE/Contents/Resources/mdreader_mdreader.bundle/Resources/dist"
fi

# Copy CHANGELOG for post-update display
if [ -f "CHANGELOG.md" ]; then
    cp CHANGELOG.md "$BUNDLE/Contents/Resources/mdreader_mdreader.bundle/Resources/CHANGELOG.md"
fi

# Copy icons
if [ -f "build/Assets.car" ]; then
    cp "build/Assets.car" "$BUNDLE/Contents/Resources/Assets.car"
fi
if [ -f "build/icon.icns" ]; then
    cp "build/icon.icns" "$BUNDLE/Contents/Resources/AppIcon.icns"
fi
if [ -f "build/doc.icns" ]; then
    cp "build/doc.icns" "$BUNDLE/Contents/Resources/DocIcon.icns"
fi

# Write Info.plist with real version
cat > "$BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>mdreader</string>
    <key>CFBundleDisplayName</key>
    <string>mdreader</string>
    <key>CFBundleIdentifier</key>
    <string>com.rvanbaalen.mdreader</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>mdreader</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>md</string>
                <string>markdown</string>
                <string>mdown</string>
                <string>mkd</string>
            </array>
            <key>CFBundleTypeName</key>
            <string>Markdown Document</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>CFBundleTypeIconFile</key>
            <string>DocIcon</string>
            <key>LSHandlerRank</key>
            <string>Default</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>net.daringfireball.markdown</string>
                <string>public.text</string>
            </array>
        </dict>
    </array>
    <key>UTImportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>net.daringfireball.markdown</string>
            <key>UTTypeDescription</key>
            <string>Markdown Document</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.text</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>md</string>
                    <string>markdown</string>
                    <string>mdown</string>
                    <string>mkd</string>
                </array>
            </dict>
        </dict>
    </array>
</dict>
</plist>
PLIST

# --- Quick Look Preview Extension ---
echo "Building Quick Look extension..."
QL_APPEX="QuickLookPreview.appex"
QL_SRC="Sources/mdreader-quicklook/PreviewProvider.swift"
QL_MODULE="QuickLookPreview"
QL_RESOURCES="Sources/mdreader-quicklook/Resources"
QL_SHARED_RESOURCES="Sources/mdreader/Resources"

# Clean stale binary
rm -f "$QL_MODULE"

# Compile extension
swiftc \
    -sdk "$(xcrun --show-sdk-path)" \
    -target "$(uname -m)-apple-macos15.0" \
    -application-extension \
    -parse-as-library \
    -framework AppKit \
    -framework Quartz \
    -framework CoreText \
    -Xlinker -e -Xlinker _NSExtensionMain \
    -module-name "$QL_MODULE" \
    -o "$QL_MODULE" \
    "$QL_SRC"

# Assemble .appex bundle
rm -rf "$QL_APPEX"
mkdir -p "$QL_APPEX/Contents/MacOS"
mkdir -p "$QL_APPEX/Contents/Resources/Fonts"
cp "$QL_MODULE" "$QL_APPEX/Contents/MacOS/$QL_MODULE"
rm "$QL_MODULE"

# Copy resources into .appex
cp "$QL_SHARED_RESOURCES/marked.min.js" "$QL_APPEX/Contents/Resources/"
cp "$QL_RESOURCES/quicklook.css" "$QL_APPEX/Contents/Resources/"
cp -R "$QL_SHARED_RESOURCES/Fonts/." "$QL_APPEX/Contents/Resources/Fonts/"

# Generate Info.plist for the extension
cat > "$QL_APPEX/Contents/Info.plist" << QLPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>QuickLookPreview</string>
    <key>CFBundleDisplayName</key>
    <string>mdreader Quick Look</string>
    <key>CFBundleIdentifier</key>
    <string>nl.robinvanbaalen.mdreader.quicklook</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>QuickLookPreview</string>
    <key>CFBundlePackageType</key>
    <string>XPC!</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.quicklook.preview</string>
        <key>NSExtensionPrincipalClass</key>
        <string>QuickLookPreview.PreviewViewController</string>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>QLSupportedContentTypes</key>
            <array>
                <string>net.daringfireball.markdown</string>
            </array>
            <key>QLSupportsSearchableItems</key>
            <false/>
        </dict>
    </dict>
</dict>
</plist>
QLPLIST

# Embed in app bundle
mkdir -p "$BUNDLE/Contents/PlugIns"
cp -R "$QL_APPEX" "$BUNDLE/Contents/PlugIns/$QL_APPEX"
rm -rf "$QL_APPEX"

# Code sign: inner (extension) before outer (app)
codesign --force --sign - "$BUNDLE/Contents/PlugIns/$QL_APPEX"
codesign --force --sign - "$BUNDLE"

echo "Done: $BUNDLE ($VERSION build $BUILD_NUMBER, $COMMIT)"
echo "Run: open $APP_NAME.app"
