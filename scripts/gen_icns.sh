#!/bin/bash
# 将品牌 Logo 生成 AppIcon.icns（sips + iconutil）
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="Sources/TraeChime/Resources/traechime-logo-mark.png"
OUT="AppIcon.icns"
TMP="$(mktemp -d)"
ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"

# 显式 -s format png，避免 sips 将 jpg 源原样写入 .png 文件名导致 iconutil 失败
gen() {
  local size="$1"
  local name="$2"
  sips -z "$size" "$size" -s format png "$SRC" --out "$ICONSET/$name" >/dev/null
}

gen 16   "icon_16x16.png"
gen 32   "icon_16x16@2x.png"
gen 32   "icon_32x32.png"
gen 64   "icon_32x32@2x.png"
gen 128  "icon_128x128.png"
gen 256  "icon_128x128@2x.png"
gen 256  "icon_256x256.png"
gen 512  "icon_256x256@2x.png"
gen 512  "icon_512x512.png"
gen 1024 "icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$OUT"
rm -rf "$TMP"
echo "已生成 $OUT"
