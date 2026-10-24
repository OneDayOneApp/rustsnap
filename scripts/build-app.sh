#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
export MACOSX_DEPLOYMENT_TARGET=11.0
case "${RUSTSNAP_ARCH:-native}" in
  native)
    cargo build --release --offline
    BINARY="$ROOT/target/release/rustsnip"
    ;;
  universal)
    # Use one rustup toolchain for both slices, independently of Homebrew PATH ordering.
    export RUSTC="$(rustup which --toolchain stable rustc)"
    CARGO="$(rustup which --toolchain stable cargo)"
    "$CARGO" --config profile.release.strip=false build --release --offline --target aarch64-apple-darwin
    "$CARGO" --config profile.release.strip=false build --release --offline --target x86_64-apple-darwin
    BINARY="$ROOT/target/universal-apple-darwin/release/rustsnip"
    mkdir -p "$(dirname -- "$BINARY")"
    /usr/bin/lipo -create "$ROOT/target/aarch64-apple-darwin/release/rustsnip" "$ROOT/target/x86_64-apple-darwin/release/rustsnip" -output "$BINARY"
    /usr/bin/lipo "$BINARY" -verify_arch arm64 x86_64
    ;;
  *) echo "RUSTSNAP_ARCH must be native or universal" >&2; exit 2 ;;
esac
APP="${1:?Usage: build-app.sh /absolute/path/RustSnap.app}"
case "$APP" in /*.app) ;; *) echo "Expected an absolute .app path" >&2; exit 2 ;; esac
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/RustSnap"
cp assets/RustSnap.icns "$APP/Contents/Resources/RustSnap.icns"
mkdir -p "$APP/Contents/Resources/snip-toolbar"
cp assets/snip-toolbar/*.png "$APP/Contents/Resources/snip-toolbar/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>RustSnap</string>
<key>CFBundleDisplayName</key><string>RustSnap</string>
<key>CFBundleIdentifier</key><string>dev.local.rustsnip</string>
<key>CFBundleExecutable</key><string>RustSnap</string>
<key>CFBundleIconFile</key><string>RustSnap.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.4.1</string>
<key>CFBundleVersion</key><string>17</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>LSMinimumSystemVersion</key><string>11.0</string>
<key>NSScreenCaptureUsageDescription</key><string>RustSnap captures only the screen region you select, so you can annotate and save it locally.</string>
</dict></plist>
PLIST
printf 'APPL????' > "$APP/Contents/PkgInfo"
/usr/bin/codesign --force --deep --sign - --identifier dev.local.rustsnip "$APP"
/usr/bin/codesign --verify --all-architectures --deep --strict "$APP"
touch "$APP"
printf 'Installed: %s\n' "$APP"
