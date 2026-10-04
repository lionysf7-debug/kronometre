#!/bin/bash
# Kronometre derleme betiği — Xcode gerekmez, Command Line Tools yeterli.
#   ./build.sh            → build/Kronometre.app üretir
#   ./build.sh --install  → /Applications'a kurar ve başlatır
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Kronometre"
BUILD="$PWD/build"
# Masaüstü iCloud ile eşitleniyorsa codesign eklenen öznitelikleri reddeder:
# paket geçici klasörde birleştirilip imzalanır. Klasör mktemp ile rastgele adla ve yalnızca
# bize açık oluşturulur: sabit bir /tmp yolunda başka bir kullanıcı imzalanmadan önce dosyaları değiştirebilirdi.
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/kronometre-build.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/$APP_NAME.app"

SWIFTC=$(xcrun -f swiftc)
SDK=$(xcrun --show-sdk-path)
TOOLCHAIN_USR="$(cd "$(dirname "$SWIFTC")/.." && pwd)"
mkdir -p "$BUILD"

# Bazı Command Line Tools sürümlerindeki "redefinition of module 'SwiftBridging'"
# hatası için FreeSlap'teki geçici çözüm.
EXTRA=()
if [ -f "$TOOLCHAIN_USR/include/swift/module.modulemap" ] && [ -f "$TOOLCHAIN_USR/include/swift/bridging.modulemap" ]; then
  OVERLAY="$BUILD/.swift-overlay"
  if [ ! -d "$OVERLAY/lib/swift" ]; then
    mkdir -p "$OVERLAY/lib/swift" "$OVERLAY/include/swift"
    for f in "$TOOLCHAIN_USR"/lib/swift/*; do ln -sf "$f" "$OVERLAY/lib/swift/$(basename "$f")"; done
    ln -sf "$TOOLCHAIN_USR/include/swift/bridging" "$OVERLAY/include/swift/bridging"
    ln -sf "$TOOLCHAIN_USR/include/swift/bridging.modulemap" "$OVERLAY/include/swift/bridging.modulemap"
  fi
  EXTRA+=(-resource-dir "$OVERLAY/lib/swift")
fi

echo "▸ Derleniyor"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
"$SWIFTC" -O -target arm64-apple-macos14.0 -sdk "$SDK" ${EXTRA[@]+"${EXTRA[@]}"} \
  -parse-as-library Sources/*.swift -o "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"   # yeniden çizmek için: Icon/make-icon.sh

echo "▸ İmzalanıyor (ad-hoc, hardened runtime)"
xattr -cr "$APP"
# Hardened runtime: DYLD_INSERT_LIBRARIES gibi ortam değişkenleriyle uygulamaya kod enjekte edilemez.
codesign --force --deep --sign - --options runtime "$APP"
codesign --verify --strict "$APP"

if [ "${1:-}" = "--install" ]; then
  pkill -x "$APP_NAME" 2>/dev/null && sleep 1 || true
  rm -rf "/Applications/$APP_NAME.app"
  ditto "$APP" "/Applications/$APP_NAME.app"
  open "/Applications/$APP_NAME.app"
  echo "✓ /Applications/$APP_NAME.app kuruldu ve başlatıldı"
else
  rm -rf "$BUILD/$APP_NAME.app"
  ditto "$APP" "$BUILD/$APP_NAME.app"
  echo "✓ $BUILD/$APP_NAME.app"
fi
