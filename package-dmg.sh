#!/bin/zsh
# Build a self-contained, compressed disk image for the current Mac architecture.
set -eu
cd "$(dirname "$0")"
./build-app.sh release
app_path="$PWD/dist/Spacer.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")
architecture=$(uname -m)
image_path="$PWD/dist/Spacer-${version}-macOS-${architecture}.dmg"
volume_name="Spacer ${version}"
staging=$(mktemp -d "$PWD/dist/dmg-stage.XXXXXX")
trap 'rm -rf "$staging"' EXIT
cp -R "$app_path" "$staging/Spacer.app"
ln -s /Applications "$staging/Applications"
cat > "$staging/Read Me.txt" <<'TXT'
Spacer — a simple, free disk space utility for macOS

No build tools or installer required. Double-click Spacer.app to run it
straight from this disk image, or copy it to Applications or any writable
folder on your Mac. Eject the image after quitting Spacer.

Requires macOS 13 or later. This image contains the app for the architecture
shown in the DMG filename (arm64 = Apple Silicon; x86_64 = Intel).

This community build is locally signed, not Apple-notarized. macOS may ask
you to approve opening it. Protected folders may require Full Disk Access
in System Settings > Privacy & Security. For a persistent permission grant,
copy the app to Applications before granting access.

English and Russian are included. The app runs locally and does not
upload your file list. Files move to Trash only after confirmation.

Source and MIT license: https://github.com/cnc-club/MacOS-Spacer
The complete license is inside Spacer.app/Contents/Resources/LICENSE.txt.
TXT
codesign --verify --deep --strict "$staging/Spacer.app"
hdiutil create -ov -format UDZO -imagekey zlib-level=9 -volname "$volume_name" -srcfolder "$staging" "$image_path"
hdiutil verify "$image_path"
shasum -a 256 "$image_path" > "$image_path.sha256"
echo "Created: $image_path"
