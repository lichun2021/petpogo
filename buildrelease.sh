#!/bin/bash
# ════════════════════════════════════════════════════════════════
#  宠联芯 - Release 打包脚本
#
#  用法：
#    ./buildrelease.sh              → 同时打包 Google Play AAB + IPA
#    ./buildrelease.sh --apk        → 仅打包 ARM 分架构 Android APK
#    ./buildrelease.sh --apk-universal → 仅打包通用 ARM Android APK
#    ./buildrelease.sh --apk-split  → 按 ABI 打包 Android APK
#    ./buildrelease.sh --aab        → 仅打包 Google Play AAB
#    ./buildrelease.sh --ipa        → 仅打包 iOS IPA
#
#  ⚠️  打 IPA 前请确保：
#    1. 已在 Xcode 配置好 Bundle Identifier 和 Signing
#    2. 已连接 Apple Developer 账号（或使用企业/Ad Hoc 证书）
# ════════════════════════════════════════════════════════════════

set -e  # 遇到错误立即退出

# ── 颜色定义 ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── 项目信息 ──────────────────────────────────────────────────
APP_NAME="宠联芯"
PKG_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')
BUILD_TIME=$(date "+%Y%m%d_%H%M%S")
OUTPUT_DIR="./release_output"

# ── 输出路径 ──────────────────────────────────────────────────
APK_SRC="build/app/outputs/flutter-apk/app-release.apk"
APK_DST="${OUTPUT_DIR}/petpogo_v${PKG_VERSION}_${BUILD_TIME}.apk"
AAB_SRC="build/app/outputs/bundle/release/app-release.aab"
AAB_DST="${OUTPUT_DIR}/petpogo_v${PKG_VERSION}_${BUILD_TIME}.aab"

IPA_SRC="build/ios/ipa/Runner.ipa"
# 也尝试 build/ios/ipa/*.ipa（不同 Flutter 版本路径略有差异）
IPA_DST="${OUTPUT_DIR}/petpogo_v${PKG_VERSION}_${BUILD_TIME}.ipa"

# ── 解析参数 ──────────────────────────────────────────────────
BUILD_APK=false
BUILD_AAB=true
BUILD_IPA=true
SPLIT_APK=false

case "$1" in
  "") ;;
  --apk)
    BUILD_APK=true
    BUILD_AAB=false
    BUILD_IPA=false
    SPLIT_APK=true  # 默认使用分架构 APK（体积更小）
    ;;
  --apk-universal)
    BUILD_APK=true
    BUILD_AAB=false
    BUILD_IPA=false
    SPLIT_APK=false  # 通用 APK（包含所有架构）
    ;;
  --apk-split)
    BUILD_APK=true
    BUILD_AAB=false
    BUILD_IPA=false
    SPLIT_APK=true
    ;;
  --aab)
    BUILD_IPA=false
    ;;
  --ipa)
    BUILD_AAB=false
    ;;
  *)
    echo "未知参数: $1"
    echo "用法: ./buildrelease.sh [--apk|--apk-split|--apk-universal|--aab|--ipa]"
    exit 2
    ;;
esac

# ── 打印 Banner ───────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     ${APP_NAME} Release 打包脚本       ║${NC}"
echo -e "${CYAN}${BOLD}║     版本: v${PKG_VERSION}                             ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ── 功能开关（assets/config/app_flags.json）────────────────────
# 该文件的值直接决定上架包行为（与 release 模式无关），打包前务必确认
FLAGS_FILE="assets/config/app_flags.json"
if [ -f "${FLAGS_FILE}" ]; then
  echo -e "${YELLOW}${BOLD}▶ [配置] ${FLAGS_FILE}${NC}"
  sed 's/^/    /' "${FLAGS_FILE}"
  if grep -Eq '"showRawError"[[:space:]]*:[[:space:]]*true' "${FLAGS_FILE}"; then
    echo -e "${YELLOW}  ⚠️  showRawError=true：本包会在错误提示下方显示原始报错文本${NC}"
  fi
  echo ""
