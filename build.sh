#!/bin/bash
# 有 Mac 时用：在 AqingApp 目录下执行 ./build.sh
# 产出 build/Aqing-unsigned.ipa，再用 Sideloadly / AltStore 免费签一次装到 iPhone。
# 没 Mac 就别跑这个，改用 .github/workflows/build-unsigned-ipa.yml（GitHub  macOS runner 免费）。
set -euo pipefail
cd "$(dirname "$0")"

SDK="${SDK:-iphoneos}"
OUT="build"
rm -rf "$OUT"
mkdir -p "$OUT/Payload"

# 用 -target 而不是 -scheme：手写 pbxproj 没有 shared scheme，避免 "not configured"
xcodebuild \
  -project Aqing.xcodeproj \
  -target Aqing \
  -configuration Release \
  -sdk "$SDK" \
  -derivedDataPath "$OUT/DerivedData" \
  -arch arm64 \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  clean build

APP_PATH="$OUT/DerivedData/Build/Products/Release-iphoneos/Aqing.app"
if [ ! -d "$APP_PATH" ]; then
  echo "找不到 $APP_PATH，看看上面的 xcodebuild 报错" >&2
  exit 1
fi
cp -R "$APP_PATH" "$OUT/Payload/"
(cd "$OUT" && zip -qr Aqing-unsigned.ipa Payload)
echo ""
echo "完成：$OUT/Aqing-unsigned.ipa"
echo "用 Sideloadly 选这个 ipa + 免费 Apple ID 侧载即可（7 天重签一次）。"
echo "想改 Bundle ID / 签名团队：Xcode 里打开 Aqing.xcodeproj → Target → Signing。"
