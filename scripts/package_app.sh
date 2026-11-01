#!/bin/bash
set -euo pipefail

if [ -z "${SDK_PATH:-}" ]; then
    SDK_PATH="$(xcrun --show-sdk-path 2>/dev/null || true)"
fi
if [ -z "${SDK_PATH}" ] || [ ! -d "${SDK_PATH}" ]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
fi

CONFIGURATION="${1:-release}"
TARGET="${TARGET:-arm64-apple-macos15.0}"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/SoundBalancer.app"
BIN_DIR=".build/${CONFIGURATION}"

echo "Building SoundBalancer (${CONFIGURATION}) with SDK ${SDK_PATH} targeting ${TARGET}..."
mkdir -p /tmp/clang-cache
swift build -c "${CONFIGURATION}" --sdk "${SDK_PATH}" -Xswiftc -target -Xswiftc "${TARGET}" -Xswiftc -module-cache-path -Xswiftc /tmp/clang-cache

echo "Assembling application bundle at ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BIN_DIR}/SoundBalancer" "${APP_BUNDLE}/Contents/MacOS/SoundBalancer"
cp Config/Info.plist "${APP_BUNDLE}/Contents/Info.plist"

echo "Signing application bundle..."
codesign -s - --force --deep --entitlements Config/SoundBalancer.entitlements "${APP_BUNDLE}"

echo "Successfully created and signed ${APP_BUNDLE}!"
