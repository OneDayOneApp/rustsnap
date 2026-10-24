#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUT="$ROOT/dist"
export RUSTSNAP_ARCH="${RUSTSNAP_ARCH:-universal}"
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/rustsnap-package.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT HUP INT TERM
mkdir -p "$OUT" "$STAGE/image"
"$ROOT/scripts/build-app.sh" "$STAGE/image/RustSnap.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$STAGE/image/RustSnap.app/Contents/Info.plist")
ARCHS=$(/usr/bin/lipo -archs "$STAGE/image/RustSnap.app/Contents/MacOS/RustSnap")
case "$ARCHS" in
  *arm64*x86_64*|*x86_64*arm64*) ARCH=universal; COMPATIBILITY="Intel 和 Apple Silicon（M 系列芯片）Mac" ;;
  *x86_64*) ARCH=x86_64; COMPATIBILITY="Intel Mac" ;;
  *arm64*) ARCH=arm64; COMPATIBILITY="Apple Silicon（M 系列芯片）Mac" ;;
  *) echo "Unsupported architecture: $ARCHS" >&2; exit 2 ;;
esac
BASE="RustSnap-$VERSION-macOS-$ARCH"
ln -s /Applications "$STAGE/image/Applications"
cat > "$STAGE/image/安装说明.txt" <<TEXT
RustSnap 安装说明

适用：${COMPATIBILITY}，macOS 11 或更新版本。

1. 将 RustSnap.app 拖到 Applications（应用程序）文件夹。
2. 从“应用程序”打开 RustSnap，默认仅驻留顶部菜单栏。
3. 截图默认快捷键为 Control + Command + S，可在偏好设置中修改。
4. 使用截图前，请在系统设置的隐私与安全性中允许 RustSnap 录制屏幕。
5. 菜单栏中可打开标注窗口、偏好设置和浮动便签。
6. 如需退出，请使用顶部菜单中的“退出 RustSnap”。

此构建使用本地临时签名，未经过 Apple 公证。首次运行可能受到 Gatekeeper 限制。
本安装包不包含个人偏好、截图、便签或 Apple 账号信息。
TEXT
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$STAGE/image/RustSnap.app" "$OUT/$BASE.zip"
/usr/bin/unzip -t "$OUT/$BASE.zip" > "$OUT/$BASE-zip-check.txt"
/usr/bin/hdiutil create -volname "RustSnap $VERSION" -srcfolder "$STAGE/image" -format UDZO -ov "$OUT/$BASE.dmg"
/usr/bin/hdiutil verify "$OUT/$BASE.dmg"
(cd "$OUT" && shasum -a 256 "$BASE.dmg" "$BASE.zip" > "$BASE-SHA256SUMS.txt")
printf 'DMG: %s\nZIP: %s\n' "$OUT/$BASE.dmg" "$OUT/$BASE.zip"
