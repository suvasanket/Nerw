#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Error: Please specify the new version (e.g., 0.1.0-beta.1)"
    exit 1
fi

NEW_VERSION="$1"
PLIST_FILE="Info.plist"

if [ ! -f "$PLIST_FILE" ]; then
    echo "Error: $PLIST_FILE not found in the current directory."
    exit 1
fi

# Calculate build number from git commit count
BUILD_NUMBER=$(git rev-list --count HEAD)
BUILD_NUMBER=$((BUILD_NUMBER + 1))

echo "Bumping version to $NEW_VERSION ($BUILD_NUMBER)..."

# Update Info.plist using plutil
plutil -replace CFBundleShortVersionString -string "$NEW_VERSION" "$PLIST_FILE"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$PLIST_FILE"

echo "Updated $PLIST_FILE successfully."

# Automatically commit and tag (efficient workflow)
git add "$PLIST_FILE"
git commit -m "chore: release v$NEW_VERSION"
git tag "v$NEW_VERSION"

echo "Successfully committed and tagged v$NEW_VERSION."
echo "You can now push using: git push origin HEAD --tags"
