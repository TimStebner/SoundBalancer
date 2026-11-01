#!/bin/bash
set -euo pipefail

APP_BUNDLE="build/SoundBalancer.app"
RELEASE_DIR="release"
DMG_PATH="${RELEASE_DIR}/SoundBalancer-arm64.dmg"

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "App bundle not found at ${APP_BUNDLE}. Building first..."
    ./scripts/package_app.sh release
fi

mkdir -p "${RELEASE_DIR}"
rm -f "${DMG_PATH}"

echo "Creating DMG at ${DMG_PATH}..."
hdiutil create -volname "SoundBalancer" -srcfolder "${APP_BUNDLE}" -ov -format UDZO "${DMG_PATH}"
echo "Successfully created ${DMG_PATH}!"
