#!/bin/bash

# Build Arguments
VERSION=$1

if [ -z "$VERSION" ]; then
    # Default to Test Build if no version specified
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    VERSION="0.0.0-test.$TIMESTAMP"
    BUILD_TYPE="test"
    echo "⚠️  No version specified. Creating TEST build: $VERSION"
else
    # Official Release
    BUILD_TYPE="release"
    echo "🚀 Creating OFFICIAL RELEASE: $VERSION"
fi

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

# Build Loop
build_for_arch() {
    ARCH=$1
    echo "========================================"
    echo "🚀 Starting build for architecture: $ARCH"
    echo "========================================"

    # output specific to arch
    BUILD_PATH=".build/${ARCH}-apple-macosx/release"
    
    echo "🔨 Compiling..."
    swift build -c release --arch "$ARCH"

    if [ $? -ne 0 ]; then
        echo "❌ Build failed for $ARCH."
        return 1
    fi

    echo "📦 Creating $APP_NAME.app bundle for $ARCH..."

    # Create structure (Standard name inside the zip)
    APP_BUNDLE="$RELEASE_DIR/${APP_NAME}.app"
    CONTENTS="$APP_BUNDLE/Contents"
    MACOS="$CONTENTS/MacOS"
    RESOURCES="$CONTENTS/Resources"
    FRAMEWORKS="$CONTENTS/Frameworks"

    rm -rf "$APP_BUNDLE"
    mkdir -p "$MACOS"
    mkdir -p "$RESOURCES"
    mkdir -p "$FRAMEWORKS"

    # Copy binary
    if [ -f "$BUILD_PATH/$APP_NAME" ]; then
        cp "$BUILD_PATH/$APP_NAME" "$MACOS/$APP_NAME" # Ensure binary name inside bundle is standard
    else
        echo "❌ Error: Binary not found at $BUILD_PATH/$APP_NAME"
        return 1
    fi

    # Copy Frameworks (VLCKit)
    # Find VLCKit.framework in specific arch build dir
    VLCKIT_PATH=$(find .build/${ARCH}-apple-macosx -name "VLCKit.framework" -type d | grep "release" | head -n 1)
    
    if [ -z "$VLCKIT_PATH" ]; then
         echo "⚠️ Warning: VLCKit.framework not found in specific path. Searching broader..."
         VLCKIT_PATH=$(find .build -name "VLCKit.framework" -type d | head -n 1)
    fi

    if [ -n "$VLCKIT_PATH" ]; then
        echo "📦 Bundling VLCKit from $VLCKIT_PATH..."
        cp -R "$VLCKIT_PATH" "$FRAMEWORKS/"
    else
        echo "❌ Error: Could not find VLCKit.framework"
        return 1
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
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
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
    # Pre-generated icon check
    if [ -f "AppIcon.icns" ]; then
         cp "AppIcon.icns" "$RESOURCES/AppIcon.icns"
    fi

    echo "🔐 Ad-hoc code signing..."
    codesign --force --deep --sign - "$APP_BUNDLE"

    # Zip
    if [ "$BUILD_TYPE" == "release" ]; then
        ZIP_NAME="${APP_NAME}_v${VERSION}_${ARCH}.zip"
    else
        # Version already contains "test" (e.g. 0.0.0-test.TIMESTAMP)
        ZIP_NAME="${APP_NAME}_${VERSION}_${ARCH}.zip"
    fi

    echo "📦 Zipping into $ZIP_NAME..."
    rm -f "$RELEASE_DIR/$ZIP_NAME"
    (cd "$RELEASE_DIR" && zip -r -q "$ZIP_NAME" "$APP_NAME.app")
    
    echo "✅ Finished $ARCH"
}

# Updates to Main Execution
# 1. Prepare output dir
RELEASE_DIR="Releases"
mkdir -p "$RELEASE_DIR"

# 2. Prepare Icon globally if needed (to avoid re-generating per arch)
if [ ! -f "AppIcon.icns" ] && [ -f "$ICON_SOURCE" ]; then
    echo "🎨 Generating AppIcon.icns from source..."
    ICONSET="PlayIPTV.iconset"
    mkdir -p "$ICONSET"
    sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" &>/dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" &>/dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" &>/dev/null
    sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" &>/dev/null
    sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" &>/dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" &>/dev/null
    sips -z 256 256   "$ICONSET/icon_256x256.png" &>/dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" &>/dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" &>/dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" &>/dev/null
    iconutil -c icns "$ICONSET" -o "AppIcon.icns"
    rm -rf "$ICONSET"
fi

# 3. Run Builds
# 3. Run Builds
build_for_arch "arm64"

echo ""
echo "🎉 Build complete!"
echo "📂 Artifacts in $RELEASE_DIR/"
echo "   - Distribution Zip: $RELEASE_DIR/${APP_NAME}*${ARCH}.zip"
echo ""
echo "🚀 To Release on GitHub:"
echo "1. Go to your repo -> Releases -> Draft a new release"
echo "2. Tag it as v$VERSION"
echo "3. Upload the zip file from $RELEASE_DIR/"
