#!/bin/bash
# 构建并组装 TraeChime.app（LSUIElement 菜单栏应用），临时签名
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

BIN=".build/release/TraeChime"
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
cp ".build/release/TraeChimeHook" "$APP/Contents/Resources/traechime-hook"
chmod +x "$APP/Contents/Resources/traechime-hook"

# Info.plist
cat > "$APP/Contents/Info.plist" <<'EOF'
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
    <string>1.0.0</string>
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
