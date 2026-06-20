#!/bin/bash
set -e

APP=${APP:-Nerw}
BUILD_DIR=${BUILD_DIR:-.build/debug}
CODESIGN_ID=${CODESIGN_ID:-LocalDevCert}

BUNDLE_NAME="${APP}.app"
MACOS_DIR="${BUNDLE_NAME}/Contents/MacOS"
CLI_BIN_DIR="${BUNDLE_NAME}/Contents/cli_bin"
RESOURCES_DIR="${BUNDLE_NAME}/Contents/Resources"

ICON_SOURCE="Assets/icon.png"
ICON_SET="AppIcon.iconset"
ICON_DEST="${RESOURCES_DIR}/AppIcon.icns"

EXT_ICON_SOURCE="Assets/nerw_ext.png"
EXT_ICON_SET="nerw_ext.iconset"
EXT_ICON_DEST="${RESOURCES_DIR}/nerw_ext.icns"

MENUBAR_ICON_SOURCE="Assets/iconTemplate.png"

echo "Bundling ${APP}..."

mkdir -p "${MACOS_DIR}"
mkdir -p "${CLI_BIN_DIR}"
mkdir -p "${RESOURCES_DIR}"
mkdir -p "${RESOURCES_DIR}/Modules"
mkdir -p "${RESOURCES_DIR}/lib"

cp Info.plist "${BUNDLE_NAME}/Contents/"
cp "${BUILD_DIR}/${APP}" "${MACOS_DIR}/"
cp "${BUILD_DIR}/nerw-cli" "${CLI_BIN_DIR}/nerw"

cp -R "${BUILD_DIR}/Modules/NerwExtensionKit."* "${RESOURCES_DIR}/Modules/" 2>/dev/null || true
cp "${BUILD_DIR}/libNerwExtensionKit.a" "${RESOURCES_DIR}/lib/" 2>/dev/null || true

# App Icon
if [ ! -f "${ICON_DEST}" ] || [ "${ICON_SOURCE}" -nt "${ICON_DEST}" ]; then
    echo "Generating App Icon..."
    mkdir -p "${ICON_SET}"
    sips -z 16 16     "${ICON_SOURCE}" --out "${ICON_SET}/icon_16x16.png" > /dev/null 2>&1
    sips -z 32 32     "${ICON_SOURCE}" --out "${ICON_SET}/icon_16x16@2x.png" > /dev/null 2>&1
    sips -z 32 32     "${ICON_SOURCE}" --out "${ICON_SET}/icon_32x32.png" > /dev/null 2>&1
    sips -z 64 64     "${ICON_SOURCE}" --out "${ICON_SET}/icon_32x32@2x.png" > /dev/null 2>&1
    sips -z 128 128   "${ICON_SOURCE}" --out "${ICON_SET}/icon_128x128.png" > /dev/null 2>&1
    sips -z 256 256   "${ICON_SOURCE}" --out "${ICON_SET}/icon_128x128@2x.png" > /dev/null 2>&1
    sips -z 256 256   "${ICON_SOURCE}" --out "${ICON_SET}/icon_256x256.png" > /dev/null 2>&1
    sips -z 512 512   "${ICON_SOURCE}" --out "${ICON_SET}/icon_512x512.png" > /dev/null 2>&1
    sips -z 512 512   "${ICON_SOURCE}" --out "${ICON_SET}/icon_512x512@2x.png" > /dev/null 2>&1
    sips -z 1024 1024 "${ICON_SOURCE}" --out "${ICON_SET}/icon_512x512@2x.png" > /dev/null 2>&1
    iconutil -c icns "${ICON_SET}"
    cp AppIcon.icns "${ICON_DEST}"
    rm -rf "${ICON_SET}" AppIcon.icns
fi

# Copy other resources
cp -r Resources/* "${RESOURCES_DIR}/" 2>/dev/null || true

# Menubar icon
if [ ! -f "${RESOURCES_DIR}/iconTemplate.png" ] || [ "${MENUBAR_ICON_SOURCE}" -nt "${RESOURCES_DIR}/iconTemplate.png" ]; then
    echo "Generating Menubar Icon..."
    sips -z 18 18     "${MENUBAR_ICON_SOURCE}" --out "${RESOURCES_DIR}/iconTemplate.png" > /dev/null 2>&1
    sips -z 36 36     "${MENUBAR_ICON_SOURCE}" --out "${RESOURCES_DIR}/iconTemplate@2x.png" > /dev/null 2>&1
fi

# Extension Icon
if [ ! -f "${EXT_ICON_DEST}" ] || [ "${EXT_ICON_SOURCE}" -nt "${EXT_ICON_DEST}" ]; then
    echo "Generating Extension Icon..."
    mkdir -p "${EXT_ICON_SET}"
    sips -z 16 16     "${EXT_ICON_SOURCE}" --out "${EXT_ICON_SET}/icon_16x16.png" > /dev/null 2>&1
    sips -z 32 32     "${EXT_ICON_SOURCE}" --out "${EXT_ICON_SET}/icon_16x16@2x.png" > /dev/null 2>&1
    sips -z 32 32     "${EXT_ICON_SOURCE}" --out "${EXT_ICON_SET}/icon_32x32.png" > /dev/null 2>&1
    sips -z 64 64     "${EXT_ICON_SOURCE}" --out "${EXT_ICON_SET}/icon_32x32@2x.png" > /dev/null 2>&1
    sips -z 128 128   "${EXT_ICON_SOURCE}" --out "${EXT_ICON_SET}/icon_128x128.png" > /dev/null 2>&1
    sips -z 256 256   "${EXT_ICON_SOURCE}" --out "${EXT_ICON_SET}/icon_128x128@2x.png" > /dev/null 2>&1
    sips -z 256 256   "${EXT_ICON_SOURCE}" --out "${EXT_ICON_SET}/icon_256x256.png" > /dev/null 2>&1
    sips -z 512 512   "${EXT_ICON_SOURCE}" --out "${EXT_ICON_SET}/icon_512x512.png" > /dev/null 2>&1
    sips -z 512 512   "${EXT_ICON_SOURCE}" --out "${EXT_ICON_SET}/icon_512x512@2x.png" > /dev/null 2>&1
    sips -z 1024 1024 "${EXT_ICON_SOURCE}" --out "${EXT_ICON_SET}/icon_512x512@2x.png" > /dev/null 2>&1
    iconutil -c icns "${EXT_ICON_SET}"
    cp nerw_ext.icns "${EXT_ICON_DEST}"
    rm -rf "${EXT_ICON_SET}" nerw_ext.icns
fi

if [ -n "${CODESIGN_ID}" ] && security find-identity -p codesigning -v | grep -q "${CODESIGN_ID}"; then
    echo "Signing ${BUNDLE_NAME} with ${CODESIGN_ID}..."
    codesign --force --deep --sign "${CODESIGN_ID}" "${BUNDLE_NAME}"
else
    echo "No codesigning identity '${CODESIGN_ID}' found. Leaving ${BUNDLE_NAME} unsigned."
fi

echo "Bundle completed successfully."
