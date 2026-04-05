#!/usr/bin/env bash
set -euo pipefail

# DavyWhisper Unified Build & Install Script
# Build location: /Applications/DavyWhisper-build (TEMPORARY)
# Install location: /Applications/DavyWhisper.app (SINGLE SOURCE OF TRUTH)
# After build: Build directory is DELETED to prevent duplicates

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SCHEME="DavyWhisper"
PROJECT="DavyWhisper.xcodeproj"
APP_NAME="DavyWhisper"
BUILD_DIR="/Applications/DavyWhisper-build"
INSTALL_DIR="/Applications/DavyWhisper.app"

echo "=== DavyWhisper Unified Build ==="
echo "Build Dir (temp): $BUILD_DIR"
echo "Install Dir: $INSTALL_DIR"
echo ""

# Clean previous build
echo "[1/5] Cleaning previous build..."
rm -rf "$BUILD_DIR"

# Clean any stale install
echo "[2/5] Cleaning stale install..."
if [ -d "$INSTALL_DIR" ]; then
    sudo rm -rf "$INSTALL_DIR"
    echo "   Removed old: $INSTALL_DIR"
fi

# Generate project
echo "[3/5] Generating project..."
cd "$PROJECT_DIR"
xcodegen generate

# Resolve packages
echo "[4/5] Resolving Swift packages..."
xcodebuild -resolvePackageDependencies \
  -project "$PROJECT_DIR/$PROJECT" \
  -scheme "$SCHEME"

# Build Release
echo "[5/5] Building Release..."
set -o pipefail
xcodebuild -project "$PROJECT_DIR/$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY='-' \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO | tee "$BUILD_DIR/build.log"

echo ""
echo "Checking build output..."
APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: App not found at $APP_PATH"
    exit 1
fi

echo "✓ Build succeeded: $APP_PATH"
echo ""

# Install to /Applications
echo "Installing to $INSTALL_DIR..."
sudo cp -R "$APP_PATH" "$INSTALL_DIR"

echo ""
echo "=== Cleaning up build directory ==="
rm -rf "$BUILD_DIR"
echo "Deleted: $BUILD_DIR"

echo ""
echo "=== Build & Install Complete ==="
echo "App location: $INSTALL_DIR"
echo "Bundle ID: $(defaults read "$INSTALL_DIR/Contents/Info.plist" CFBundleIdentifier)"
echo ""
echo "To launch: open $INSTALL_DIR"