else
  echo -e "${YELLOW}  ⚠️  未找到 ${FLAGS_FILE}，App 将使用默认开关（全部关闭）${NC}"
  echo ""
fi

# ── 创建输出目录 ──────────────────────────────────────────────
mkdir -p "${OUTPUT_DIR}"

# ══════════════════════════════════════════════════════════════
# STEP 1: Flutter pub get
# ══════════════════════════════════════════════════════════════
echo -e "${BLUE}${BOLD}▶ [准备] 同步依赖包...${NC}"
flutter pub get
echo -e "${GREEN}  ✅ 依赖同步完成${NC}"
echo ""

# ══════════════════════════════════════════════════════════════
# STEP 2: 打包 APK
# ══════════════════════════════════════════════════════════════
if [ "$BUILD_APK" = true ]; then
  if [ "$SPLIT_APK" = true ]; then
    echo -e "${BLUE}${BOLD}▶ [Android] 开始按 ABI 打包 Release APK...${NC}"
  else
    echo -e "${BLUE}${BOLD}▶ [Android] 开始打包通用 Release APK...${NC}"
  fi
  echo -e "${YELLOW}  ℹ️  App ID: com.junxin.petpogo_and${NC}"
  echo ""

  if [ "$SPLIT_APK" = true ]; then
    # 与 android/app/build.gradle.kts 的 ARM ABI 配置一致，避免 Flutter
    # 等待并不存在的 x86_64 APK，将已成功的构建误判为失败。
    flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64
    for ABI in armeabi-v7a arm64-v8a; do
      ABI_SRC="build/app/outputs/flutter-apk/app-${ABI}-release.apk"
      ABI_DST="${OUTPUT_DIR}/petpogo_v${PKG_VERSION}_${BUILD_TIME}_${ABI}.apk"
      if [ -f "${ABI_SRC}" ]; then
        cp "${ABI_SRC}" "${ABI_DST}"
        ABI_SIZE=$(du -sh "${ABI_DST}" | cut -f1)
        echo -e "${GREEN}  📦 ${ABI}: ${ABI_DST} (${ABI_SIZE})${NC}"
      else
        echo -e "${RED}  ❌ 未找到 ${ABI} APK: ${ABI_SRC}${NC}"
        exit 1
      fi
    done
  else
    flutter build apk --release --target-platform android-arm,android-arm64
    if [ -f "${APK_SRC}" ]; then
      cp "${APK_SRC}" "${APK_DST}"
      APK_SIZE=$(du -sh "${APK_DST}" | cut -f1)
      echo -e "${GREEN}  📦 通用 APK: ${APK_DST} (${APK_SIZE})${NC}"
    else
      echo -e "${RED}  ❌ APK 文件未找到，打包可能失败${NC}"
      exit 1
    fi
  fi
  echo -e "${GREEN}${BOLD}  ✅ APK 打包成功！${NC}"
  echo ""
fi

# ══════════════════════════════════════════════════════════════
# STEP 3: 打包 AAB
# ══════════════════════════════════════════════════════════════
if [ "$BUILD_AAB" = true ]; then
  echo -e "${BLUE}${BOLD}▶ [Android] 开始打包 Google Play AAB...${NC}"
  flutter build appbundle --release
  if [ -f "${AAB_SRC}" ]; then
    cp "${AAB_SRC}" "${AAB_DST}"
    AAB_SIZE=$(du -sh "${AAB_DST}" | cut -f1)
    echo -e "${GREEN}${BOLD}  ✅ AAB 打包成功！${NC}"
    echo -e "${GREEN}  📦 文件路径: ${AAB_DST}${NC}"
    echo -e "${GREEN}  📏 文件大小: ${AAB_SIZE}${NC}"
  else
    echo -e "${RED}  ❌ AAB 文件未找到，打包可能失败${NC}"
    exit 1
  fi
  echo ""
fi

