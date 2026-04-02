#!/bin/bash
set -e

APP_NAME="mdreader"
BUNDLE="$APP_NAME.app"
CONFIG="${1:-release}"

# Get version from git
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")
VERSION="${VERSION#v}" # strip leading v
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

# Copy icons
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

# Ad-hoc codesign
codesign --force --sign - --deep "$BUNDLE"

echo "Done: $BUNDLE ($VERSION build $BUILD_NUMBER, $COMMIT)"
echo "Run: open $APP_NAME.app"
