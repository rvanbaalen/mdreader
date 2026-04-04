#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Generating app icons..."

# Compile SVG renderer if needed
if [ ! -f svg2png ] || [ svg2png.swift -nt svg2png ]; then
    echo "  Compiling svg2png..."
    swiftc -O svg2png.swift -o svg2png
fi

# --- Generate .icns from dark variant (default icon) ---
echo "  Rendering dark icon (1024x1024)..."
./svg2png icon-dark.svg icon-dark-1024.png 1024

echo "  Creating iconset..."
rm -rf AppIcon.iconset
mkdir AppIcon.iconset

SIZES="16 32 64 128 256 512 1024"
for size in $SIZES; do
    sips -z "$size" "$size" icon-dark-1024.png --out "AppIcon.iconset/icon_${size}x${size}.png" >/dev/null 2>&1
done

# Map to Apple's iconset naming convention (10 files: 5 sizes x 2 scales)
cd AppIcon.iconset
mv icon_32x32.png   icon_16x16@2x.png   # 16x16 @2x = 32px
mv icon_64x64.png   icon_32x32@2x.png   # 32x32 @2x = 64px
mv icon_256x256.png tmp_256.png
cp tmp_256.png      icon_128x128@2x.png  # 128x128 @2x = 256px
mv tmp_256.png      icon_256x256.png     # 256x256 @1x = 256px
mv icon_512x512.png tmp_512.png
cp tmp_512.png      icon_256x256@2x.png  # 256x256 @2x = 512px
mv tmp_512.png      icon_512x512.png     # 512x512 @1x = 512px
mv icon_1024x1024.png icon_512x512@2x.png # 512x512 @2x = 1024px

# Generate 32x32 @1x (sips from 16x16@2x which is 32px)
cp icon_16x16@2x.png icon_32x32.png
cd ..

echo "  Building icon.icns..."
iconutil --convert icns AppIcon.iconset -o icon.icns

# Reuse the same iconset for doc.icns (document type icon for .md files)
echo "  Building doc.icns..."
iconutil --convert icns AppIcon.iconset -o doc.icns
rm -rf AppIcon.iconset

# --- Generate Asset Catalog with dark/light variants ---
echo "  Rendering light icon (1024x1024)..."
./svg2png icon-light.svg icon-light-1024.png 1024

APPICONSET="Assets.xcassets/AppIcon.appiconset"
rm -rf Assets.xcassets
mkdir -p "$APPICONSET"

# Generate all sizes for both variants
ICON_SIZES=(
    "16:1x:16"
    "16:2x:32"
    "32:1x:32"
    "32:2x:64"
    "128:1x:128"
    "128:2x:256"
    "256:1x:256"
    "256:2x:512"
    "512:1x:512"
    "512:2x:1024"
)

for entry in "${ICON_SIZES[@]}"; do
    IFS=':' read -r pt scale px <<< "$entry"

    # Dark variant
    DARK_NAME="icon_${pt}x${pt}@${scale}_dark.png"
    sips -z "$px" "$px" icon-dark-1024.png --out "$APPICONSET/$DARK_NAME" >/dev/null 2>&1

    # Light variant
    LIGHT_NAME="icon_${pt}x${pt}@${scale}_light.png"
    sips -z "$px" "$px" icon-light-1024.png --out "$APPICONSET/$LIGHT_NAME" >/dev/null 2>&1
done

