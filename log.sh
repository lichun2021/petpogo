#!/bin/bash
# ════════════════════════════════════════════════
#  萌宠智伴 实时日志查看器
#  用法：./log.sh
# ════════════════════════════════════════════════

ADB=~/Library/Android/sdk/platform-tools/adb
PKG="com.junxin.petpogo_and"

# 如果有多个模拟器，自动选第一个
DEVICE=$($ADB devices | grep -E "emulator-[0-9]+" | grep "device$" | head -1 | awk '{print $1}')

if [ -z "$DEVICE" ]; then
  echo "❌ 没有找到运行中的模拟器，请先运行 ./run.sh"
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
echo "║       萌宠智伴 实时日志                  ║"
echo "╚══════════════════════════════════════════╝"
echo "📱 设备: $DEVICE   PID: $PID"
echo "🎨 绿=成功  红=错误  青=网络  紫=页面  黄=状态"
echo "────────────────────────────────────────────"
echo ""

# 清空旧日志
$ADB -s $DEVICE logcat -c

# 只抓 App 进程 + flutter tag
$ADB -s $DEVICE logcat --pid=$PID 2>&1 | grep --line-buffered "flutter" | while IFS= read -r line; do
  if echo "$line" | grep -qE "✅|成功|loggedIn|\[API 响应\]"; then
    echo -e "\033[32m$line\033[0m"       # 绿色：成功/响应
  elif echo "$line" | grep -qE "✗|失败|[Ee]rror|[Ee]xception|\[API 错误\]"; then
    echo -e "\033[31m$line\033[0m"       # 红色：错误
  elif echo "$line" | grep -qE "→ POST|→ GET|\[API 请求\]|│ Body:|│ Headers:|│ Query:|│ Status:"; then
    echo -e "\033[36m$line\033[0m"       # 青色：请求/参数
  elif echo "$line" | grep -qE "\[路由\]"; then
    echo -e "\033[35m$line\033[0m"       # 紫色：页面跳转
  elif echo "$line" | grep -qE "\[状态\]"; then
    echo -e "\033[33m$line\033[0m"       # 黄色：状态变化
  else
    echo "$line"
  fi
done
