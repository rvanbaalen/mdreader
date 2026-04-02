#!/bin/bash
set -e

APP_NAME="mdreader"
BUNDLE="$APP_NAME.app"
VERSION="1.2.2" # x-release-please-version
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo "0")

echo "Building $APP_NAME (dev)..."

# Build Swift in debug mode (faster compile)
swift build --disable-sandbox 2>&1 | tail -3
BUILD_DIR=$(swift build --show-bin-path 2>/dev/null)

echo "Assembling $BUNDLE..."
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$BUNDLE/Contents/MacOS/$APP_NAME"

if [ -d "$BUILD_DIR/mdreader_mdreader.bundle" ]; then
    cp -R "$BUILD_DIR/mdreader_mdreader.bundle" "$BUNDLE/Contents/Resources/mdreader_mdreader.bundle"
fi

echo "$COMMIT" > "$BUNDLE/Contents/Resources/mdreader_mdreader.bundle/Resources/build-info.txt"

# Copy CHANGELOG for post-update display
[ -f "CHANGELOG.md" ] && cp CHANGELOG.md "$BUNDLE/Contents/Resources/mdreader_mdreader.bundle/Resources/CHANGELOG.md"

# Copy icons
[ -f "build/icon.icns" ] && cp "build/icon.icns" "$BUNDLE/Contents/Resources/AppIcon.icns"
[ -f "build/doc.icns" ] && cp "build/doc.icns" "$BUNDLE/Contents/Resources/DocIcon.icns"

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

codesign --force --sign - --deep "$BUNDLE"

# Install web dependencies if needed
cd web
[ -d "node_modules" ] || npm install --silent

# Start Vite dev server in background
npx vite &
VITE_PID=$!
cd ..

# Wait for Vite to be ready
echo "Waiting for Vite..."
for i in $(seq 1 30); do
    if curl -s http://localhost:5173 > /dev/null 2>&1; then break; fi
    sleep 0.5
done

# Launch app pointing at Vite dev server
echo "Launching $APP_NAME (dev mode)..."
MDREADER_DEV=1 open "$BUNDLE"

# Keep Vite running, clean up on Ctrl+C
trap "kill $VITE_PID 2>/dev/null; exit 0" INT TERM
echo "Vite running at http://localhost:5173 — Ctrl+C to stop"
wait $VITE_PID
