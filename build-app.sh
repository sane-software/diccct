#!/usr/bin/env bash
# Assemble SaneDiccct.app from a release build.
#
# SaneDiccct is a SwiftPM package with no Xcode project by design (zero third-party
# dependencies). This script does what Xcode would otherwise do: build the
# release executable and wrap it in a proper .app bundle with an Info.plist so it
# runs as a normal menu-bar app (double-clickable, LSUIElement).
set -euo pipefail

# The script lives at the repo root, so its own directory is the repo root.
# Resolving from BASH_SOURCE keeps it working when invoked from anywhere.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${REPO_ROOT}"

APP_NAME="SaneDiccct"
BUNDLE_ID="com.sane-software.sanediccct"
VERSION="0.1.0"
APP_DIR="${REPO_ROOT}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "Building release binary…"
swift build -c release --product "${APP_NAME}"
BIN_PATH="$(swift build -c release --product "${APP_NAME}" --show-bin-path)/${APP_NAME}"
test -x "${BIN_PATH}" # fail loud if the expected binary is missing

echo "Assembling ${APP_NAME}.app…"
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"

cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signature so macOS will run the local bundle. This is not a Developer ID
# signature (which would need an Apple account); it is enough for personal use on
# the machine that built it.
codesign --force --deep --sign - "${APP_DIR}"

echo "Done: ${APP_DIR}"
echo "Run it with: open \"${APP_DIR}\""
