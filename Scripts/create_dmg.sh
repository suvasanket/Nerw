#!/bin/bash
set -e

APP_NAME="Nerw"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
TMP_DMG="build/tmp.dmg"
DMG_DIR="build/dmg_temp"
VOLUME_NAME="Nerw"
BACKGROUND_IMAGE="Assets/dmg_background.png"

# Check if application bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: $APP_BUNDLE not found. Run 'make bundle' first."
    exit 1
fi

# Ensure no stale mount points exist from previous failed or manual runs
if mount | grep -q "on /Volumes/${VOLUME_NAME}"; then
    echo "Unmounting stale volume..."
    hdiutil detach "/Volumes/${VOLUME_NAME}" 2>/dev/null || true
    sleep 1
fi
if mount | grep -q "on /Volumes/${VOLUME_NAME} 1"; then
    echo "Unmounting stale volume..."
    hdiutil detach "/Volumes/${VOLUME_NAME} 1" 2>/dev/null || true
    sleep 1
fi

echo "Cleaning up previous DMG build files..."
rm -rf "$TMP_DMG" "$DMG_NAME" "$DMG_DIR"
mkdir -p "build"
mkdir -p "$DMG_DIR"

echo "Copying application bundle to staging directory..."
cp -R "$APP_BUNDLE" "$DMG_DIR/"

echo "Creating Applications folder symlink..."
ln -s /Applications "$DMG_DIR/Applications"

echo "Preparing background image..."
mkdir -p "$DMG_DIR/.background"

# Get original dimensions of the background image
BG_W=$(sips -g pixelWidth "$BACKGROUND_IMAGE" | tail -1 | awk '{print $NF}')
BG_H=$(sips -g pixelHeight "$BACKGROUND_IMAGE" | tail -1 | awk '{print $NF}')

# Calculate target dimensions (width 900, maintain aspect ratio) to safely bypass Finder's minimum width limit
TARGET_W=900
TARGET_H=$(( BG_H * TARGET_W / BG_W ))

# Resize the background image dynamically based on the aspect ratio
sips -z $TARGET_H $TARGET_W "$BACKGROUND_IMAGE" --out "$DMG_DIR/.background/dmg_background.png" > /dev/null

echo "Creating raw temporary disk image..."
hdiutil create -srcfolder "$DMG_DIR" -volname "$VOLUME_NAME" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 150m "$TMP_DMG"

echo "Mounting temporary DMG for visual styling..."
# Mount the temp image and extract the mount path
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "$TMP_DMG" | grep "/Volumes/" | awk -F '\t' '{print $NF}')
echo "Mounted at: $MOUNT_DIR"

if [ -z "$MOUNT_DIR" ]; then
    echo "Error: Failed to mount the temporary DMG."
    exit 1
fi

echo "Configuring Finder window layout, positions, and background..."
# Apply Finder customizations using AppleScript
osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set containerWindow to container window
        set toolbar visible of containerWindow to false
        set statusbar visible of containerWindow to false
        try
            set sidebar width of containerWindow to 0
        end try

        -- Set bounds dynamically based on target dimensions
        set the bounds of containerWindow to {100, 100, $(( 100 + TARGET_W )), $(( 100 + TARGET_H ))}
        
        -- macOS bug workaround: delay and re-apply bounds to ensure Finder respects them
        delay 2
        set the bounds of containerWindow to {100, 100, $(( 100 + TARGET_W )), $(( 100 + TARGET_H ))}

        set theViewOptions to icon view options of containerWindow
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 72

        -- Set background picture
        set background picture of theViewOptions to file ".background:dmg_background.png"

        -- Position items dynamically based on target dimensions (26% and 74% horizontally, 50% vertically)
        set position of item "$APP_BUNDLE" of containerWindow to {$(( TARGET_W * 26 / 100 )), $(( TARGET_H * 50 / 100 ))}
        set position of item "Applications" of containerWindow to {$(( TARGET_W * 74 / 100 )), $(( TARGET_H * 50 / 100 ))}

        -- Force update Finder visual state
        update every item
        close
    end tell
end tell
EOF

echo "Applying permissions & delaying for OS cache sync..."
sleep 3

echo "Unmounting temporary DMG..."
hdiutil detach "$MOUNT_DIR"

echo "Converting temporary DMG into compressed, read-only distribution DMG..."
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_NAME"

echo "Cleaning up temporary files..."
rm -rf "$TMP_DMG" "$DMG_DIR"

echo "DMG creation complete: $DMG_NAME"