# Generate Contents.json
cat > "$APPICONSET/Contents.json" << 'JSONEOF'
{
  "images": [
    { "size": "16x16",   "idiom": "mac", "filename": "icon_16x16@1x_dark.png",  "scale": "1x" },
    { "size": "16x16",   "idiom": "mac", "filename": "icon_16x16@2x_dark.png",  "scale": "2x" },
    { "size": "32x32",   "idiom": "mac", "filename": "icon_32x32@1x_dark.png",  "scale": "1x" },
    { "size": "32x32",   "idiom": "mac", "filename": "icon_32x32@2x_dark.png",  "scale": "2x" },
    { "size": "128x128", "idiom": "mac", "filename": "icon_128x128@1x_dark.png","scale": "1x" },
    { "size": "128x128", "idiom": "mac", "filename": "icon_128x128@2x_dark.png","scale": "2x" },
    { "size": "256x256", "idiom": "mac", "filename": "icon_256x256@1x_dark.png","scale": "1x" },
    { "size": "256x256", "idiom": "mac", "filename": "icon_256x256@2x_dark.png","scale": "2x" },
    { "size": "512x512", "idiom": "mac", "filename": "icon_512x512@1x_dark.png","scale": "1x" },
    { "size": "512x512", "idiom": "mac", "filename": "icon_512x512@2x_dark.png","scale": "2x" },
    {
      "size": "16x16",   "idiom": "mac", "filename": "icon_16x16@1x_light.png", "scale": "1x",
      "appearances": [{ "appearance": "luminosity", "value": "light" }]
    },
    {
      "size": "16x16",   "idiom": "mac", "filename": "icon_16x16@2x_light.png", "scale": "2x",
      "appearances": [{ "appearance": "luminosity", "value": "light" }]
    },
    {
      "size": "32x32",   "idiom": "mac", "filename": "icon_32x32@1x_light.png", "scale": "1x",
      "appearances": [{ "appearance": "luminosity", "value": "light" }]
    },
    {
      "size": "32x32",   "idiom": "mac", "filename": "icon_32x32@2x_light.png", "scale": "2x",
      "appearances": [{ "appearance": "luminosity", "value": "light" }]
    },
    {
      "size": "128x128", "idiom": "mac", "filename": "icon_128x128@1x_light.png","scale": "1x",
      "appearances": [{ "appearance": "luminosity", "value": "light" }]
    },
    {
      "size": "128x128", "idiom": "mac", "filename": "icon_128x128@2x_light.png","scale": "2x",
      "appearances": [{ "appearance": "luminosity", "value": "light" }]
    },
    {
      "size": "256x256", "idiom": "mac", "filename": "icon_256x256@1x_light.png","scale": "1x",
      "appearances": [{ "appearance": "luminosity", "value": "light" }]
    },
    {
      "size": "256x256", "idiom": "mac", "filename": "icon_256x256@2x_light.png","scale": "2x",
      "appearances": [{ "appearance": "luminosity", "value": "light" }]
    },
    {
      "size": "512x512", "idiom": "mac", "filename": "icon_512x512@1x_light.png","scale": "1x",
      "appearances": [{ "appearance": "luminosity", "value": "light" }]
    },
    {
      "size": "512x512", "idiom": "mac", "filename": "icon_512x512@2x_light.png","scale": "2x",
      "appearances": [{ "appearance": "luminosity", "value": "light" }]
    }
  ],
  "info": { "version": 1, "author": "generate-icons" }
}
JSONEOF

# Compile Asset Catalog
echo "  Compiling Asset Catalog..."
mkdir -p output
xcrun actool Assets.xcassets \
    --compile output \
    --platform macosx \
    --minimum-deployment-target 14.0 \
    --app-icon AppIcon \
    --output-partial-info-plist output/AssetCatalog-Info.plist \
    >/dev/null 2>&1

if [ -f output/Assets.car ]; then
    mv output/Assets.car Assets.car
    echo "  Created Assets.car"
else
    echo "  Warning: Assets.car not created, falling back to .icns only"
fi
rm -rf output

# Clean up intermediate PNGs
rm -f icon-dark-1024.png icon-light-1024.png

echo "Done! Generated:"
echo "  icon.icns     - legacy app icon (dark variant)"
echo "  doc.icns      - document type icon for .md files"
echo "  Assets.car    - asset catalog with dark + light mode"
ls -la icon.icns doc.icns Assets.car 2>/dev/null | awk '{print "  " $NF " (" $5 " bytes)"}'
