#!/bin/bash
# 构建并组装 TraeChime.app（LSUIElement 菜单栏应用），临时签名
set -euo pipefail
cd "$(dirname "$0")/.."

# 版本号唯一来源：读 VERSION 文件（CI 打 tag 前会先校验 tag 与其一致）
VERSION="$(cat VERSION 2>/dev/null || echo '0.0.0')"

# 构建 universal 二进制（同时支持 Apple Silicon 与 Intel Mac）。
# 单纯 `swift build -c release` 只产出当前机器架构：
#   - 本机(Intel)构建出 x86_64，能装但无法在 Apple Silicon 上运行；
#   - CI(macos-latest=arm64)构建出 arm64，在 Intel Mac 上会提示“不支持 Intel macOS”。
# 因此分别交叉编译两种架构，再用 lipo 合并为 fat binary，保证同一份 DMG 两端通用。
swift build -c release --arch arm64
swift build -c release --arch x86_64

UNIVERSAL=".build/universal"
mkdir -p "$UNIVERSAL"

lipo -create \
  .build/arm64-apple-macosx/release/TraeChime \
  .build/x86_64-apple-macosx/release/TraeChime \
  -output "$UNIVERSAL/TraeChime"

lipo -create \
  .build/arm64-apple-macosx/release/TraeChimeHook \
  .build/x86_64-apple-macosx/release/TraeChimeHook \
  -output "$UNIVERSAL/TraeChimeHook"

BIN="$UNIVERSAL/TraeChime"
APP="dist/TraeChime.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/TraeChime"

# 图标
./scripts/gen_icns.sh
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# 面板 Logo（供 Bundle.main 读取）
cp "Sources/TraeChime/Resources/traechime-logo-chime-word-rounded-v3.jpg" \
   "$APP/Contents/Resources/traechime-logo-chime-word-rounded-v3.jpg"

# 菜单栏 logo 图案（去白底透明 PNG）
cp "Sources/TraeChime/Resources/traechime-logo-mark.png" \
   "$APP/Contents/Resources/traechime-logo-mark.png"

# Hook 桥接二进制（供「一键接入」写入 hooks.json 后调用）
cp "$UNIVERSAL/TraeChimeHook" "$APP/Contents/Resources/traechime-hook"
chmod +x "$APP/Contents/Resources/traechime-hook"

# Info.plist
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>TraeChime</string>
    <key>CFBundleDisplayName</key>
    <string>TraeChime</string>
    <key>CFBundleIdentifier</key>
    <string>com.traechime.app</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>TraeChime</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

codesign --force --deep -s - "$APP"
echo "已生成 $APP"
