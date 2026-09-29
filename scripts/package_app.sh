#!/bin/bash
set -euo pipefail

SDK_PATH="${SDK_PATH:-/Library/Developer/CommandLineTools/SDKs/MacOSX27.0.sdk}"
if [ ! -d "${SDK_PATH}" ]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
fi
CONFIGURATION="${1:-release}"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/SoundBalancer.app"
BIN_DIR=".build/${CONFIGURATION}"

echo "Building SoundBalancer (${CONFIGURATION}) with SDK ${SDK_PATH} targeting macOS 27.0..."
mkdir -p /tmp/clang-cache
swift build -c "${CONFIGURATION}" --sdk "${SDK_PATH}" -Xswiftc -target -Xswiftc arm64-apple-macos27.0 -Xswiftc -module-cache-path -Xswiftc /tmp/clang-cache

echo "Assembling application bundle at ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BIN_DIR}/SoundBalancer" "${APP_BUNDLE}/Contents/MacOS/SoundBalancer"
cp Config/Info.plist "${APP_BUNDLE}/Contents/Info.plist"

echo "Signing application bundle..."
codesign -s - --force --deep --entitlements Config/SoundBalancer.entitlements "${APP_BUNDLE}"

echo "Successfully created and signed ${APP_BUNDLE}!"
