#!/bin/bash
# 构建 TraeChime.dmg（未签名/未公证，仅本地分发使用）
set -euo pipefail
cd "$(dirname "$0")/.."

# 先构建 .app
./scripts/make_app.sh

STAGE="dist/dmg-staging"
DMG="dist/TraeChime.dmg"

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "dist/TraeChime.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -volname "TraeChime" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

echo "已生成 $DMG"
