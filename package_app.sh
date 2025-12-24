#!/bin/bash

# Configuration
APP_NAME="PlayIPTV"
ICON_SOURCE="app_icon.png"
BUILD_DIR=".build/release"
OUTPUT_DIR="."

# Ensure we have an icon source
if [ ! -f "AppIcon.icns" ] && [ ! -f "$ICON_SOURCE" ]; then
    echo "Error: Neither AppIcon.icns nor $ICON_SOURCE found!"
    exit 1
fi

echo "🚀 Building $APP_NAME..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "Build failed."
    exit 1
fi

echo "📦 Creating $APP_NAME.app bundle..."

# Create structure
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
FRAMEWORKS="$CONTENTS/Frameworks"

mkdir -p "$MACOS"
mkdir -p "$RESOURCES"
mkdir -p "$FRAMEWORKS"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$MACOS/"

# Copy Frameworks (VLCKit)
# Find VLCKit.framework in build dir
VLCKIT_PATH=$(find .build -name "VLCKit.framework" -type d | grep "release" | head -n 1)
if [ -z "$VLCKIT_PATH" ]; then
    echo "⚠️ Warning: VLCKit.framework not found in release build. Trying to find anywhere..."
    VLCKIT_PATH=$(find .build -name "VLCKit.framework" -type d | head -n 1)
fi

if [ -n "$VLCKIT_PATH" ]; then
    echo "📦 Bundling VLCKit from $VLCKIT_PATH..."
    cp -R "$VLCKIT_PATH" "$FRAMEWORKS/"
else
    echo "❌ Error: Could not find VLCKit.framework"
    exit 1
fi

# Create Info.plist
cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "🎨 Setting up AppIcon..."

if [ -f "AppIcon.icns" ]; then
    echo "✅ Found existing AppIcon.icns, using it."
    cp "AppIcon.icns" "$RESOURCES/AppIcon.icns"
else
    echo "Generating from $ICON_SOURCE..."
    
    # Create iconset directory
    ICONSET="PlayIPTV.iconset"
    mkdir -p "$ICONSET"

    # Generate icons of various sizes using sips
    sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" &>/dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" &>/dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" &>/dev/null
    sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" &>/dev/null
    sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" &>/dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" &>/dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" &>/dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" &>/dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" &>/dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" &>/dev/null

    # Convert iconset to icns
    iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"

    # Cleanup
    rm -rf "$ICONSET"
fi

echo "🔐 Ad-hoc code signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

# Prepare Release Artifacts
RELEASE_DIR="Releases"
mkdir -p "$RELEASE_DIR"

echo "📦 Packaging for GitHub Release..."
# Clean old artifacts in release dir
rm -rf "$RELEASE_DIR/$APP_NAME.app"
rm -f "$RELEASE_DIR/$APP_NAME.zip"

# Move App Bundle to Release Folder
mv "$APP_BUNDLE" "$RELEASE_DIR/"

# Zip the bundle (Standard GitHub Release format)
echo "Compression..."
(cd "$RELEASE_DIR" && zip -r -q "$APP_NAME.zip" "$APP_NAME.app")

echo "✅ Build Complete!"
echo "📂 Artifacts Location: $(pwd)/$RELEASE_DIR"
echo "   - App Bundle: $RELEASE_DIR/$APP_NAME.app"
echo "   - Distribution Zip: $RELEASE_DIR/$APP_NAME.zip"
echo ""
echo "🚀 To Release on GitHub:"
echo "1. Go to your repo -> Releases -> Draft a new release"
echo "2. Upload '$RELEASE_DIR/$APP_NAME.zip'"
