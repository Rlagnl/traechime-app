#!/bin/bash
# 构建 TraeChime DMG 安装包（未签名/未公证，仅本地分发使用）
set -euo pipefail
cd "$(dirname "$0")/.."

# 先构建 .app
./scripts/make_app.sh

# 从 VERSION 文件读取版本号，DMG 文件名带版本（与 CI 发布产物一致）
VERSION="$(cat VERSION 2>/dev/null || echo '0.0.0')"

STAGE="dist/dmg-staging"
DMG="dist/TraeChime-${VERSION}.dmg"

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "dist/TraeChime.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -volname "TraeChime" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

echo "已生成 $DMG"
