#!/bin/bash
# 在 Mac 上运行。默认开发签名，仅导出本地文件，不上传 App Store。
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project="${IOS_XCODE_PROJECT:-$script_dir/Xcode/BoomerangArena.xcodeproj}"
if [[ ! -d "$project" && -z "${IOS_XCODE_PROJECT:-}" ]]; then
  project="$script_dir/../build/ios/Xcode/BoomerangArena.xcodeproj"
fi

usage() {
  cat <<'HELP'
用法（Mac）：
  bash build-ipa.sh --open
    打开已导出的 Xcode 工程，在 Signing & Capabilities 中选择自己的 Team。

  IOS_TEAM_ID=你的10位TeamID bash build-ipa.sh --build
    使用 Mac 上已有的开发证书和设备描述文件，归档并导出 .ipa。

可选环境变量：
  IOS_BUNDLE_ID       默认 io.github.ruofei6666.boomerangarena
  IOS_EXPORT_METHOD  development（默认）、ad-hoc 或 app-store
  IOS_XCODE_PROJECT  自定义 .xcodeproj 路径
  IOS_OUTPUT_DIR     自定义输出路径；该目录必须不存在
  IOS_ALLOW_PROVISIONING_UPDATES=1
    允许 Xcode 联系 Apple 自动管理签名描述文件；需要已配置的开发者账号。

development/ad-hoc 包只能安装到描述文件包含的设备。
免费个人账号优先在 Xcode 中连接 iPhone 并点击 Run；不保证支持导出 IPA。
HELP
}

action="${1:---help}"
if [[ "$action" == "--help" || "$action" == "-h" ]]; then
  usage
  exit 0
fi
if [[ "$action" != "--open" && "$action" != "--build" ]]; then
  usage
  exit 2
fi
if [[ "$(uname -s)" != "Darwin" ]]; then
  printf '%s\n' '错误：编译和签名 .ipa 必须在安装 Xcode 的 Mac 上完成。' >&2
  exit 1
fi
if ! command -v xcodebuild >/dev/null 2>&1 || ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
  printf '%s\n' '错误：请先安装完整 Xcode 和 iOS SDK，并在 Xcode 内完成首次配置。' >&2
  exit 1
fi
if [[ ! -f "$project/project.pbxproj" ]]; then
  printf '错误：找不到 Xcode 工程：%s\n' "$project" >&2
  exit 1
fi
if [[ "$action" == "--open" ]]; then
  open "$project"
  exit 0
fi

team="${IOS_TEAM_ID:-}"
if [[ ! "$team" =~ ^[A-Z0-9]{10}$ || "$team" == "UNSIGNED00" ]]; then
  printf '%s\n' '错误：IOS_TEAM_ID 必须是自己的有效 10 位 Team ID，不能使用占位值。' >&2
  exit 1
fi
bundle_id="${IOS_BUNDLE_ID:-io.github.ruofei6666.boomerangarena}"
if [[ ! "$bundle_id" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]]; then
  printf '%s\n' '错误：IOS_BUNDLE_ID 必须采用反向域名格式。' >&2
  exit 1
fi
method="${IOS_EXPORT_METHOD:-development}"
case "$method" in
  development) certificate="Apple Development" ;;
  ad-hoc|app-store) certificate="Apple Distribution" ;;
  *) printf '%s\n' '错误：不支持的 IOS_EXPORT_METHOD。' >&2; exit 1 ;;
esac

output="${IOS_OUTPUT_DIR:-$script_dir/output/$(date +%Y%m%d-%H%M%S)-$$}"
if [[ -e "$output" ]]; then
  printf '错误：输出目录已存在，请选择新目录：%s\n' "$output" >&2
  exit 1
fi
mkdir -p "$output"
output="$(cd "$output" && pwd)"
set --
if [[ "${IOS_ALLOW_PROVISIONING_UPDATES:-0}" == "1" ]]; then
  set -- -allowProvisioningUpdates
fi

cat > "$output/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>$method</string>
  <key>destination</key><string>export</string>
  <key>teamID</key><string>$team</string>
  <key>signingStyle</key><string>automatic</string>
  <key>signingCertificate</key><string>$certificate</string>
</dict></plist>
PLIST
plutil -lint "$output/ExportOptions.plist"
xcodebuild archive \
  -project "$project" -scheme BoomerangArena -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$output/BoomerangArena.xcarchive" \
  DEVELOPMENT_TEAM="$team" PRODUCT_BUNDLE_IDENTIFIER="$bundle_id" \
  CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="$certificate" \
  "$@" 2>&1 | tee "$output/archive.log"
xcodebuild -exportArchive \
  -archivePath "$output/BoomerangArena.xcarchive" \
  -exportOptionsPlist "$output/ExportOptions.plist" \
  -exportPath "$output/ipa" \
  "$@" 2>&1 | tee "$output/export.log"

ipa="$(find "$output/ipa" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
if [[ -z "$ipa" ]]; then
  printf '%s\n' '错误：Xcode 未生成 .ipa，请查看 export.log。' >&2
  exit 1
fi
printf 'IPA_READY: %s\n' "$ipa"
shasum -a 256 "$ipa"
