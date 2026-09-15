#!/bin/bash
# ════════════════════════════════════════════════
#  宠连芯 实时日志查看器
#  用法：./log.sh [--full]
#    --full  显示所有 tag（默认只显示 flutter）
# ════════════════════════════════════════════════

ADB=~/Library/Android/sdk/platform-tools/adb
PKG="com.junxin.petpogo_and"
FULL_MODE=false

if [[ "$1" == "--full" ]]; then
  FULL_MODE=true
fi

# 先找真机（非 emulator 开头的在线设备）
DEVICE=$($ADB devices | grep -v "^List" | grep "device$" | grep -v "emulator" | head -1 | awk '{print $1}')

if [ -n "$DEVICE" ]; then
  echo "  ✅ 找到真机: $DEVICE"
else
  # 真机没有，找模拟器
  DEVICE=$($ADB devices | grep -E "emulator-[0-9]+" | grep "device$" | head -1 | awk '{print $1}')
fi

if [ -z "$DEVICE" ]; then
  echo "❌ 没有找到任何设备（真机或模拟器），请先连接设备或运行 ./run.sh"
  exit 1
fi

# 获取 App 进程 PID
PID=$($ADB -s $DEVICE shell pidof -s $PKG 2>/dev/null | tr -d '\r')

if [ -z "$PID" ]; then
  echo "❌ App 未运行，请先启动 App"
  exit 1
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       宠连芯 实时日志                    ║"
echo "╚══════════════════════════════════════════╝"
echo "📱 设备: $DEVICE   PID: $PID"
echo "🎨 绿=成功  红=错误  青=网络  紫=页面  黄=状态"
if $FULL_MODE; then
  echo "📋 模式: 完整（所有 tag）"
else
  echo "📋 模式: Flutter 日志（./log.sh --full 显示全部）"
fi
echo "────────────────────────────────────────────"
echo ""

# 加大 logcat 环形缓冲区至 16MB，减少高频日志被挤掉
$ADB -s $DEVICE logcat -G 16M 2>/dev/null || true

# 清空旧日志
$ADB -s $DEVICE logcat -c

colorize() {
  while IFS= read -r line; do
    if echo "$line" | grep -qE "✅|成功|loggedIn|\[API 响应\]"; then
      echo -e "\033[32m$line\033[0m"
    elif echo "$line" | grep -qE "✗|失败|[Ee]rror|[Ee]xception|\[API 错误\]"; then
      echo -e "\033[31m$line\033[0m"
    elif echo "$line" | grep -qE "→ POST|→ GET|\[API 请求\]|│ Body:|│ Headers:|│ Query:|│ Status:"; then
      echo -e "\033[36m$line\033[0m"
    elif echo "$line" | grep -qE "\[路由\]"; then
      echo -e "\033[35m$line\033[0m"
    elif echo "$line" | grep -qE "\[状态\]"; then
      echo -e "\033[33m$line\033[0m"
    else
      echo "$line"
    fi
  done
}

if $FULL_MODE; then
  # 完整模式：App PID 的所有 tag
  $ADB -s $DEVICE logcat --pid=$PID 2>&1 | colorize
else
  # 默认模式：只看 flutter tag（直接 logcat tag 过滤）
  $ADB -s $DEVICE logcat --pid=$PID flutter:V "*:S" 2>&1 | colorize
fi