# ══════════════════════════════════════════════════════════════
# STEP 4: 打包 IPA
# ══════════════════════════════════════════════════════════════
if [ "$BUILD_IPA" = true ]; then
  echo -e "${BLUE}${BOLD}▶ [iOS] 开始打包 Release IPA...${NC}"
  echo -e "${YELLOW}  ℹ️  Bundle ID: 请确认 Xcode 中已配置签名${NC}"
  echo ""

  # 检查是否在 macOS 上运行
  if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}  ❌ IPA 打包仅支持 macOS，当前系统: ${OSTYPE}${NC}"
    exit 1
  fi

  # 先执行 pod install（避免 CocoaPods 不同步问题）
  echo -e "${YELLOW}  → 更新 CocoaPods...${NC}"
  cd ios && pod install --repo-update 2>&1 | tail -5 && cd ..
  echo ""

  # 打包 IPA
  flutter build ipa --release

  # 查找生成的 IPA（路径因版本而异）
  FOUND_IPA=$(find build/ios/ipa -name "*.ipa" 2>/dev/null | head -1)

  if [ -n "${FOUND_IPA}" ] && [ -f "${FOUND_IPA}" ]; then
    cp "${FOUND_IPA}" "${IPA_DST}"
    IPA_SIZE=$(du -sh "${IPA_DST}" | cut -f1)
    echo ""
    echo -e "${GREEN}${BOLD}  ✅ IPA 打包成功！${NC}"
    echo -e "${GREEN}  📦 文件路径: ${IPA_DST}${NC}"
    echo -e "${GREEN}  📏 文件大小: ${IPA_SIZE}${NC}"
  else
    echo ""
    echo -e "${YELLOW}  ⚠️  未找到自动生成的 .ipa 文件${NC}"
    echo -e "${YELLOW}  提示：可能需要在 Xcode 中手动 Archive → Distribute App${NC}"
    echo -e "${YELLOW}  或者检查 build/ios/ipa/ 目录是否有产物${NC}"
    ls -la build/ios/ipa/ 2>/dev/null || echo "  build/ios/ipa/ 目录不存在"
    exit 1
  fi
  echo ""
fi

# ══════════════════════════════════════════════════════════════
# 完成摘要
# ══════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║               🎉 打包完成！                       ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}  版本号: v${PKG_VERSION}${NC}"
echo -e "${BOLD}  时间戳: ${BUILD_TIME}${NC}"
echo -e "${BOLD}  输出目录: ${OUTPUT_DIR}/${NC}"
echo ""
ls -lh "${OUTPUT_DIR}/" 2>/dev/null
echo ""

if [ "$BUILD_APK" = true ]; then
  if [ "$SPLIT_APK" = true ]; then
    echo -e "  ${GREEN}📱 分 ABI APK:${NC} ${OUTPUT_DIR}/petpogo_v${PKG_VERSION}_${BUILD_TIME}_<abi>.apk"
  else
    echo -e "  ${GREEN}📱 Android APK:${NC} ${APK_DST}"
  fi
fi
if [ "$BUILD_AAB" = true ]; then
  echo -e "  ${GREEN}🧩 Android AAB:${NC} ${AAB_DST}"
fi
if [ "$BUILD_IPA" = true ]; then
  echo -e "  ${GREEN}🍎 iOS IPA:${NC}     ${IPA_DST}"
fi

echo ""
echo -e "${YELLOW}  💡 提示：${NC}"
if [ "$BUILD_APK" = true ]; then
  echo -e "  • APK 可直接安装到 Android 设备（允许未知来源安装）"
  echo -e "  • Google Play 上架请使用: ./buildrelease.sh --aab"
fi
if [ "$BUILD_AAB" = true ]; then
  echo -e "  • AAB 用于 Google Play，商店会按设备 ABI 自动下发"
fi
if [ "$BUILD_IPA" = true ]; then
  echo -e "  • IPA 需通过 TestFlight 或 Xcode 安装到已注册设备"
  echo -e "  • 上架 App Store 请在 Xcode 中使用 Distribute App → App Store Connect"
fi
echo ""
