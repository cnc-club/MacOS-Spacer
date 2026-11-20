#!/bin/zsh
set -eu
cd "$(dirname "$0")"
configuration="${1:-release}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$PWD/.build/ModuleCache}"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
swift build --disable-sandbox --cache-path "$PWD/.build/cache" -c "$configuration" -j 2
mkdir -p dist/Spacer.app/Contents/MacOS
cp .build/"$configuration"/Spacer dist/Spacer.app/Contents/MacOS/Spacer
mkdir -p dist/Spacer.app/Contents/Resources
cp -R .build/"$configuration"/Spacer_Spacer.bundle dist/Spacer.app/Contents/Resources/
cp LICENSE dist/Spacer.app/Contents/Resources/LICENSE.txt
cat > dist/Spacer.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Spacer</string>
<key>CFBundleIdentifier</key><string>local.spacer.app</string>
<key>CFBundleName</key><string>Spacer</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>ru</string></array>
<key>NSHumanReadableCopyright</key><string>Copyright © 2026 Nick. MIT License.</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - dist/Spacer.app
