#!/bin/bash
# ════════════════════════════════════════════════
#  PetPogo 一键打包 + 安装 + 启动
#  用法：./run.sh
#        ./run.sh --release   （打 Release 包）
# ════════════════════════════════════════════════

ADB=~/Library/Android/sdk/platform-tools/adb
EMULATOR=~/Library/Android/sdk/emulator/emulator
AVD_NAME="Pixel9_API35"
PKG="com.junxin.petpogo_and"
ACTIVITY=".MainActivity"
BUILD_MODE="--debug"
APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"

# ── 解析参数 ──────────────────────────────────
if [ "$1" == "--release" ]; then
  BUILD_MODE="--release"
  APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       PetPogo 一键打包运行脚本            ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Step 1: 检查/启动模拟器 ─────────────────────
echo "▶ [1/3] 检查模拟器..."

# 列出所有在线模拟器
ALL_DEVICES=$($ADB devices | grep -E "emulator-[0-9]+" | grep "device$" | awk '{print $1}')
COUNT=$(echo "$ALL_DEVICES" | grep -c "emulator" 2>/dev/null || echo 0)

# 超过 1 个时，关掉多余的，只保留最新的
if [ "$COUNT" -gt 1 ]; then
  echo "  ⚠️  检测到 $COUNT 个模拟器，自动关闭多余的..."
  echo "$ALL_DEVICES" | tail -n +2 | while read -r OLD_DEV; do
    $ADB -s $OLD_DEV emu kill > /dev/null 2>&1
    echo "  关闭: $OLD_DEV"
  done
  sleep 2
fi

DEVICE=$($ADB devices | grep -E "emulator-[0-9]+" | grep "device$" | head -1 | awk '{print $1}')

if [ -z "$DEVICE" ]; then
  echo "  模拟器未运行，正在启动 $AVD_NAME ..."
  $EMULATOR -avd $AVD_NAME -no-snapshot-load > /dev/null 2>&1 &
  echo "  等待模拟器启动（最多 60 秒）..."

  for i in $(seq 1 60); do
    sleep 2
    DEVICE=$($ADB devices | grep emulator | grep "device$" | head -1 | awk '{print $1}')
    if [ -n "$DEVICE" ]; then
      BOOTED=$($ADB -s $DEVICE shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
      if [ "$BOOTED" == "1" ]; then
        echo "  ✅ 模拟器已就绪: $DEVICE"
        break
      fi
    fi
    echo "  ... 等待中 ($((i*2))s)"
  done

  if [ -z "$DEVICE" ]; then
    echo "  ❌ 模拟器启动超时，请手动启动后重试"
    exit 1
  fi
else
  echo "  ✅ 已有模拟器: $DEVICE"
fi

# ── Step 2: 打包 ────────────────────────────────
echo ""
echo "▶ [2/3] Flutter 打包 ($BUILD_MODE)..."
flutter build apk $BUILD_MODE

if [ $? -ne 0 ]; then
  echo "  ❌ 打包失败，请查看上方错误"
  exit 1
fi
echo "  ✅ 打包完成: $APK_PATH"

# ── Step 3: 安装 + 启动 ──────────────────────────
echo ""
echo "▶ [3/3] 安装并启动 App..."
$ADB -s $DEVICE install -r $APK_PATH

if [ $? -ne 0 ]; then
  echo "  ❌ 安装失败"
  exit 1
fi

$ADB -s $DEVICE shell am start -n $PKG/$ACTIVITY

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ✅ 完成！App 已在模拟器上运行           ║"
echo "║  👉 查看日志：./log.sh                   ║"
echo "╚══════════════════════════════════════════╝"
echo ""
