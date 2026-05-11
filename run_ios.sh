#!/bin/bash
# ════════════════════════════════════════════════
#  PetPogo iOS 真机运行脚本（茶里王）
#  用法：./run_ios.sh
#        ./run_ios.sh --release
# ════════════════════════════════════════════════

DEVICE_ID="00008140-000169A03C32801C"
BUILD_MODE="--debug"

# ── 解析参数 ──────────────────────────────────
if [ "$1" == "--release" ]; then
  BUILD_MODE="--release"
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║    PetPogo iOS 真机运行（茶里王）        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── 检查设备是否连接 ────────────────────────────
echo "▶ 检查真机连接状态..."
FOUND=$(flutter devices 2>/dev/null | grep "$DEVICE_ID")

if [ -z "$FOUND" ]; then
  echo "  ❌ 未检测到「茶里王」，请确认："
  echo "     1. iPhone 已通过 USB 连接到 Mac"
  echo "     2. iPhone 已解锁并信任此电脑"
  echo "     3. 已在 Xcode 中完成开发者证书配置"
  exit 1
fi

echo "  ✅ 已检测到「茶里王」($DEVICE_ID)"
echo ""

# ── 启动（debug 模式支持热重载）──────────────────
if [ "$BUILD_MODE" == "--debug" ]; then
  echo "▶ 以 Debug 模式启动（支持热重载 r / 热重启 R）..."
  echo ""
  flutter run -d "$DEVICE_ID" --debug
else
  echo "▶ 以 Release 模式构建并安装..."
  echo ""
  flutter run -d "$DEVICE_ID" --release
fi
