#!/bin/bash
# ============================================================
#  ios_fix.sh — Flutter iOS 构建问题一键修复脚本
#  用法：在项目根目录执行  bash ios_fix.sh
# ============================================================
set -e

# ── 颜色 ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${CYAN}ℹ  $1${NC}"; }
warn() { echo -e "${YELLOW}⚠  $1${NC}"; }
step() { echo -e "\n${BOLD}${CYAN}▶ $1${NC}"; }
err()  { echo -e "${RED}✗  $1${NC}"; }

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
IOS_DIR="$PROJECT_ROOT/ios"
BUILD_IOS_DIR="$PROJECT_ROOT/build/ios"

echo -e "\n${BOLD}╔══════════════════════════════════════════════════╗"
echo -e "║  Flutter iOS 构建修复脚本                        ║"
echo -e "╚══════════════════════════════════════════════════╝${NC}"
echo -e "  项目路径: ${CYAN}$PROJECT_ROOT${NC}\n"

# ──────────────────────────────────────────────────────────
# 错误 1：Framework 'Pods_Runner' not found (DerivedData 冲突)
# 原因：DerivedData 目录里存在多个过时的 Runner-xxx 缓存，
#       链接器找到了不包含 Pods_Runner.framework 的旧缓存。
# ──────────────────────────────────────────────────────────
step "修复 1/5 · 清除 Xcode DerivedData (Pods_Runner not found)"
DERIVED_DIRS=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "Runner-*" -type d 2>/dev/null)
if [ -n "$DERIVED_DIRS" ]; then
  echo "$DERIVED_DIRS" | while read -r dir; do
    info "删除 $(basename "$dir")"
    rm -rf "$dir"
  done
  ok "DerivedData 已清除"
else
  info "DerivedData 中无 Runner-* 缓存，跳过"
fi

# ──────────────────────────────────────────────────────────
# 错误 2：Clean Build failed — Could not delete build directory
# 原因：build/ios/iphoneos 由 Flutter 命令创建，未打 Xcode 标记，
#       Xcode 的 Clean 操作无权删除它。
# ──────────────────────────────────────────────────────────
step "修复 2/5 · 标记 build 目录为 Xcode 可删除 (Clean Build failed)"
IPHONEOS_DIR="$BUILD_IOS_DIR/iphoneos"
if [ -d "$IPHONEOS_DIR" ]; then
  xattr -w com.apple.xcode.CreatedByBuildSystem true "$IPHONEOS_DIR"
  ok "已标记 $IPHONEOS_DIR"
else
  info "目录不存在，跳过标记（构建后自动处理）"
fi

# ──────────────────────────────────────────────────────────
# 错误 3：flutter clean + pub get（重置构建环境）
# ──────────────────────────────────────────────────────────
step "修复 3/5 · flutter clean + pub get"
cd "$PROJECT_ROOT"
flutter clean 2>&1 | grep -v "^$" | tail -5
# 使用国内镜像，防止 pub.dev 握手超时
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter pub get 2>&1 | tail -3
ok "flutter 环境已重置"

# ──────────────────────────────────────────────────────────
# 重新标记（flutter clean 之后目录被删，重建后再标记）
# ──────────────────────────────────────────────────────────
mkdir -p "$IPHONEOS_DIR"
xattr -w com.apple.xcode.CreatedByBuildSystem true "$IPHONEOS_DIR"
ok "build/ios/iphoneos 标记完成"

# ──────────────────────────────────────────────────────────
# 错误 4：ld: framework 'Pods_Runner' not found (链接阶段)
#         source: unbound variable (嵌入阶段)
# 原因 A：Pods-Runner.debug.xcconfig 生成的 FRAMEWORK_SEARCH_PATHS
#         只含各 pod 子目录，缺少 Pods_Runner.framework 所在的根目录
#         $(PODS_CONFIGURATION_BUILD_DIR)。
# 原因 B：Xcode 新版增量构建系统跳过了无输出声明的
#         [CP] Copy XCFrameworks 阶段，导致 XCFramework 切片
#         未解压到 PODS_XCFRAMEWORKS_BUILD_DIR，
#         install_framework() 三个条件全部不满足 → source 未绑定。
# 解法：通过 Podfile post_install 钩子永久写入修复。
# ──────────────────────────────────────────────────────────
step "修复 4/5 · 检查并修补 Podfile (FRAMEWORK_SEARCH_PATHS + XCFrameworks)"

PODFILE="$IOS_DIR/Podfile"

# 检查是否已含 FRAMEWORK_SEARCH_PATHS 修复
if ! grep -q 'PODS_CONFIGURATION_BUILD_DIR.*FRAMEWORK_SEARCH_PATHS\|FRAMEWORK_SEARCH_PATHS.*PODS_CONFIGURATION_BUILD_DIR' "$PODFILE" 2>/dev/null; then
  warn "Podfile 尚未包含 FRAMEWORK_SEARCH_PATHS 修复，请手动确认 Podfile 中已有以下 post_install 代码："
  echo -e "  ${YELLOW}config.build_settings['FRAMEWORK_SEARCH_PATHS'] += ['\\$(PODS_CONFIGURATION_BUILD_DIR)']${NC}"
else
  ok "FRAMEWORK_SEARCH_PATHS 修复已存在"
fi

if ! grep -q 'Fix.*Extract XCFrameworks\|\[Fix\]' "$PODFILE" 2>/dev/null; then
  warn "Podfile 尚未包含 XCFrameworks 提取修复，请手动确认 Podfile 中已有前置提取逻辑"
else
  ok "XCFrameworks 提取修复已存在"
fi

# ──────────────────────────────────────────────────────────
# 错误 5：pod install
# ──────────────────────────────────────────────────────────
step "修复 5/5 · pod install (重新生成 Pods 项目并应用所有修复)"
cd "$IOS_DIR"
if pod install 2>&1 | tee /tmp/pod_install.log | tail -8; then
  ok "pod install 完成"
else
  err "pod install 失败，查看日志："
  cat /tmp/pod_install.log
  exit 1
fi

# ── 最终检查 ──────────────────────────────────────────────
step "最终检查"

# 检查 FRAMEWORK_SEARCH_PATHS 是否写入 project.pbxproj
if grep -q 'PODS_CONFIGURATION_BUILD_DIR' "$IOS_DIR/Runner.xcodeproj/project.pbxproj" 2>/dev/null; then
  ok "FRAMEWORK_SEARCH_PATHS 已写入 project.pbxproj"
else
  warn "FRAMEWORK_SEARCH_PATHS 未找到，可能需要检查 Podfile post_install 逻辑"
fi

# 检查 Embed 修复是否写入
if grep -q 'Fix.*Extract XCFrameworks' "$IOS_DIR/Runner.xcodeproj/project.pbxproj" 2>/dev/null; then
  ok "[CP] Embed Pods Frameworks XCFrameworks 提取前置已写入"
else
  warn "XCFrameworks 提取前置未找到，可能需要检查 Podfile post_install 逻辑"
fi

echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════╗"
echo -e "║  🎉  所有修复已完成！                            ║"
echo -e "╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  接下来请在 Xcode 中："
echo -e "  ${CYAN}1.${NC} 完全退出 Xcode（⌘Q）"
echo -e "  ${CYAN}2.${NC} 打开 ${BOLD}ios/Runner.xcworkspace${NC}（不是 .xcodeproj）"
echo -e "  ${CYAN}3.${NC} Product → Clean Build Folder（⇧⌘K）"
echo -e "  ${CYAN}4.${NC} Run ▶"
echo ""
